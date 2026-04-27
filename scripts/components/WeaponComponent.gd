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
	if in_mag <= 0:
		if reserve > 0:
			try_reload()
		return false

	_cooldown = current.seconds_per_shot()
	in_mag -= 1

	var origin: Vector3 = _aim_provider.global_position
	var basis := _aim_provider.global_transform.basis
	var dir: Vector3 = -basis.z

	if current.spread_degrees > 0.0:
		var rad := deg_to_rad(current.spread_degrees)
		dir = dir.rotated(Vector3.UP, RNG.randf_range(-rad, rad))
		dir = dir.rotated(basis.x, RNG.randf_range(-rad, rad))
	dir = dir.normalized()

	var end_point: Vector3 = origin + dir * current.max_range
	var hit_data: Dictionary = {}

	if current.damage_type == WeaponData.DamageType.HITSCAN:
		hit_data = _hitscan(origin, dir)
		if not hit_data.is_empty():
			end_point = hit_data["position"]
	# TODO: PROJECTILE → spawn current.projectile_scene + dejar que viaje físico.

	shot_fired.emit(current, end_point, hit_data)
	EventBus.weapon_fired.emit(self, origin, dir)
	ammo_changed.emit(in_mag, reserve)
	return true


func _hitscan(origin: Vector3, dir: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		origin, origin + dir * current.max_range
	)
	query.collision_mask = hit_mask
	query.exclude = _exclude_rids
	var result := space.intersect_ray(query)
	if result.is_empty():
		return {}

	var collider: Object = result.get("collider")
	var hp := _find_health_on(collider)
	if hp:
		hp.take_damage(current.damage, get_parent())
		EventBus.damage_dealt.emit(collider, current.damage, get_parent())
	EventBus.impact.emit(
		result.get("position", Vector3.ZERO),
		result.get("normal", Vector3.UP),
		collider
	)
	return result


func _find_health_on(node: Object) -> HealthComponent:
	if not (node is Node):
		return null
	for child in (node as Node).get_children():
		if child is HealthComponent:
			return child
	return null


func try_reload() -> bool:
	if current == null or _reloading:
		return false
	if in_mag == current.mag_size or reserve <= 0:
		return false
	_reloading = true
	_reload_timer = current.reload_time
	reload_started.emit()
	return true


func _finish_reload() -> void:
	var needed: int = current.mag_size - in_mag
	var taken: int = min(needed, reserve)
	in_mag += taken
	reserve -= taken
	_reloading = false
	reload_finished.emit()
	ammo_changed.emit(in_mag, reserve)
