class_name WeaponVFX
extends Node3D
## VFX del arma: muzzle flash + bullet tracer + impact decal + sparks.
## Se suscribe al WeaponComponent indicado y reacciona a shot_fired.

@export var weapon_path: NodePath
@export var muzzle_path: NodePath
@export var muzzle_flash_path: NodePath
@export var weapon_visual_path: NodePath

@export_group("Muzzle / tracer")
@export var muzzle_flash_duration: float = 0.05
@export var tracer_duration: float = 0.06
@export var tracer_thickness: float = 0.025
@export var tracer_color: Color = Color(1.0, 0.85, 0.4, 1.0)

@export_group("Weapon kick")
@export var kick_distance: float = 0.05      # m hacia atrás (+Z)
@export var kick_pitch: float = 0.06         # rad — el cañón sube un poco
@export var kick_recover_speed: float = 18.0

@export_group("Impact decal")
@export var decal_size: float = 0.10
@export var decal_lifetime: float = 8.0
@export var decal_fade_duration: float = 1.5

@export_group("Sparks")
@export var spark_count: int = 12
@export var spark_color: Color = Color(1.0, 0.65, 0.2, 1.0)
@export var spark_lifetime: float = 0.4

var _weapon: WeaponComponent
var _muzzle: Node3D
var _muzzle_flash: Node3D
var _weapon_visual: Node3D
var _weapon_visual_rest_pos: Vector3
var _weapon_visual_rest_rot: Vector3
var _kick_z: float = 0.0          # offset hacia atrás
var _kick_pitch_x: float = 0.0    # cañón hacia arriba
var _flash_timer: float = 0.0


func _ready() -> void:
	if weapon_path:
		_weapon = get_node_or_null(weapon_path) as WeaponComponent
	if muzzle_path:
		_muzzle = get_node_or_null(muzzle_path) as Node3D
	if muzzle_flash_path:
		_muzzle_flash = get_node_or_null(muzzle_flash_path) as Node3D
	if weapon_visual_path:
		_weapon_visual = get_node_or_null(weapon_visual_path) as Node3D
		if _weapon_visual:
			_weapon_visual_rest_pos = _weapon_visual.position
			_weapon_visual_rest_rot = _weapon_visual.rotation
	if _muzzle_flash:
		_muzzle_flash.visible = false
	if _weapon:
		_weapon.shot_fired.connect(_on_shot_fired)


func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0 and _muzzle_flash:
			_muzzle_flash.visible = false

	# Recover weapon kick
	if _weapon_visual:
		_kick_z = lerpf(_kick_z, 0.0, delta * kick_recover_speed)
		_kick_pitch_x = lerpf(_kick_pitch_x, 0.0, delta * kick_recover_speed)
		_weapon_visual.position = _weapon_visual_rest_pos + Vector3(0.0, 0.0, _kick_z)
		_weapon_visual.rotation = _weapon_visual_rest_rot + Vector3(_kick_pitch_x, 0.0, 0.0)


func _on_shot_fired(_data: WeaponData, end_point: Vector3, hit_data: Dictionary) -> void:
	if _muzzle_flash:
		_muzzle_flash.visible = true
		_flash_timer = muzzle_flash_duration
	if _muzzle:
		_spawn_tracer(_muzzle.global_position, end_point)

	# Kick visual del arma
	_kick_z = kick_distance
	_kick_pitch_x = kick_pitch

	if hit_data.is_empty():
		return
	var hit_pos: Vector3 = hit_data.get("position", end_point)
	var hit_normal: Vector3 = hit_data.get("normal", Vector3.UP)
	var collider: Object = hit_data.get("collider")
	# Decal solo en geometría estática (no en personajes — para ellos ya hay
	# flash_hit en el HumanoidAnimator).
	var hit_character := collider is CharacterBody3D
	if not hit_character:
		_spawn_decal(hit_pos, hit_normal)
		_spawn_sparks(hit_pos, hit_normal)


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
