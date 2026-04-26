class_name Player
extends CharacterBody3D
## Entity Player. Cablea components, maneja input de cámara, zoom, recoil,
## shake, footsteps, weapon swap. Toda la lógica de gameplay vive en
## components.

@export var data: CharacterData

@onready var camera_pitch: Node3D = $CameraPitch
@onready var recoil_pivot: Node3D = $CameraPitch/RecoilPivot
@onready var spring_arm: SpringArm3D = $CameraPitch/RecoilPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPitch/RecoilPivot/SpringArm3D/Camera3D
@onready var weapon_mount: Marker3D = $WeaponMount
@onready var health: HealthComponent = $HealthComponent
@onready var movement: MovementComponent = $MovementComponent
@onready var weapon: WeaponComponent = $WeaponComponent
@onready var animator: HumanoidAnimator = $HumanoidAnimator

var _mouse_sensitivity: float = 0.003
const PITCH_LIMIT: float = deg_to_rad(70.0)

const ZOOM_DEFAULT_FOV: float = 70.0
const ZOOM_ADS_FOV: float = 35.0
const ZOOM_MIN_FOV: float = 20.0
const ZOOM_MAX_FOV: float = 80.0
const ZOOM_STEP: float = 8.0
var _zoom_target_fov: float = ZOOM_DEFAULT_FOV

@export_group("Camera feel")
@export var recoil_pitch_factor: float = 0.04
@export var recoil_yaw_factor: float = 0.02
@export var recoil_decay: float = 6.5
@export var shake_max: float = 1.5
@export var shake_decay: float = 5.0
@export var shake_amplitude: float = 0.04

var _recoil_pitch: float = 0.0
var _recoil_yaw: float = 0.0
var _shake_intensity: float = 0.0

# --- Weapon swap ---
# _weapon_states[i] = {"in_mag": int, "reserve": int}.
# Mantiene la munición por arma cuando hacemos swap.
var _weapons: Array[WeaponData] = []
var _weapon_states: Array[Dictionary] = []
var _active_weapon_idx: int = -1


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	spring_arm.add_excluded_object(get_rid())

	if data:
		_mouse_sensitivity = data.mouse_sensitivity
		health.max_health = data.max_health
		health.current_health = data.max_health
		movement.walk_speed = data.move_speed
		movement.sprint_speed = data.sprint_speed
		movement.jump_velocity = data.jump_velocity

	# Override con la sensibilidad del usuario (persistida en Settings)
	_mouse_sensitivity = Settings.mouse_sensitivity
	Settings.changed.connect(_on_setting_changed)

	weapon.setup(camera, self)

	# Construir inventario de armas
	if data:
		if data.starting_weapons and data.starting_weapons.size() > 0:
			for w in data.starting_weapons:
				_weapons.append(w)
		elif data.starting_weapon:
			_weapons.append(data.starting_weapon)
	for w in _weapons:
		_weapon_states.append({"in_mag": w.mag_size, "reserve": w.reserve_ammo})
	if _weapons.size() > 0:
		_equip_weapon(0)

	weapon.reload_started.connect(_on_reload_started)
	weapon.shot_fired.connect(_on_weapon_shot_fired)
	health.damaged.connect(_on_player_damaged)
	health.died.connect(_on_died)
	movement.step.connect(_on_step)

	camera.fov = ZOOM_DEFAULT_FOV
	_zoom_target_fov = ZOOM_DEFAULT_FOV

	GameState.local_player = self


func _exit_tree() -> void:
	if GameState.local_player == self:
		GameState.local_player = null


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventKey:
		_handle_key(event as InputEventKey)


func _handle_mouse_motion(m: InputEventMouseMotion) -> void:
	var sens_scale: float = camera.fov / ZOOM_DEFAULT_FOV
	rotate_y(-m.relative.x * _mouse_sensitivity * sens_scale)
	camera_pitch.rotate_x(-m.relative.y * _mouse_sensitivity * sens_scale)
	camera_pitch.rotation.x = clamp(camera_pitch.rotation.x, -PITCH_LIMIT, PITCH_LIMIT)


func _handle_mouse_button(mb: InputEventMouseButton) -> void:
	if not mb.pressed:
		return
	match mb.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			_zoom_target_fov = clampf(_zoom_target_fov - ZOOM_STEP, ZOOM_MIN_FOV, ZOOM_MAX_FOV)
		MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_target_fov = clampf(_zoom_target_fov + ZOOM_STEP, ZOOM_MIN_FOV, ZOOM_MAX_FOV)
		MOUSE_BUTTON_RIGHT:
			if absf(_zoom_target_fov - ZOOM_DEFAULT_FOV) < 0.5:
				_zoom_target_fov = ZOOM_ADS_FOV
			else:
				_zoom_target_fov = ZOOM_DEFAULT_FOV


func _handle_key(k: InputEventKey) -> void:
	if not k.pressed:
		return
	match k.keycode:
		KEY_X:
			_zoom_target_fov = ZOOM_DEFAULT_FOV
		KEY_1:
			if _weapons.size() >= 1:
				_equip_weapon(0)
		KEY_2:
			if _weapons.size() >= 2:
				_equip_weapon(1)
		KEY_Q:
			# Swap rápido al "última arma usada"
			if _weapons.size() >= 2:
				_equip_weapon((_active_weapon_idx + 1) % _weapons.size())


func _equip_weapon(idx: int) -> void:
	if idx == _active_weapon_idx or idx < 0 or idx >= _weapons.size():
		return
	# Guardar estado del arma actual
	if _active_weapon_idx >= 0 and _active_weapon_idx < _weapon_states.size():
		_weapon_states[_active_weapon_idx] = {
			"in_mag": weapon.in_mag,
			"reserve": weapon.reserve,
		}
	# Equipar la nueva
	_active_weapon_idx = idx
	weapon.equip(_weapons[idx])
	var state: Dictionary = _weapon_states[idx]
	weapon.in_mag = state.get("in_mag", _weapons[idx].mag_size)
	weapon.reserve = state.get("reserve", _weapons[idx].reserve_ammo)
	weapon.ammo_changed.emit(weapon.in_mag, weapon.reserve)
	EventBus.weapon_swapped.emit(_weapons[idx], idx)


func _process(delta: float) -> void:
	camera.fov = lerpf(camera.fov, _zoom_target_fov, delta * 14.0)

	if animator:
		animator.local_velocity = movement.local_velocity
		animator.is_on_floor = is_on_floor()
		animator.is_crouching = movement.is_crouching

	_recoil_pitch = lerpf(_recoil_pitch, 0.0, delta * recoil_decay)
	_recoil_yaw = lerpf(_recoil_yaw, 0.0, delta * (recoil_decay + 2.0))

	var shake_x := 0.0
	var shake_y := 0.0
	if _shake_intensity > 0.001:
		var amp := _shake_intensity * shake_amplitude
		shake_x = RNG.randf_range(-amp, amp)
		shake_y = RNG.randf_range(-amp, amp)
		_shake_intensity = maxf(0.0, _shake_intensity - delta * shake_decay)

	if recoil_pivot:
		recoil_pivot.rotation.x = _recoil_pitch + shake_x
		recoil_pivot.rotation.y = _recoil_yaw + shake_y


func _physics_process(_delta: float) -> void:
	weapon.handle_fire_input(
		Input.is_action_pressed(&"fire"),
		Input.is_action_just_pressed(&"fire")
	)
	if Input.is_action_just_pressed(&"reload"):
		weapon.try_reload()


func _on_reload_started() -> void:
	if animator and weapon.current:
		animator.trigger_reload(weapon.current.reload_time)
	AudioManager.play_3d(&"reload_click", global_position, -8.0, 0.04, 30.0)


func _on_step() -> void:
	AudioManager.play_3d(&"footstep", global_position, -10.0, 0.10, 35.0)


func _on_weapon_shot_fired(_data: WeaponData, _end_point: Vector3, _hit_data: Dictionary) -> void:
	if weapon.current == null:
		return
	var kick: Vector2 = weapon.current.recoil_kick
	_recoil_pitch += kick.y * recoil_pitch_factor
	_recoil_yaw += RNG.randf_range(-1.0, 1.0) * kick.x * recoil_yaw_factor


func _on_player_damaged(amount: float, _source: Node) -> void:
	if animator:
		animator.flash_hit(0.12)
	_shake_intensity = clampf(_shake_intensity + amount * 0.04, 0.0, shake_max)
	EventBus.entity_damaged.emit(self, amount)


func _on_died() -> void:
	EventBus.player_died.emit(self)
	GameState.mode = GameState.Mode.GAME_OVER
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_physics_process(false)
	set_process_input(false)
	print("[Player] muerto — game over")


func _on_setting_changed(key: StringName, value: Variant) -> void:
	if key == &"mouse_sensitivity":
		_mouse_sensitivity = float(value)
