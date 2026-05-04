class_name WeaponComponent
extends Node3D
## Equipa un WeaponData y maneja fire / cooldown / reload / spread.
## En TPS, el "aim provider" es la Camera3D: su -Z global es la dirección
## del disparo y su posición es el origen del raycast.
##
## El signal shot_fired entrega end_point + hit_data (Dictionary del raycast,
## con position/normal/collider/rid o vacío si miss). VFX usa eso para tracer,
## decal y sparks.

signal weapon_equipped(data: WeaponData)
signal shot_fired(data: WeaponData, end_point: Vector3, hit_data: Dictionary)
signal reload_started
signal reload_finished
signal ammo_changed(in_mag: int, reserve: int)

@export_flags_3d_physics var hit_mask: int = 0xFFFFFFFF
@export var weapon_mount_path: NodePath  ## Marker3D bajo el cual se instancia el visual del arma

var current: WeaponData
var in_mag: int = 0
var reserve: int = 0

var _cooldown: float = 0.0
var _reloading: bool = false
var _reload_timer: float = 0.0
var _aim_provider: Node3D
var _exclude_rids: Array[RID] = []
var _weapon_mount: Node3D


func _ready() -> void:
	if weapon_mount_path:
		_weapon_mount = get_node_or_null(weapon_mount_path) as Node3D


func setup(aim_provider: Node3D, exclude_body: CollisionObject3D = null) -> void:
	_aim_provider = aim_provider
	_exclude_rids.clear()
	if exclude_body:
		_exclude_rids.append(exclude_body.get_rid())


func equip(data: WeaponData) -> void:
	current = data
	in_mag = data.mag_size
	reserve = data.reserve_ammo
	_cooldown = 0.0
	_reloading = false
	# El visual se instancia ANTES de emitir weapon_equipped para que
	# WeaponVFX (que escucha la signal y re-resuelve el muzzle) encuentre
	# el visual recién puesto en el árbol.
	_swap_visual(data)
	weapon_equipped.emit(data)
	ammo_changed.emit(in_mag, reserve)


func _swap_visual(data: WeaponData) -> void:
	if not is_instance_valid(_weapon_mount):
		return
	for child in _weapon_mount.get_children():
		_weapon_mount.remove_child(child)
		child.queue_free()
	if data == null or data.weapon_scene == null:
		return
	var inst: Node = data.weapon_scene.instantiate()
	_weapon_mount.add_child(inst)


func _physics_process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown = max(0.0, _cooldown - delta)
	if _reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_finish_reload()


func handle_fire_input(pressed: bool, just_pressed: bool) -> void:
	if current == null:
		return
	var should := false
	match current.fire_mode:
		WeaponData.FireMode.SEMI:
			should = just_pressed
		WeaponData.FireMode.AUTO:
			should = pressed
		WeaponData.FireMode.BURST:
			should = just_pressed  # TODO: ráfaga real
	if should:
		try_fire()


func try_fire() -> bool:
	if current == null or _reloading or _cooldown > 0.0 or _aim_provider == null:
		return false
	# Melee no consume munición ni se queda sin balas: el cuchillo es un arma
	# de cuerpo a cuerpo, no de proyectiles.
	var is_melee: bool = current.max_range < 5.0
	if not is_melee and in_mag <= 0:
		if reserve > 0:
			try_reload()
		return false

	_cooldown = current.seconds_per_shot()
	if not is_melee:
		in_mag -= 1

	var origin: Vector3 = _aim_provider.global_position
	var basis := _aim_provider.global_transform.basis
	var base_dir: Vector3 = -basis.z
	var pellets: int = maxi(current.pellets_per_shot, 1)

	# Para shotgun (pellets > 1) cada pellet hace su propio hitscan con
	# spread independiente. Emitimos shot_fired UNA vez con el último hit
	# para que VFX dispare un solo muzzle flash + tracer.
	var end_point: Vector3 = origin + base_dir * current.max_range
	var hit_data: Dictionary = {}

	# Hold breath: si el player local está aguantando respiración con sniper,
	# reducimos drásticamente el spread (precisión perfecta).
	var spread_mult: float = 1.0
	if get_parent() == GameState.local_player and GameState.local_player and "holding_breath_active" in GameState.local_player and GameState.local_player.holding_breath_active:
		spread_mult = 0.05
	# `last_dir` queda fuera del loop para poder pasarlo a EventBus.weapon_fired
	# despues (un solo SFX de disparo aunque sean N pellets).
	var last_dir: Vector3 = base_dir
	for _i in range(pellets):
		var dir: Vector3 = base_dir
		if current.spread_degrees > 0.0:
			var rad := deg_to_rad(current.spread_degrees * spread_mult)
			dir = dir.rotated(Vector3.UP, RNG.randf_range(-rad, rad))
			dir = dir.rotated(basis.x, RNG.randf_range(-rad, rad))
		dir = dir.normalized()
		last_dir = dir
		var pellet_end: Vector3 = origin + dir * current.max_range
		var pellet_hit: Dictionary = {}
		if current.damage_type == WeaponData.DamageType.HITSCAN:
			pellet_hit = _hitscan(origin, dir)
			if not pellet_hit.is_empty():
				pellet_end = pellet_hit["position"]
		# Tracer/VFX por pellet (shotgun da spray visual)
		if pellets > 1:
			EventBus.pellet_fired.emit(current, origin, pellet_end, pellet_hit)
		# El último (o el único) define end_point para el shot_fired global.
		end_point = pellet_end
		hit_data = pellet_hit

	shot_fired.emit(current, end_point, hit_data)
	# weapon_fired dispara el SFX de disparo. Para melee no queremos sonido
	# de balazo: el slash visual + audio de impacto (si hay) ya es suficiente.
	if not is_melee:
		EventBus.weapon_fired.emit(self, origin, last_dir)
	ammo_changed.emit(in_mag, reserve)
	return true


func _hitscan(origin: Vector3, dir: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var current_origin: Vector3 = origin
	var remaining_range: float = current.max_range
	var first_result: Dictionary = {}
	var penetration_dmg_factor: float = 1.0
	var penetrated_rids: Array[RID] = []
	# Bullet penetration: si el hit deja al enemy con < 20 HP residual
	# (= mata o casi-mata), el balazo continúa al siguiente con falloff 0.55.
	# Cap a 2 penetraciones para evitar pasar por toda la wave.
	var penetration_attempts: int = 3
	while penetration_attempts > 0:
		penetration_attempts -= 1
		var query := PhysicsRayQueryParameters3D.create(
			current_origin, current_origin + dir * remaining_range
		)
		query.collision_mask = hit_mask
		var combined_exclude: Array[RID] = _exclude_rids.duplicate()
		combined_exclude.append_array(penetrated_rids)
		query.exclude = combined_exclude
		var result := space.intersect_ray(query)
		if result.is_empty():
			break
		if first_result.is_empty():
			first_result = result
		var collider: Object = result.get("collider")
		var hp := _find_health_on(collider)
		var hit_pos: Vector3 = result.get("position", current_origin)
		var hit_normal: Vector3 = result.get("normal", Vector3.UP)
		var should_penetrate: bool = false
		if hp:
			# Hit en char con HP. Calculamos daño esperado y vemos si penetra.
			should_penetrate = _apply_hit(collider, hp, hit_pos, hit_normal, penetration_dmg_factor)
		else:
			# Pared/obstáculo: no penetra. Termina el rayo aquí.
			EventBus.impact.emit(hit_pos, hit_normal, collider)
			break
		if not should_penetrate:
			break
		# Continuamos: el rayo sigue desde el hit_pos + un poquito hacia adelante.
		var rid: RID = collider.get_rid() if collider.has_method("get_rid") else RID()
		if rid.is_valid():
			penetrated_rids.append(rid)
		current_origin = hit_pos + dir * 0.05
		remaining_range -= current_origin.distance_to(origin)
		penetration_dmg_factor *= 0.55
	return first_result


func _apply_hit(collider: Object, hp: HealthComponent, hit_pos: Vector3, hit_normal: Vector3, dmg_factor: float) -> bool:
	## Aplica el daño al collider+hp y emite las signals correspondientes.
	## Devuelve true si el balazo debería continuar penetrando (es decir,
	## el target murió o quedará casi-muerto y solo es player el que dispara).
	var dmg: float = current.damage * dmg_factor
	if get_parent() == GameState.local_player:
		dmg *= GameState.damage_multiplier()
	else:
		dmg *= Settings.enemy_damage_multiplier()
		if GameState.current_wave_affix == 3:
			dmg *= 1.25
	# Headshot
	var is_headshot: bool = _is_headshot(collider, hit_pos)
	if is_headshot:
		dmg *= current.headshot_multiplier
		EventBus.headshot.emit(collider, get_parent())
	# Penetration: solo si lo dispara el player local. Penetra si el target
	# va a morir con este hit O si su HP residual es bajo.
	var pen_threshold: float = 20.0
	var is_player_shot: bool = (get_parent() == GameState.local_player)
	var will_kill: bool = hp.current_health <= dmg
	var should_penetrate: bool = is_player_shot and (will_kill or hp.current_health - dmg < pen_threshold)
	hp.take_damage(dmg, get_parent())
	EventBus.damage_dealt.emit(collider, dmg, get_parent())
	EventBus.impact.emit(hit_pos, hit_normal, collider)
	return should_penetrate


func _find_health_on(node: Object) -> HealthComponent:
	if not (node is Node):
		return null
	for child in (node as Node).get_children():
		if child is HealthComponent:
			return child
	return null


## Heurística simple de headshot: si la cápsula del enemigo tiene altura H,
## consideramos el tercio superior (>72% de la altura) como cabeza. Funciona
## bien con humanoides verticales (puma, blocky, capibara). NO requiere mesh
## de hitboxes separados — solo posición Y relativa al body root.
func _is_headshot(collider: Object, hit_pos: Vector3) -> bool:
	if not (collider is CharacterBody3D):
		return false
	var body := collider as CharacterBody3D
	var col_shape := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col_shape == null:
		return false
	var capsule := col_shape.shape as CapsuleShape3D
	if capsule == null:
		return false
	# Altura local del impacto: hit_pos.y - body_origin_y - capsule_offset.y
	var local_y: float = hit_pos.y - body.global_position.y - col_shape.position.y + capsule.height * 0.5
	var t: float = clampf(local_y / capsule.height, 0.0, 1.0)
	return t > 0.72


func try_reload() -> bool:
	if current == null or _reloading:
		return false
	if in_mag == current.mag_size or reserve <= 0:
		return false
	_reloading = true
	# Aplicar bonus de kill streak (recarga rápida a partir de x5).
	# Solo aplica si SOMOS el player local (no bonifica enemigos).
	var mult: float = 1.0
	if get_parent() == GameState.local_player:
		mult = GameState.reload_speed_multiplier()
	_reload_timer = current.reload_time * mult
	reload_started.emit()
	return true


func is_reloading() -> bool:
	return _reloading


func _finish_reload() -> void:
	var needed: int = current.mag_size - in_mag
	var taken: int = min(needed, reserve)
	in_mag += taken
	reserve -= taken
	_reloading = false
	reload_finished.emit()
	ammo_changed.emit(in_mag, reserve)
