class_name HumanoidAnimator
extends Node
## Animación procedural para humanoide hecho de primitivas.
## Manipula transforms locales de pivots de extremidades y posición de
## Visuals (para crouch). NO requiere skeleton ni AnimationPlayer.
##
## Estado de entrada: local_velocity, is_on_floor, is_crouching.
## Llamadas explícitas: trigger_reload(duration), flash_hit(duration).

@export var visuals_path: NodePath
@export var arm_l_path: NodePath
@export var arm_r_path: NodePath
@export var leg_l_path: NodePath
@export var leg_r_path: NodePath

# --- Tuning ---
@export var arm_hold_x: float = 1.4              # rad (~80°): brazos al frente sosteniendo arma
@export var leg_walk_amp: float = 0.55           # ±31°
@export var arm_walk_amp: float = 0.10           # ±5° (bobbing leve, ya que sostienen arma)
@export var leg_air_tuck: float = 0.4            # rad — piernas al aire (saltando)
@export var crouch_drop: float = 0.35            # m — bajar Visuals al agacharse
@export var walk_freq_factor: float = 1.4        # ciclos por segundo por m/s
@export var smooth_speed: float = 14.0           # rapidez de interp
@export var reload_dip_x: float = 1.2            # rad — caída del brazo derecho al recargar

# --- Estado de entrada ---
var local_velocity: Vector3 = Vector3.ZERO
var is_on_floor: bool = true
var is_crouching: bool = false

# --- Internos ---
var _visuals: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _meshes: Array[MeshInstance3D] = []

var _walk_phase: float = 0.0
var _crouch_offset: float = 0.0

var _reloading: bool = false
var _reload_t: float = 0.0
var _reload_dur: float = 1.0

var _hit_overlay: StandardMaterial3D
var _hit_timer: float = 0.0


func _ready() -> void:
	_visuals = get_node_or_null(visuals_path) as Node3D
	_arm_l = get_node_or_null(arm_l_path) as Node3D
	_arm_r = get_node_or_null(arm_r_path) as Node3D
	_leg_l = get_node_or_null(leg_l_path) as Node3D
	_leg_r = get_node_or_null(leg_r_path) as Node3D
	if _visuals:
		_collect_meshes(_visuals)
	_hit_overlay = StandardMaterial3D.new()
	_hit_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hit_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hit_overlay.albedo_color = Color(1.0, 0.15, 0.15, 0.55)


func _collect_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		_meshes.append(node)
	for child in node.get_children():
		_collect_meshes(child)


func trigger_reload(duration: float) -> void:
	_reloading = true
	_reload_t = 0.0
	_reload_dur = max(0.05, duration)


func cancel_reload() -> void:
	_reloading = false


func flash_hit(duration: float = 0.12) -> void:
	if _meshes.is_empty():
		return
	for m in _meshes:
		m.material_overlay = _hit_overlay
	_hit_timer = duration


func _process(delta: float) -> void:
	# Hit flash timeout
	if _hit_timer > 0.0:
		_hit_timer -= delta
		if _hit_timer <= 0.0:
			for m in _meshes:
				if is_instance_valid(m):
					m.material_overlay = null

	# Reload progress
	var reload_progress := 0.0
	if _reloading:
		_reload_t += delta
		reload_progress = clamp(_reload_t / _reload_dur, 0.0, 1.0)
		if _reload_t >= _reload_dur:
			_reloading = false

	# Walk phase: avanza con velocidad horizontal local
	var horizontal_speed := Vector2(local_velocity.x, local_velocity.z).length()
	var moving := horizontal_speed > 0.15
	# Si va hacia atrás (z local positivo en la convención de Godot, ya que -Z es forward),
	# invertimos la fase para que las piernas "caminen al revés" visualmente.
	var direction_sign := -1.0 if local_velocity.z > 0.05 else 1.0
	if moving:
		_walk_phase += delta * horizontal_speed * walk_freq_factor * TAU * direction_sign

	# Crouch offset
	var target_crouch := -crouch_drop if is_crouching else 0.0
	_crouch_offset = lerpf(_crouch_offset, target_crouch, delta * smooth_speed)
	if _visuals:
		_visuals.position.y = _crouch_offset

	# --- Piernas ---
	var leg_target_l := 0.0
	var leg_target_r := 0.0
	if not is_on_floor:
		leg_target_l = leg_air_tuck
		leg_target_r = leg_air_tuck * 0.6
	elif moving:
		leg_target_l = leg_walk_amp * sin(_walk_phase)
		leg_target_r = -leg_walk_amp * sin(_walk_phase)

	if _leg_l:
		_leg_l.rotation.x = lerpf(_leg_l.rotation.x, leg_target_l, delta * smooth_speed)
	if _leg_r:
		_leg_r.rotation.x = lerpf(_leg_r.rotation.x, leg_target_r, delta * smooth_speed)

	# --- Brazos ---
	# Bobbing en sintonía con caminar (fase doble: dos pequeñas oscilaciones por ciclo)
	var bob: float = arm_walk_amp * sin(_walk_phase * 2.0) if moving else 0.0
	var arm_target_l := arm_hold_x + bob
	var arm_target_r := arm_hold_x + bob

	# Animación de recarga (mano derecha baja a la cartuchera y vuelve)
	if reload_progress > 0.0 and reload_progress < 1.0:
		var dip := sin(reload_progress * PI)  # 0 → 1 → 0
		arm_target_r = arm_hold_x - dip * reload_dip_x

	if _arm_l:
		_arm_l.rotation.x = lerpf(_arm_l.rotation.x, arm_target_l, delta * smooth_speed)
	if _arm_r:
		_arm_r.rotation.x = lerpf(_arm_r.rotation.x, arm_target_r, delta * smooth_speed)
