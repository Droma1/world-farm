class_name BlockyAnimator
extends Node
## Animador procedural para los Blocky Characters de Kenney (CC0). Estos
## modelos NO usan Skeleton3D — son una jerarquía de Node3D:
##   character-X
##     root
##       leg-left, leg-right     (rotamos en X para swing forward/back)
##       torso
##         arm-left, arm-right   (rotamos en X para swing forward/back)
##         head                  (rotación contrarrotada al torso)
##
## Implementa la misma API pública que HumanoidAnimator para que el resto
## del juego (Player.gd, Enemy.gd) los pueda intercambiar sin tocar nada.

@export var visuals_path: NodePath  ## Apunta al nodo "character-X" o al "root".

@export_group("Walk")
@export var leg_swing_amp: float = 0.8     ## rad — amplitud del swing al caminar
@export var arm_swing_amp: float = 0.5
@export var walk_freq_factor: float = 1.6
@export var smooth_speed: float = 14.0
@export var torso_bob_amp: float = 0.04

@export_group("Attack / reload")
@export var attack_arm_swing: float = 1.6  ## rad — amplitud del slash con brazo derecho
@export var reload_arm_lift: float = 1.0

# --- Estado de entrada (mismo que HumanoidAnimator) ---
var local_velocity: Vector3 = Vector3.ZERO
var is_on_floor: bool = true
var is_crouching: bool = false

# --- Internos ---
var _root: Node3D                     # nodo "root"
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _torso: Node3D
var _head: Node3D
var _meshes: Array[MeshInstance3D] = []
var _hit_overlay: StandardMaterial3D
var _hit_timer: float = 0.0

var _walk_phase: float = 0.0
var _idle_phase: float = 0.0

var _reloading: bool = false
var _reload_t: float = 0.0
var _reload_dur: float = 1.0
var _attacking: bool = false
var _attack_t: float = 0.0
var _attack_dur: float = 0.35

var _weapon_data: WeaponData
var _dead: bool = false
var _root_rest_y: float = 0.0


func _ready() -> void:
	var visuals: Node = get_node_or_null(visuals_path)
	if visuals == null:
		return
	_root = _find_first(visuals, "root") as Node3D
	if _root == null:
		# Tal vez el visuals_path ya apunta al root.
		_root = visuals as Node3D
	if _root == null:
		return
	_leg_l = _root.get_node_or_null("leg-left") as Node3D
	_leg_r = _root.get_node_or_null("leg-right") as Node3D
	_torso = _root.get_node_or_null("torso") as Node3D
	if _torso:
		_arm_l = _torso.get_node_or_null("arm-left") as Node3D
		_arm_r = _torso.get_node_or_null("arm-right") as Node3D
		_head = _torso.get_node_or_null("head") as Node3D
	_root_rest_y = _root.position.y
	_collect_meshes(_root)
	_hit_overlay = StandardMaterial3D.new()
	_hit_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hit_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hit_overlay.albedo_color = Color(1.0, 0.15, 0.15, 0.55)


func _find_first(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for ch in node.get_children():
		var found := _find_first(ch, target_name)
		if found:
			return found
	return null


func _collect_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		_meshes.append(node)
	for ch in node.get_children():
		_collect_meshes(ch)


# --- API pública (idéntica a HumanoidAnimator) ---

func trigger_reload(duration: float) -> void:
	_reloading = true
	_reload_t = 0.0
	_reload_dur = max(0.05, duration)


func cancel_reload() -> void:
	_reloading = false


func trigger_attack(duration: float = 0.35) -> void:
	_attacking = true
	_attack_t = 0.0
	_attack_dur = max(0.05, duration)


func get_reload_progress() -> float:
	if not _reloading:
		return -1.0
	return clamp(_reload_t / _reload_dur, 0.0, 1.0)


func get_attack_progress() -> float:
	if not _attacking:
		return -1.0
	return clamp(_attack_t / _attack_dur, 0.0, 1.0)


func set_weapon_data(data: WeaponData) -> void:
	_weapon_data = data


func set_dead(dead: bool) -> void:
	_dead = dead


func flash_hit(duration: float = 0.12) -> void:
	if _meshes.is_empty():
		return
	for m in _meshes:
		if is_instance_valid(m):
			m.material_overlay = _hit_overlay
	_hit_timer = duration


func tint_body(color: Color) -> void:
	if color == Color(1, 1, 1, 1):
		return
	for m in _meshes:
		var mat: Material = m.material_override if m.material_override else m.get_active_material(0)
		if mat is StandardMaterial3D:
			var dup := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
			dup.albedo_color = dup.albedo_color * color
			m.material_override = dup


# --- Helpers ---

func _smooth_rot(node: Node3D, target: Vector3, delta: float) -> void:
	if node == null:
		return
	var t: float = clampf(delta * smooth_speed, 0.0, 1.0)
	var current := node.rotation
	node.rotation = current.lerp(target, t)


# --- Loop ---

func _process(delta: float) -> void:
	if _hit_timer > 0.0:
		_hit_timer -= delta
		if _hit_timer <= 0.0:
			for m in _meshes:
				if is_instance_valid(m):
					m.material_overlay = null

	if _dead or _root == null:
		return

	var reload_progress := 0.0
	if _reloading:
		_reload_t += delta
		reload_progress = clamp(_reload_t / _reload_dur, 0.0, 1.0)
		if _reload_t >= _reload_dur:
			_reloading = false

	var attack_progress := 0.0
	if _attacking:
		_attack_t += delta
		attack_progress = clamp(_attack_t / _attack_dur, 0.0, 1.0)
		if _attack_t >= _attack_dur:
			_attacking = false

	var horizontal_speed := Vector2(local_velocity.x, local_velocity.z).length()
	var moving := horizontal_speed > 0.15
	_idle_phase += delta * 2.2
	var direction_sign := -1.0 if local_velocity.z > 0.05 else 1.0
	if moving:
		_walk_phase += delta * horizontal_speed * walk_freq_factor * TAU * direction_sign

	var stride: float = sin(_walk_phase) if moving else 0.0
	var bounce: float = maxf(0.0, -cos(_walk_phase * 2.0)) if moving else 0.0

	# Bob vertical del root
	var bob_y: float = -bounce * torso_bob_amp if is_on_floor else 0.0
	_root.position.y = lerpf(_root.position.y, _root_rest_y + bob_y, clampf(delta * smooth_speed, 0.0, 1.0))

	# Piernas: swing forward/back. Como cada pierna es un Node3D hijo del root
	# (no espejado por bone-roll), USAMOS signos opuestos para alternar.
	var leg_x_l := -stride * leg_swing_amp
	var leg_x_r := stride * leg_swing_amp
	_smooth_rot(_leg_l, Vector3(leg_x_l, 0, 0), delta)
	_smooth_rot(_leg_r, Vector3(leg_x_r, 0, 0), delta)

	# Brazos: pose base + walk sway + reload + attack
	var is_melee: bool = _weapon_data != null and _weapon_data.max_range < 5.0
	var arm_base_x: float = -0.6 if not is_melee else -0.4  # rifle al frente / cuchillo más relajado
	var arm_x_l := arm_base_x + stride * arm_swing_amp
	var arm_x_r := arm_base_x - stride * arm_swing_amp

	# Reload: brazo derecho sube y baja en bell curve
	if _reloading:
		var dip: float = sin(reload_progress * PI)
		arm_x_r = arm_base_x - dip * reload_arm_lift
		arm_x_l = arm_base_x + dip * 0.4  # acompaña

	# Attack (slash melee): brazo derecho swing amplio
	if _attacking and is_melee:
		var s: float = sin(attack_progress * PI)
		arm_x_r = arm_base_x - s * attack_arm_swing

	_smooth_rot(_arm_l, Vector3(arm_x_l, 0, 0), delta)
	_smooth_rot(_arm_r, Vector3(arm_x_r, 0, 0), delta)

	# Torso pequeño rotation al caminar (yaw counter)
	if _torso:
		var torso_y: float = stride * 0.05
		_smooth_rot(_torso, Vector3(0, torso_y, 0), delta)

	# Cabeza counter-rotation del torso
	if _head:
		var head_y: float = -stride * 0.03
		_smooth_rot(_head, Vector3(0, head_y, 0), delta)
