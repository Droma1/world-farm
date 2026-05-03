class_name HumanoidAnimator
extends Node
## Animación procedural para humanoide con Skeleton3D (modelo riggeado).
## Manipula huesos por nombre — el rig debe tener nombres tipo:
##   pelvis, spine_01, spine_02, neck, head
##   shoulder_L/R, upper_arm_L/R, forearm_L/R, hand_L/R
##   thigh_L/R, shin_L/R, foot_L/R
##
## Estado de entrada: local_velocity, is_on_floor, is_crouching
## Llamadas explícitas:
##   trigger_reload(duration), trigger_attack(duration)
##   set_weapon_data(WeaponData), set_dead(true), flash_hit(duration)
##
## Si no encuentra Skeleton3D (entidades sin rig, ej. enemigos con puma
## sin riggear) la animación de miembros queda como no-op pero flash_hit
## y tint_body siguen funcionando.

@export var visuals_path: NodePath
@export var skeleton_path: NodePath  ## Si vacío, busca Skeleton3D recursivamente bajo Visuals

## Rigs distintos tienen distintos bone roll: en algunos (capibara/puma) el eje
## "pitch" (forward/back swing) cae sobre el bone-local Z en vez de X. Cuando
## true, intercambiamos los argumentos X y Z al aplicar rotaciones de hueso,
## de forma que las piernas/brazos balanceen forward/back en vez de side-to-side.
@export var swap_pitch_roll_axes: bool = false

# --- Tuning base ---
@export var arm_hold_x: float = 1.0
@export var leg_walk_amp: float = 0.55
@export var arm_walk_amp: float = 0.10
@export var leg_air_tuck: float = 0.4
@export var crouch_drop: float = 0.35
@export var walk_freq_factor: float = 1.4
@export var smooth_speed: float = 14.0
@export var torso_bob_amp: float = 0.04
@export var torso_roll_amp: float = 0.08
@export var torso_yaw_amp: float = 0.05
@export var head_counter_roll: float = 0.05
@export var head_counter_yaw: float = 0.03
@export var arm_sway_z: float = 0.12
@export var arm_yaw_sway: float = 0.08
@export var leg_splay_z: float = 0.05
@export var idle_breath_amp: float = 0.012

@export_group("Knee bending")
@export var shin_walk_bend: float = 0.7
@export var shin_idle_bend: float = 0.10
@export var shin_air_bend: float = 1.0
@export var thigh_crouch_x: float = 1.0
@export var shin_crouch_bend: float = 1.55

@export_group("Reload animation")
## Recarga en 3 fases:
##   Fase 1 (lift):   eleva el arma hacia arriba
##   Fase 2 (side):   inclina el arma al lateral, brazo izquierdo saca cargador
##   Fase 3 (return): vuelve a la posición de listo apuntando al frente
@export var reload_arm_l_pull: float = 0.55
@export var reload_arm_l_yaw: float = 0.45
@export var reload_forearm_l_bend: float = 1.30
@export var reload_hand_l_twist: float = 0.55
@export var reload_arm_r_lift: float = 0.85   ## Cuánto sube el brazo derecho en la fase 1
@export var reload_arm_r_side: float = 0.55   ## Cuánto se inclina al lateral en la fase 2
@export var reload_forearm_r_bend: float = 0.30
@export var forearm_l_rest_x: float = 0.30
@export var forearm_r_rest_x: float = 0.25

@export_group("Knife pose")
@export var knife_arm_r_x: float = 0.9
@export var knife_arm_r_z: float = -0.25
@export var knife_arm_l_x: float = 0.7
@export var knife_arm_l_z: float = 0.30
@export var knife_forearm_r_bend: float = 0.4
@export var knife_forearm_l_bend: float = 0.6

@export_group("Rifle two-hand pose")
## Pose a dos manos del rifle: el brazo izquierdo cruza al frente para
## sujetar el guardamano, el derecho mantiene el grip cerca del pecho.
## Estos valores se SUMAN a la pose base (arm_hold_x).
@export var rifle_arm_l_extra_pitch: float = 0.30  ## Extiende el brazo izq más al frente
@export var rifle_arm_l_yaw: float = -0.20     ## Cruza el brazo izq hacia la derecha (twist sutil)
@export var rifle_arm_r_yaw: float = 0.10      ## Inclinación leve del derecho
@export var rifle_arm_l_z_offset: float = 0.10 ## Roll del brazo izq para llevarlo a la línea del rifle
@export var rifle_forearm_l_bend: float = 0.75 ## Codo izq doblado para llegar al guardamano
@export var rifle_forearm_r_bend: float = 0.55 ## Codo derecho doblado al pecho

@export_group("Attack animation (slash)")
## El slash tiene 2 fases: windup (sube el brazo) y strike (baja en arco).
@export var attack_arm_r_swing: float = 1.2     ## amplitud del strike (brazo bajando)
@export var attack_arm_r_windup: float = 0.7    ## cuánto sube el brazo en el windup
@export var attack_arm_r_yaw: float = 0.55      ## abre/cruza el brazo en el strike
@export var attack_forearm_r_extend: float = -0.5

@export_group("Tail (puma)")
@export var tail_walk_amp: float = 0.35    ## Latigueo lateral durante run/walk
@export var tail_idle_amp: float = 0.10    ## Sway sutil en idle
@export var tail_segment_falloff: float = 0.80  ## Cada segmento sigue al anterior con menos amplitud
@export var tail_phase_lag: float = 0.45   ## Retraso de fase por segmento (whip-like)

# --- Estado de entrada ---
var local_velocity: Vector3 = Vector3.ZERO
var is_on_floor: bool = true
var is_crouching: bool = false

# --- Internos ---
var _visuals: Node3D
var _skeleton: Skeleton3D
var _meshes: Array[MeshInstance3D] = []

# Bone indices (cached). -1 = no encontrado.
var _b_pelvis: int = -1
var _b_spine_01: int = -1
var _b_spine_02: int = -1
var _b_neck: int = -1
var _b_head: int = -1
var _b_shoulder_l: int = -1
var _b_upper_arm_l: int = -1
var _b_forearm_l: int = -1
var _b_hand_l: int = -1
var _b_shoulder_r: int = -1
var _b_upper_arm_r: int = -1
var _b_forearm_r: int = -1
var _b_hand_r: int = -1
var _b_thigh_l: int = -1
var _b_shin_l: int = -1
var _b_foot_l: int = -1
var _b_thigh_r: int = -1
var _b_shin_r: int = -1
var _b_foot_r: int = -1
var _b_tail_01: int = -1
var _b_tail_02: int = -1
var _b_tail_03: int = -1

# Cache de rest pose por bone (para aplicar rotaciones aditivas)
var _rest_basis: Dictionary = {}  # int → Basis

var _walk_phase: float = 0.0
var _idle_phase: float = 0.0
var _crouch_offset: float = 0.0

var _reloading: bool = false
var _reload_t: float = 0.0
var _reload_dur: float = 1.0

var _attacking: bool = false
var _attack_t: float = 0.0
var _attack_dur: float = 0.35

var _weapon_data: WeaponData

var _hit_overlay: StandardMaterial3D
var _hit_timer: float = 0.0

var _dead: bool = false


func _ready() -> void:
	_visuals = get_node_or_null(visuals_path) as Node3D
	if skeleton_path:
		_skeleton = get_node_or_null(skeleton_path) as Skeleton3D
	if _skeleton == null and _visuals:
		_skeleton = _find_skeleton(_visuals)
	if _skeleton:
		_resolve_bones()
	if _visuals:
		_collect_meshes(_visuals)
	_hit_overlay = StandardMaterial3D.new()
	_hit_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hit_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hit_overlay.albedo_color = Color(1.0, 0.15, 0.15, 0.55)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null


func _resolve_bones() -> void:
	_b_pelvis      = _skeleton.find_bone("pelvis")
	_b_spine_01    = _skeleton.find_bone("spine_01")
	_b_spine_02    = _skeleton.find_bone("spine_02")
	_b_neck        = _skeleton.find_bone("neck")
	_b_head        = _skeleton.find_bone("head")
	_b_shoulder_l  = _skeleton.find_bone("shoulder_L")
	_b_upper_arm_l = _skeleton.find_bone("upper_arm_L")
	_b_forearm_l   = _skeleton.find_bone("forearm_L")
	_b_hand_l      = _skeleton.find_bone("hand_L")
	_b_shoulder_r  = _skeleton.find_bone("shoulder_R")
	_b_upper_arm_r = _skeleton.find_bone("upper_arm_R")
	_b_forearm_r   = _skeleton.find_bone("forearm_R")
	_b_hand_r      = _skeleton.find_bone("hand_R")
	_b_thigh_l     = _skeleton.find_bone("thigh_L")
	_b_shin_l      = _skeleton.find_bone("shin_L")
	_b_foot_l      = _skeleton.find_bone("foot_L")
	_b_thigh_r     = _skeleton.find_bone("thigh_R")
	_b_shin_r      = _skeleton.find_bone("shin_R")
	_b_foot_r      = _skeleton.find_bone("foot_R")
	# Tail bones (solo puma, en capibara devuelven -1)
	_b_tail_01     = _skeleton.find_bone("tail_01")
	_b_tail_02     = _skeleton.find_bone("tail_02")
	_b_tail_03     = _skeleton.find_bone("tail_03")
	# Cachear rest basis de los bones que vamos a animar.
	for idx in [
		_b_pelvis, _b_spine_01, _b_spine_02, _b_neck, _b_head,
		_b_upper_arm_l, _b_forearm_l, _b_hand_l,
		_b_upper_arm_r, _b_forearm_r, _b_hand_r,
		_b_thigh_l, _b_shin_l, _b_foot_l,
		_b_thigh_r, _b_shin_r, _b_foot_r,
		_b_tail_01, _b_tail_02, _b_tail_03,
	]:
		if idx >= 0:
			_rest_basis[idx] = _skeleton.get_bone_rest(idx).basis


func _collect_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		_meshes.append(node)
	for child in node.get_children():
		_collect_meshes(child)


# --- API pública ---

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


## 0..1 si está recargando, -1 si no. Útil para que WeaponVFX sincronice el
## movimiento del arma visible con la pose del brazo (3 fases).
func get_reload_progress() -> float:
	if not _reloading:
		return -1.0
	return clamp(_reload_t / _reload_dur, 0.0, 1.0)


## 0..1 si está atacando, -1 si no.
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
		m.material_overlay = _hit_overlay
	_hit_timer = duration


func tint_body(color: Color) -> void:
	if color == Color(1, 1, 1, 1):
		return
	for m in _meshes:
		var mat: StandardMaterial3D = m.material_override
		if mat:
			var dup := mat.duplicate() as StandardMaterial3D
			dup.albedo_color = mat.albedo_color * color
			m.material_override = dup


# --- Bone helpers ---

func _is_melee_weapon() -> bool:
	return _weapon_data != null and _weapon_data.max_range < 5.0


## Aplica una rotación al bone como offset desde su rest pose. Lerp suave
## para evitar saltos. La rotación es Euler (x, y, z) en radianes.
## Si swap_pitch_roll_axes está activo Y is_limb es true, los valores X y Z
## se intercambian. En estos rigs (capibara/puma) los huesos de limbs tienen
## un bone roll distinto al de la columna/cabeza, así que el swap aplica solo
## a brazos y piernas; spine y head conservan su convención.
func _set_bone_rot(bone_idx: int, target_x: float, target_y: float, target_z: float, delta: float, is_limb: bool = false) -> void:
	if bone_idx < 0 or _skeleton == null:
		return
	var rest_b: Basis = _rest_basis.get(bone_idx, Basis.IDENTITY)
	var euler: Vector3
	if swap_pitch_roll_axes and is_limb:
		euler = Vector3(target_z, target_y, target_x)
	else:
		euler = Vector3(target_x, target_y, target_z)
	var offset := Basis.from_euler(euler)
	var target_quat := (rest_b * offset).get_rotation_quaternion()
	var current_quat := _skeleton.get_bone_pose_rotation(bone_idx)
	var t := clampf(delta * smooth_speed, 0.0, 1.0)
	_skeleton.set_bone_pose_rotation(bone_idx, current_quat.slerp(target_quat, t))


# --- Loop principal ---

func _process(delta: float) -> void:
	if _hit_timer > 0.0:
		_hit_timer -= delta
		if _hit_timer <= 0.0:
			for m in _meshes:
				if is_instance_valid(m):
					m.material_overlay = null

	if _dead:
		return

	# Reload progress
	var reload_progress := 0.0
	if _reloading:
		_reload_t += delta
		reload_progress = clamp(_reload_t / _reload_dur, 0.0, 1.0)
		if _reload_t >= _reload_dur:
			_reloading = false

	# Attack progress (slash)
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

	var stride := sin(_walk_phase)
	var bounce := maxf(0.0, -cos(_walk_phase * 2.0))
	var idle_breath := sin(_idle_phase) * idle_breath_amp if is_on_floor and not moving else 0.0

	# Crouch offset: bajar Visuals (no es un bone, es la raíz del modelo)
	var target_crouch := -crouch_drop if is_crouching else 0.0
	_crouch_offset = lerpf(_crouch_offset, target_crouch, delta * smooth_speed)
	if _visuals:
		var bob_offset := -bounce * torso_bob_amp if moving and is_on_floor else 0.0
		_visuals.position.y = _crouch_offset + bob_offset + idle_breath

	if _skeleton == null:
		return  # Sin rig: solo animamos Visuals (crouch/bob), no bones

	# ============================================================
	# PIERNAS (thigh + shin) — squat, walk, jump
	# ============================================================
	var thigh_target_l := 0.0
	var thigh_target_r := 0.0
	var shin_target_l := 0.0
	var shin_target_r := 0.0
	var leg_roll_l := 0.0
	var leg_roll_r := 0.0

	if not is_on_floor:
		thigh_target_l = -leg_air_tuck
		thigh_target_r = -leg_air_tuck * 0.6
		shin_target_l = shin_air_bend
		shin_target_r = shin_air_bend * 0.7
	elif is_crouching:
		thigh_target_l = -thigh_crouch_x
		thigh_target_r = -thigh_crouch_x
		shin_target_l = shin_crouch_bend
		shin_target_r = shin_crouch_bend
		if moving:
			thigh_target_l += -leg_walk_amp * 0.3 * stride
			thigh_target_r += leg_walk_amp * 0.3 * stride
	elif moving:
		# Cuando swap_pitch_roll_axes está activo, las piernas rotan alrededor
		# de bone-Z, que está ESPEJADO entre L y R. Para alternar (un pie
		# adelante, el otro atrás) necesitamos el MISMO signo en L y R; el
		# espejo del bone-axis hace el resto. Sin swap, signos opuestos.
		var leg_l_phase: float
		var leg_r_phase: float
		if swap_pitch_roll_axes:
			leg_l_phase = leg_walk_amp * stride
			leg_r_phase = leg_walk_amp * stride
		else:
			leg_l_phase = -leg_walk_amp * stride
			leg_r_phase = leg_walk_amp * stride
		thigh_target_l = leg_l_phase
		thigh_target_r = leg_r_phase
		shin_target_l = maxf(0.0, stride) * shin_walk_bend
		shin_target_r = maxf(0.0, -stride) * shin_walk_bend
		# Splay también necesita mismo signo para alternar bajo swap.
		if swap_pitch_roll_axes:
			leg_roll_l = leg_splay_z * stride
			leg_roll_r = leg_splay_z * stride
		else:
			leg_roll_l = -leg_splay_z * stride
			leg_roll_r = leg_splay_z * stride
	else:
		shin_target_l = shin_idle_bend
		shin_target_r = shin_idle_bend

	_set_bone_rot(_b_thigh_l, thigh_target_l, 0.0, leg_roll_l, delta, true)
	_set_bone_rot(_b_thigh_r, thigh_target_r, 0.0, leg_roll_r, delta, true)
	_set_bone_rot(_b_shin_l, shin_target_l, 0.0, 0.0, delta, true)
	_set_bone_rot(_b_shin_r, shin_target_r, 0.0, 0.0, delta, true)

	# ============================================================
	# TORSO + CABEZA  (spine_01 + neck/head)
	# ============================================================
	var torso_pitch_target := 0.0
	var torso_roll_target := 0.0
	var torso_yaw_target := 0.0
	var head_roll_target := 0.0
	var head_yaw_target := 0.0
	if moving and is_on_floor:
		torso_pitch_target = -0.08
		torso_roll_target = -stride * torso_roll_amp
		torso_yaw_target = sin(_walk_phase + PI * 0.5) * torso_yaw_amp
		head_roll_target = stride * head_counter_roll
		head_yaw_target = -sin(_walk_phase + PI * 0.5) * head_counter_yaw
	elif is_crouching:
		torso_pitch_target = -0.20

	# El "torso" lo distribuimos: spine_01 hace la mayoría del bend, spine_02
	# da continuidad. Si solo hay spine_01, va todo ahí.
	_set_bone_rot(_b_spine_01, torso_pitch_target * 0.7, torso_yaw_target * 0.7, torso_roll_target * 0.7, delta)
	_set_bone_rot(_b_spine_02, torso_pitch_target * 0.3, torso_yaw_target * 0.3, torso_roll_target * 0.3, delta)
	# Cabeza: counter-rotation para mantener mirada estable
	_set_bone_rot(_b_head, -torso_pitch_target * 0.2, head_yaw_target, head_roll_target, delta)

	# ============================================================
	# BRAZOS — pose base depende del arma + reload + attack
	# ============================================================
	var bob: float = arm_walk_amp * sin(_walk_phase * 2.0) if moving else idle_breath * 0.5

	var arm_base_l_x: float
	var arm_base_r_x: float
	var arm_base_l_z: float
	var arm_base_r_z: float
	var forearm_base_l: float
	var forearm_base_r: float

	# Pose base por arma. Para el rifle, ambas manos lo sujetan (la izq cruza
	# al guardamano), no es un brazo "casual" colgando.
	var arm_base_l_y: float = 0.0
	var arm_base_r_y: float = 0.0
	if _is_melee_weapon():
		arm_base_l_x = -knife_arm_l_x
		arm_base_r_x = -knife_arm_r_x
		arm_base_l_z = knife_arm_l_z
		arm_base_r_z = knife_arm_r_z
		forearm_base_l = knife_forearm_l_bend
		forearm_base_r = knife_forearm_r_bend
	else:
		# Brazo derecho: grip cerca del pecho.
		# Brazo izquierdo: extendido al frente y cruzando para el guardamano.
		# El extra_pitch lleva el brazo izq más adelante; el z_offset lo
		# desplaza al centro del cuerpo (línea del rifle).
		arm_base_r_x = -arm_hold_x
		arm_base_l_x = -arm_hold_x - rifle_arm_l_extra_pitch
		arm_base_l_z = arm_sway_z + rifle_arm_l_z_offset
		arm_base_r_z = -arm_sway_z
		arm_base_l_y = rifle_arm_l_yaw
		arm_base_r_y = rifle_arm_r_yaw
		forearm_base_l = rifle_forearm_l_bend
		forearm_base_r = rifle_forearm_r_bend

	# Sway de brazos al caminar: mismo problema de espejo que las piernas.
	# Bajo swap, mismo signo en L/R; sin swap, signos opuestos.
	var arm_pitch_l_sway: float
	var arm_pitch_r_sway: float
	var arm_z_l_sway: float
	var arm_z_r_sway: float
	if swap_pitch_roll_axes:
		arm_pitch_l_sway = stride * arm_walk_amp * 0.65
		arm_pitch_r_sway = stride * arm_walk_amp * 0.35
		arm_z_l_sway = stride * arm_sway_z * 0.20
		arm_z_r_sway = stride * arm_sway_z * 0.12
	else:
		arm_pitch_l_sway = -stride * arm_walk_amp * 0.65
		arm_pitch_r_sway = stride * arm_walk_amp * 0.35
		arm_z_l_sway = stride * arm_sway_z * 0.20
		arm_z_r_sway = -stride * arm_sway_z * 0.12

	var arm_target_l := arm_base_l_x + bob + arm_pitch_l_sway
	var arm_target_r := arm_base_r_x + bob + arm_pitch_r_sway
	var arm_y_l := arm_base_l_y + stride * arm_yaw_sway * 0.55
	var arm_y_r := arm_base_r_y - stride * arm_yaw_sway * 0.35
	var arm_z_l := arm_base_l_z + arm_z_l_sway
	var arm_z_r := arm_base_r_z + arm_z_r_sway
	var forearm_target_l := forearm_base_l
	var forearm_target_r := forearm_base_r
	var hand_z_l := 0.0
	var hand_z_r := 0.0

	# Reload en 3 fases:
	#   Fase 1 (0.00 → 0.35): el arma SUBE (lift). Brazo derecho lo eleva.
	#   Fase 2 (0.30 → 0.70): el arma se INCLINA AL LATERAL. Brazo izquierdo
	#                          va al cargador y tira hacia abajo (mag swap).
	#   Fase 3 (0.65 → 1.00): RETORNO al frente (ready). Todo vuelve a 0.
	# Se solapan ligeramente para evitar saltos (pose continua).
	if reload_progress > 0.0 and reload_progress < 1.0:
		var lift: float = smoothstep(0.0, 0.35, reload_progress) - smoothstep(0.65, 1.0, reload_progress)
		var side: float = smoothstep(0.30, 0.55, reload_progress) - smoothstep(0.70, 1.0, reload_progress)
		var work: float = smoothstep(0.35, 0.55, reload_progress) - smoothstep(0.70, 0.95, reload_progress)

		# Brazo derecho: sube en fase 1, gira al lateral en fase 2, vuelve en 3.
		arm_target_r = arm_base_r_x - lift * reload_arm_r_lift
		arm_y_r = side * reload_arm_r_side
		arm_z_r = arm_base_r_z + lift * 0.15

		# Brazo izquierdo: se acompaña al lift, luego coge el cargador (work).
		arm_target_l = arm_base_l_x - lift * 0.45 + work * reload_arm_l_pull
		arm_y_l = -work * reload_arm_l_yaw
		arm_z_l = arm_base_l_z + work * 0.20
		forearm_target_l = forearm_base_l + work * reload_forearm_l_bend
		forearm_target_r = forearm_base_r + work * reload_forearm_r_bend
		hand_z_l = work * reload_hand_l_twist

	# Attack slash (solo melee). 2 fases: windup (brazo arriba) → strike (arco bajando).
	if attack_progress > 0.0 and attack_progress < 1.0 and _is_melee_weapon():
		var windup: float = smoothstep(0.0, 0.30, attack_progress) - smoothstep(0.30, 0.55, attack_progress)
		var strike: float = smoothstep(0.30, 0.55, attack_progress) - smoothstep(0.55, 1.0, attack_progress)
		# Windup: brazo derecho sube y se arma atrás
		# Strike: brazo cae en arco hacia el frente, ligero cruce con yaw
		arm_target_r = arm_base_r_x + windup * attack_arm_r_windup - strike * attack_arm_r_swing
		arm_y_r = strike * attack_arm_r_yaw
		arm_z_r = arm_base_r_z - strike * 0.30
		forearm_target_r = forearm_base_r - windup * 0.20 + strike * attack_forearm_r_extend
		# El brazo izquierdo acompaña ligeramente para balance visual
		arm_target_l = arm_base_l_x + (windup - strike) * 0.15

	_set_bone_rot(_b_upper_arm_l, arm_target_l, arm_y_l, arm_z_l, delta, true)
	_set_bone_rot(_b_upper_arm_r, arm_target_r, arm_y_r, arm_z_r, delta, true)
	_set_bone_rot(_b_forearm_l, forearm_target_l, 0.0, 0.0, delta, true)
	_set_bone_rot(_b_forearm_r, forearm_target_r, 0.0, 0.0, delta, true)
	_set_bone_rot(_b_hand_l, 0.0, 0.0, hand_z_l, delta, true)
	_set_bone_rot(_b_hand_r, 0.0, 0.0, hand_z_r, delta, true)

	# ============================================================
	# TAIL (solo si el rig tiene tail bones, ej. puma)
	# Latigueo lateral con phase offset por segmento → efecto whip.
	# Cuando el enemigo está en idle/atacando: sway sutil.
	# Cuando corre: latigueo más amplio.
	# ============================================================
	if _b_tail_01 >= 0:
		var tail_phase: float
		var tail_amp: float
		if moving:
			# La fase del tail sigue el walk_phase, dividida para que sea más lenta
			tail_phase = _walk_phase * 0.5
			tail_amp = tail_walk_amp
		else:
			tail_phase = _idle_phase * 0.6
			tail_amp = tail_idle_amp
		var t1 := sin(tail_phase) * tail_amp
		var t2 := sin(tail_phase - tail_phase_lag) * tail_amp * tail_segment_falloff
		var t3 := sin(tail_phase - tail_phase_lag * 2.0) * tail_amp * tail_segment_falloff * tail_segment_falloff
		_set_bone_rot(_b_tail_01, 0.0, t1, 0.0, delta)
		_set_bone_rot(_b_tail_02, 0.0, t2, 0.0, delta)
		_set_bone_rot(_b_tail_03, 0.0, t3, 0.0, delta)
