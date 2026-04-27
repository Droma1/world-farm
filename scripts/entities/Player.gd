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
@onready var health: HealthComponent = $HealthComponent
@onready var movement: MovementComponent = $MovementComponent
@onready var weapon: WeaponComponent = $WeaponComponent
@onready var animator: HumanoidAnimator = $HumanoidAnimator
@onready var visuals: Node3D = $Visuals

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
	# Ctrl + rueda → ciclar armas (wrap-around). Sin Ctrl, comportamiento normal.
	if mb.ctrl_pressed and (
		mb.button_index == MOUSE_BUTTON_WHEEL_UP
		or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN
	):
		_cycle_weapon(1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
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
		KEY_3:
			if _weapons.size() >= 3:
				_equip_weapon(2)
		KEY_Q:
			# Swap rápido al "última arma usada"
			if _weapons.size() >= 2:
				_equip_weapon((_active_weapon_idx + 1) % _weapons.size())


func _cycle_weapon(direction: int) -> void:
	var n: int = _weapons.size()
	if n < 2:
		return
	var next_idx: int = ((_active_weapon_idx + direction) % n + n) % n
	_equip_weapon(next_idx)


func _equip_weapon(idx: int) -> void:
	if idx == _active_weapon_idx or idx < 0 or idx >= _weapons.size():
		return
	# Guardar estado del arma actual
	if _active_weapon_idx >= 0 and _active_weapon_idx < _weapon_states.size():
		_weapon_states[_active_weapon_idx] = {
			"in_mag": weapon.in_mag,
			"reserve": weapon.reserve,
		}
	# Equipar la nueva. WeaponComponent.equip() instancia el visual del arma
	# bajo WeaponMount automáticamente, así que no hay que tocarlo aquí.
	_active_weapon_idx = idx
	var data: WeaponData = _weapons[idx]
	weapon.equip(data)
	# Notificar al animator para que cambie la pose base (rifle vs cuchillo)
	if animator:
		animator.set_weapon_data(data)
	var state: Dictionary = _weapon_states[idx]
	weapon.in_mag = state.get("in_mag", data.mag_size)
	weapon.reserve = state.get("reserve", data.reserve_ammo)
	weapon.ammo_changed.emit(weapon.in_mag, weapon.reserve)
	EventBus.weapon_swapped.emit(data, idx)


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


func _on_weapon_shot_fired(data: WeaponData, _end_point: Vector3, _hit_data: Dictionary) -> void:
	if weapon.current == null:
		return
	var kick: Vector2 = weapon.current.recoil_kick
	_recoil_pitch += kick.y * recoil_pitch_factor
	_recoil_yaw += RNG.randf_range(-1.0, 1.0) * kick.x * recoil_yaw_factor
	# Slash animation cuando golpea con cuchillo (max_range corto = melee)
	if animator and data and data.max_range < 5.0:
		animator.trigger_attack(0.32)


func _on_player_damaged(amount: float, _source: Node) -> void:
	if animator:
		animator.flash_hit(0.12)
	_shake_intensity = clampf(_shake_intensity + amount * 0.04, 0.0, shake_max)
	EventBus.entity_damaged.emit(self, amount)
	GameState.notify_player_damaged()


func _on_died() -> void:
	EventBus.player_died.emit(self)
	# Bloquear input pero NO setear GAME_OVER inmediatamente — esperamos que
	# termine la animación de caída para que el HUD muestre el overlay tras
	# el efecto dramático.
	set_physics_process(false)
	set_process_input(false)
	# El MovementComponent corre en su propio _physics_process leyendo
	# Input.get_action_strength directamente — apagarlo para que el cadáver
	# no se mueva con WASD.
	if movement:
		movement.set_physics_process(false)
		movement.read_input = false
		movement.external_wish_dir = Vector3.ZERO
		movement.is_sprinting = false
		movement.is_crouching = false
		velocity = Vector3.ZERO
	# Detener animación procedural — el cadáver queda en su última pose +
	# la rotación del tween. Sin esto, los miembros siguen oscilando.
	if animator:
		animator.set_dead(true)

	# Animación: el capibara cae hacia atrás + cámara al suelo
	var tween := create_tween().set_parallel(true)
	if visuals:
		tween.tween_property(visuals, "rotation:x", deg_to_rad(75), 0.7) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if camera_pitch:
		tween.tween_property(camera_pitch, "rotation:x", deg_to_rad(-50), 0.8) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Tras la caída, dar el control al GameState (HUD muestra overlay).
	tween.chain().tween_interval(0.4)
	tween.chain().tween_callback(func():
		GameState.mode = GameState.Mode.GAME_OVER
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	)


func _on_setting_changed(key: StringName, value: Variant) -> void:
	if key == &"mouse_sensitivity":
		_mouse_sensitivity = float(value)
