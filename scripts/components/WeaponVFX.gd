class_name WeaponVFX
extends Node3D
## VFX del arma: muzzle flash + bullet tracer + impact decal + sparks.
## Se suscribe al WeaponComponent indicado y reacciona a shot_fired.

@export var weapon_path: NodePath
@export var weapon_mount_path: NodePath  ## Marker3D padre. El primer hijo Node3D es el arma activa

@export_group("Muzzle / tracer")
@export var muzzle_flash_duration: float = 0.05
@export var tracer_duration: float = 0.06
@export var tracer_thickness: float = 0.025
@export var tracer_color: Color = Color(1.0, 0.85, 0.4, 1.0)

@export_group("Weapon kick")
@export var kick_distance: float = 0.05      # m hacia atrás (+Z)
@export var kick_pitch: float = 0.06         # rad — el cañón sube un poco
@export var kick_recover_speed: float = 18.0

@export_group("Reload weapon motion")
## Animación del arma durante recarga (3 fases: arriba → lateral → frente).
@export var reload_lift_up: float = 0.18         ## m arriba en la fase 1
@export var reload_lift_pitch: float = 0.55      ## rad — cañón apuntando arriba
@export var reload_side_offset: float = 0.12     ## m al lateral (+X) en la fase 2
@export var reload_side_yaw: float = 0.65        ## rad — cañón apuntando al lateral
@export var reload_side_roll: float = 0.30       ## rad — twist del arma al lateral

@export_group("Melee swing motion")
## Animación del cuchillo / arma melee al cortar (windup → strike).
@export var melee_windup_lift: float = 0.18      ## m arriba en el windup
@export var melee_windup_pitch: float = -0.7     ## rad — punta hacia arriba
@export var melee_strike_thrust: float = 0.18    ## m hacia adelante en el strike
@export var melee_strike_pitch: float = 0.9      ## rad — punta hacia abajo / al frente
@export var melee_strike_yaw: float = 0.35       ## rad — cruce lateral del corte

@export_group("Impact decal")
@export var decal_size: float = 0.10
@export var decal_lifetime: float = 8.0
@export var decal_fade_duration: float = 1.5

@export_group("Sparks")
@export var spark_count: int = 12
@export var spark_color: Color = Color(1.0, 0.65, 0.2, 1.0)
@export var spark_lifetime: float = 0.4

var _weapon: WeaponComponent
var _weapon_mount: Node3D
var _muzzle: Node3D
var _muzzle_flash: Node3D
var _weapon_visual: Node3D
var _weapon_visual_rest_pos: Vector3
var _weapon_visual_rest_rot: Vector3
var _kick_z: float = 0.0          # offset hacia atrás
var _kick_pitch_x: float = 0.0    # cañón hacia arriba
var _flash_timer: float = 0.0

# Reload anim: progreso 0..1, -1 = no reloading
var _reload_t: float = 0.0
var _reload_dur: float = 0.0
var _reloading: bool = false

# Melee swing anim
var _swing_t: float = 0.0
var _swing_dur: float = 0.0
var _swinging: bool = false


func _ready() -> void:
	if weapon_path:
		_weapon = get_node_or_null(weapon_path) as WeaponComponent
	if weapon_mount_path:
		_weapon_mount = get_node_or_null(weapon_mount_path) as Node3D
	if _weapon:
		_weapon.weapon_equipped.connect(_on_weapon_equipped)
		_weapon.shot_fired.connect(_on_shot_fired)
		_weapon.reload_started.connect(_on_reload_started)
		_weapon.reload_finished.connect(_on_reload_finished)
	# Pellets de shotgun: tracer extra por cada uno (no muzzle flash extra).
	EventBus.pellet_fired.connect(_on_pellet_fired)


func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0 and is_instance_valid(_muzzle_flash):
			_muzzle_flash.visible = false

	# Avance de timers de pose
	if _reloading:
		_reload_t += delta
		if _reload_t >= _reload_dur:
			_reloading = false
	if _swinging:
		_swing_t += delta
		if _swing_t >= _swing_dur:
			_swinging = false

	# Recover weapon kick
	if is_instance_valid(_weapon_visual):
		_kick_z = lerpf(_kick_z, 0.0, delta * kick_recover_speed)
		_kick_pitch_x = lerpf(_kick_pitch_x, 0.0, delta * kick_recover_speed)

		var pos_offset := Vector3(0.0, 0.0, _kick_z)
		var rot_offset := Vector3(_kick_pitch_x, 0.0, 0.0)

		# Reload pose: 3 fases (lift → side → return)
		# Convención: el cañón apunta a -Z (forward). Rotar +X gira la punta
		# hacia ABAJO (porque +X usa right-hand rule: +Z → -Y); rotar -X la
		# gira hacia ARRIBA. Por eso el lift usa rotación NEGATIVA en X.
		if _reloading and _reload_dur > 0.0:
			var p: float = clamp(_reload_t / _reload_dur, 0.0, 1.0)
			var lift: float = smoothstep(0.0, 0.35, p) - smoothstep(0.65, 1.0, p)
			var side: float = smoothstep(0.30, 0.55, p) - smoothstep(0.70, 1.0, p)
			pos_offset += Vector3(side * reload_side_offset, lift * reload_lift_up, 0.0)
			rot_offset += Vector3(-lift * reload_lift_pitch, side * reload_side_yaw, side * reload_side_roll)

		# Melee swing pose: 2 fases (windup → strike). La punta del arma sube
		# en el windup (rotación -X) y baja al frente en el strike (rotación +X).
		if _swinging and _swing_dur > 0.0:
			var s: float = clamp(_swing_t / _swing_dur, 0.0, 1.0)
			var windup: float = smoothstep(0.0, 0.30, s) - smoothstep(0.30, 0.55, s)
			var strike: float = smoothstep(0.30, 0.55, s) - smoothstep(0.55, 1.0, s)
			pos_offset += Vector3(
				strike * 0.05,
				windup * melee_windup_lift - strike * 0.10,
				-strike * melee_strike_thrust
			)
			# windup_pitch < 0 (eleva la punta), strike_pitch > 0 (baja la punta)
			rot_offset += Vector3(
				windup * melee_windup_pitch + strike * melee_strike_pitch,
				strike * melee_strike_yaw,
				0.0
			)

		_weapon_visual.position = _weapon_visual_rest_pos + pos_offset
		_weapon_visual.rotation = _weapon_visual_rest_rot + rot_offset


func _on_weapon_equipped(_data: WeaponData) -> void:
	# Re-resolver el visual al swappear arma. Tomamos el primer hijo Node3D
	# del WeaponMount como "arma activa". Si el arma no tiene Muzzle (ej.
	# cuchillo), simplemente no habrá tracer/flash, sin crashear.
	_muzzle = null
	_muzzle_flash = null
	_weapon_visual = null
	_kick_z = 0.0
	_kick_pitch_x = 0.0
	_reloading = false
	_swinging = false
	if not is_instance_valid(_weapon_mount):
		return
	for child in _weapon_mount.get_children():
		if child is Node3D:
			_weapon_visual = child as Node3D
			break
	if not _weapon_visual:
		return
	_weapon_visual_rest_pos = _weapon_visual.position
	_weapon_visual_rest_rot = _weapon_visual.rotation
	_muzzle = _weapon_visual.get_node_or_null("Muzzle") as Node3D
	if _muzzle:
		_muzzle_flash = _muzzle.get_node_or_null("MuzzleFlash") as Node3D
		if _muzzle_flash:
			_muzzle_flash.visible = false


func _on_shot_fired(data: WeaponData, end_point: Vector3, hit_data: Dictionary) -> void:
	if not is_inside_tree():
		return

	# Cuchillo / melee: SIN muzzle flash, SIN tracer. Solo slash effect en hit.
	var is_melee := data != null and data.max_range < 5.0

	if is_melee:
		# Lanzar la animación de swing del arma (windup → strike). Duración
		# alineada con el cooldown del arma para que match con el siguiente input.
		var swing_dur: float = 0.32
		if data:
			swing_dur = clampf(data.seconds_per_shot() * 0.85, 0.18, 0.55)
		_swing_t = 0.0
		_swing_dur = swing_dur
		_swinging = true
	else:
		if is_instance_valid(_muzzle_flash):
			_muzzle_flash.visible = true
			_flash_timer = muzzle_flash_duration
		if is_instance_valid(_muzzle):
			_spawn_tracer(_muzzle.global_position, end_point)
		_kick_z = kick_distance
		_kick_pitch_x = kick_pitch

	if hit_data.is_empty():
		return
	var hit_pos: Vector3 = hit_data.get("position", end_point)
	var hit_normal: Vector3 = hit_data.get("normal", Vector3.UP)
	var collider: Object = hit_data.get("collider")
	var hit_character := collider is CharacterBody3D

	if is_melee:
		# Slash en el punto de hit (arco blanco brillante). Sin sparks naranjas
		# ni decal de bala — esto es un corte, no un disparo.
		_spawn_slash(hit_pos, hit_normal)
	elif not hit_character:
		_spawn_decal(hit_pos, hit_normal)
		_spawn_sparks(hit_pos, hit_normal)


func _on_pellet_fired(_data: Resource, origin: Vector3, end_point: Vector3, hit_data: Dictionary) -> void:
	# Solo dibujamos tracer si este WeaponVFX pertenece al weapon que disparó.
	# (Los pellets emiten globalmente; filtramos por proximidad al muzzle).
	if not is_instance_valid(_muzzle):
		return
	if origin.distance_to(_muzzle.global_position) > 0.8:
		return
	_spawn_tracer(_muzzle.global_position, end_point)
	# Sparks pequeños en el punto de impacto si es pared.
	if not hit_data.is_empty():
		var collider: Object = hit_data.get("collider")
		if not (collider is CharacterBody3D):
			_spawn_sparks(hit_data.get("position", end_point), hit_data.get("normal", Vector3.UP))


func _on_reload_started() -> void:
	if _weapon == null or _weapon.current == null:
		return
	# Melee no recarga.
	if _weapon.current.max_range < 5.0:
		return
	_reload_t = 0.0
	_reload_dur = max(0.05, _weapon.current.reload_time)
	_reloading = true


func _on_reload_finished() -> void:
	_reloading = false


# --- Slash effect (melee) ---

func _spawn_slash(pos: Vector3, normal: Vector3) -> void:
	## Arco blanco corto que aparece en el punto de impacto del cuchillo.
	## Compuesto por: una "estela" (quad alargado) + chispas blancas finas.
	var slash := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.6, 0.08)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.95, 0.95, 1.0, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(1, 1, 1, 1)
	mat.emission_energy_multiplier = 4.0
	mesh.material = mat
	slash.mesh = mesh
	slash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	get_tree().current_scene.add_child(slash)
	slash.global_position = pos + normal * 0.02
	# Orientar el quad mirando hacia la normal del impacto, con un ligero tilt
	var up: Vector3 = Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	slash.look_at(slash.global_position - normal, up)
	slash.rotate_object_local(Vector3.FORWARD, RNG.randf_range(-0.6, 0.6))

	# Chispas blancas finas (no naranjas como las de bala)
	var p := CPUParticles3D.new()
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 8
	p.lifetime = 0.25
	p.direction = normal
	p.spread = 45.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -3, 0)
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.7
	p.color = Color(1, 1, 1, 1)
	var sm := SphereMesh.new()
	sm.radius = 0.012
	sm.height = 0.024
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(1, 1, 1, 1)
	smat.emission_enabled = true
	smat.emission = Color(1, 1, 1, 1)
	smat.emission_energy_multiplier = 3.0
	sm.material = smat
	p.mesh = sm
	get_tree().current_scene.add_child(p)
	p.global_position = pos + normal * 0.05

	# Fade-out + free
	var tween := create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(slash.queue_free)
	get_tree().create_timer(0.45).timeout.connect(p.queue_free)


# --- Tracer ---

func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var distance := from.distance_to(to)
	if distance < 0.05:
		return

	var tracer := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(tracer_thickness, tracer_thickness, distance)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = tracer_color
	mat.emission_enabled = true
	mat.emission = tracer_color
	mat.emission_energy_multiplier = 5.0
	mesh.material = mat
	tracer.mesh = mesh
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	get_tree().current_scene.add_child(tracer)
	tracer.global_position = (from + to) * 0.5
	var dir := (to - from).normalized()
	var up: Vector3 = Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	tracer.look_at(to, up)

	get_tree().create_timer(tracer_duration).timeout.connect(tracer.queue_free)


# --- Bullet hole decal ---

func _spawn_decal(pos: Vector3, normal: Vector3) -> void:
	var decal := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(decal_size, decal_size)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.04, 0.03, 0.03, 0.92)
	mesh.material = mat
	decal.mesh = mesh
	decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	get_tree().current_scene.add_child(decal)
	# Pequeño offset hacia fuera para evitar z-fighting con la pared
	decal.global_position = pos + normal * 0.01
	# QuadMesh tiene su normal en +Z local. Queremos que +Z = hit_normal.
	# look_at orienta -Z hacia el target → target = pos - normal.
	var up: Vector3 = Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	decal.look_at(decal.global_position - normal, up)

	# Fade-out + free
	var tween := create_tween()
	tween.tween_interval(decal_lifetime)
	tween.tween_property(mat, "albedo_color:a", 0.0, decal_fade_duration)
	tween.tween_callback(decal.queue_free)


# --- Sparks ---

func _spawn_sparks(pos: Vector3, normal: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = spark_count
	p.lifetime = spark_lifetime
	p.direction = normal
	p.spread = 60.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.5
	p.gravity = Vector3(0, -8, 0)
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.0
	p.color = spark_color

	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.015
	spark_mesh.height = 0.03

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = spark_color
	mat.emission_enabled = true
	mat.emission = spark_color
	mat.emission_energy_multiplier = 4.0
	spark_mesh.material = mat
	p.mesh = spark_mesh

	get_tree().current_scene.add_child(p)
	p.global_position = pos + normal * 0.05

	get_tree().create_timer(spark_lifetime + 0.2).timeout.connect(p.queue_free)
