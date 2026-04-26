class_name HumanoidAnimator
extends Node
## Animación procedural para humanoide hecho de primitivas.
## Manipula transforms locales de pivots de extremidades y posición de
## Visuals (para crouch). NO requiere skeleton ni AnimationPlayer.
##
## Estado de entrada: local_velocity, is_on_floor, is_crouching.
## Llamadas explícitas: trigger_reload(duration), flash_hit(duration).

@export var visuals_path: NodePath
@export var torso_path: NodePath
@export var head_path: NodePath
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
@export var torso_bob_amp: float = 0.04
@export var torso_roll_amp: float = 0.08
@export var torso_yaw_amp: float = 0.05
@export var head_counter_roll: float = 0.05
@export var head_counter_yaw: float = 0.03
@export var arm_sway_z: float = 0.12
@export var arm_yaw_sway: float = 0.08
@export var leg_splay_z: float = 0.05
@export var idle_breath_amp: float = 0.012

# --- Estado de entrada ---
var local_velocity: Vector3 = Vector3.ZERO
var is_on_floor: bool = true
var is_crouching: bool = false

# --- Internos ---
var _visuals: Node3D
var _torso: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _meshes: Array[MeshInstance3D] = []

var _walk_phase: float = 0.0
var _idle_phase: float = 0.0
var _crouch_offset: float = 0.0

var _reloading: bool = false
var _reload_t: float = 0.0
var _reload_dur: float = 1.0

var _hit_overlay: StandardMaterial3D
var _hit_timer: float = 0.0


func _ready() -> void:
	_visuals = get_node_or_null(visuals_path) as Node3D
	_torso = get_node_or_null(torso_path) as Node3D
	_head = get_node_or_null(head_path) as Node3D
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


func tint_body(color: Color) -> void:
	## Multiplica el albedo de los meshes por `color`. Usado por enemigos
	## para diferenciar variantes (Heavy = oscuro, Sniper = púrpura, etc).
	if color == Color(1, 1, 1, 1):
		return
	for m in _meshes:
		var mat: StandardMaterial3D = m.material_override
		if mat:
			var dup := mat.duplicate() as StandardMaterial3D
			dup.albedo_color = mat.albedo_color * color
			m.material_override = dup


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
	_idle_phase += delta * 2.2
	# Si va hacia atrás (z local positivo en la convención de Godot, ya que -Z es forward),
	# invertimos la fase para que las piernas "caminen al revés" visualmente.
	var direction_sign := -1.0 if local_velocity.z > 0.05 else 1.0
	if moving:
		_walk_phase += delta * horizontal_speed * walk_freq_factor * TAU * direction_sign

	var stride := sin(_walk_phase)
	var bounce := maxf(0.0, -cos(_walk_phase * 2.0))
	var idle_breath := sin(_idle_phase) * idle_breath_amp if is_on_floor and not moving else 0.0

	# Crouch offset
	var target_crouch := -crouch_drop if is_crouching else 0.0
	_crouch_offset = lerpf(_crouch_offset, target_crouch, delta * smooth_speed)
	if _visuals:
		var bob_offset := -bounce * torso_bob_amp if moving and is_on_floor else 0.0
		_visuals.position.y = _crouch_offset + bob_offset + idle_breath

	# --- Piernas ---
	var leg_target_l := 0.0
	var leg_target_r := 0.0
	var leg_roll_l := 0.0
	var leg_roll_r := 0.0
	if not is_on_floor:
		leg_target_l = leg_air_tuck
		leg_target_r = leg_air_tuck * 0.6
	elif moving:
		leg_target_l = leg_walk_amp * stride
		leg_target_r = -leg_walk_amp * stride
		leg_roll_l = -leg_splay_z * stride
		leg_roll_r = leg_splay_z * stride

	if _leg_l:
		_leg_l.rotation.x = lerpf(_leg_l.rotation.x, leg_target_l, delta * smooth_speed)
		_leg_l.rotation.z = lerpf(_leg_l.rotation.z, leg_roll_l, delta * smooth_speed)
	if _leg_r:
		_leg_r.rotation.x = lerpf(_leg_r.rotation.x, leg_target_r, delta * smooth_speed)
		_leg_r.rotation.z = lerpf(_leg_r.rotation.z, leg_roll_r, delta * smooth_speed)

	# --- Torso y cabeza ---
	var torso_pitch_target := 0.0
	var torso_roll_target := 0.0
	var torso_yaw_target := 0.0
	var head_roll_target := 0.0
	var head_yaw_target := 0.0
	if moving and is_on_floor:
		torso_pitch_target = 0.08
		torso_roll_target = -stride * torso_roll_amp
		torso_yaw_target = sin(_walk_phase + PI * 0.5) * torso_yaw_amp
		head_roll_target = stride * head_counter_roll
		head_yaw_target = -sin(_walk_phase + PI * 0.5) * head_counter_yaw
	elif is_crouching:
		torso_pitch_target = 0.12

	if _torso:
		_torso.rotation.x = lerpf(_torso.rotation.x, torso_pitch_target, delta * smooth_speed)
		_torso.rotation.z = lerpf(_torso.rotation.z, torso_roll_target, delta * smooth_speed)
		_torso.rotation.y = lerpf(_torso.rotation.y, torso_yaw_target, delta * smooth_speed)
	if _head:
		_head.rotation.x = lerpf(_head.rotation.x, -torso_pitch_target * 0.2, delta * smooth_speed)
		_head.rotation.z = lerpf(_head.rotation.z, head_roll_target, delta * smooth_speed)
		_head.rotation.y = lerpf(_head.rotation.y, head_yaw_target, delta * smooth_speed)

	# --- Brazos ---
	# Bobbing en sintonía con caminar (fase doble: dos pequeñas oscilaciones por ciclo)
	var bob: float = arm_walk_amp * sin(_walk_phase * 2.0) if moving else idle_breath * 0.5
	var arm_target_l := arm_hold_x + bob + stride * arm_walk_amp * 0.65
	var arm_target_r := arm_hold_x + bob - stride * arm_walk_amp * 0.35
	var arm_y_l := stride * arm_yaw_sway * 0.55
	var arm_y_r := -stride * arm_yaw_sway * 0.35
	var arm_z_l := arm_sway_z + stride * arm_sway_z * 0.20
	var arm_z_r := -arm_sway_z - stride * arm_sway_z * 0.12

	# Animación de recarga (mano derecha baja a la cartuchera y vuelve)
	if reload_progress > 0.0 and reload_progress < 1.0:
		var dip := sin(reload_progress * PI)  # 0 → 1 → 0
		arm_target_r = arm_hold_x - dip * reload_dip_x
		arm_y_r = -dip * (arm_yaw_sway + 0.12)
		arm_z_r = -arm_sway_z - dip * 0.18

	if _arm_l:
		_arm_l.rotation.x = lerpf(_arm_l.rotation.x, arm_target_l, delta * smooth_speed)
		_arm_l.rotation.y = lerpf(_arm_l.rotation.y, arm_y_l, delta * smooth_speed)
		_arm_l.rotation.z = lerpf(_arm_l.rotation.z, arm_z_l, delta * smooth_speed)
	if _arm_r:
		_arm_r.rotation.x = lerpf(_arm_r.rotation.x, arm_target_r, delta * smooth_speed)
		_arm_r.rotation.y = lerpf(_arm_r.rotation.y, arm_y_r, delta * smooth_speed)
		_arm_r.rotation.z = lerpf(_arm_r.rotation.z, arm_z_r, delta * smooth_speed)
