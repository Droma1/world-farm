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
@onready var weapon_mount: Marker3D = $WeaponMount

var _mouse_sensitivity: float = 0.003
const PITCH_LIMIT: float = deg_to_rad(70.0)

const ZOOM_DEFAULT_FOV: float = 70.0
const ZOOM_ADS_FOV: float = 35.0
const ZOOM_MIN_FOV: float = 20.0
const ZOOM_MAX_FOV: float = 80.0
const ZOOM_STEP: float = 8.0
var _zoom_target_fov: float = ZOOM_DEFAULT_FOV

# ADS (Aim Down Sights): además del FOV, el spring arm acerca la cámara al
# hombro y el arma se mueve al centro de pantalla. is_ads = true cuando el
# FOV objetivo está por debajo del default (RMB, scroll-zoom o sniper).
const SPRING_ARM_DEFAULT: float = 3.5
const SPRING_ARM_ADS: float = 1.6
const WEAPON_MOUNT_DEFAULT: Vector3 = Vector3(0.18, 0.55, -0.25)
const WEAPON_MOUNT_ADS: Vector3 = Vector3(0.0, 0.55, -0.45)
@export var ads_lerp_speed: float = 12.0

@export_group("Dash")
@export var dash_distance: float = 7.0           ## m de distancia
@export var dash_duration: float = 0.18           ## s — el body avanza linealmente
@export var dash_cooldown: float = 1.5
@export var dash_double_tap_window: float = 0.28
@export var dash_invuln_duration: float = 0.20
var _dash_cd: float = 0.0
var _dash_t: float = 0.0
var _dashing: bool = false
var _dash_dir: Vector3 = Vector3.ZERO
# Última pulsación (-1 = ninguna; tracked por acción)
var _last_press_t: Dictionary = {
	&"move_forward": -10.0, &"move_back": -10.0,
	&"move_left": -10.0, &"move_right": -10.0,
}
var _press_count: Dictionary = {
	&"move_forward": 0, &"move_back": 0, &"move_left": 0, &"move_right": 0,
}

@export_group("Quick melee")
@export var quick_melee_damage: float = 50.0
@export var quick_melee_range: float = 2.2
@export var quick_melee_cooldown: float = 0.7
var _quick_melee_cd: float = 0.0

@export_group("Hold breath (sniper)")
@export var hold_breath_max_duration: float = 5.0  ## seg que aguantas la respiración
@export var hold_breath_recovery: float = 1.5      ## /s recovery cuando sueltas
var hold_breath_remaining: float = 5.0
var holding_breath_active: bool = false

@export_group("Knife throw")
@export var thrown_knife_scene: PackedScene
@export var thrown_knife_speed: float = 22.0
@export var thrown_knife_cooldown: float = 1.2
var _thrown_knife_cd: float = 0.0

@export_group("Grenades")
@export var grenade_scene: PackedScene
@export var grenade_count_start: int = 2
@export var smoke_count_start: int = 2
@export var flash_count_start: int = 2
@export var grenade_throw_force: float = 14.0   ## velocidad inicial m/s al lanzar
@export var grenade_throw_up: float = 4.0       ## componente Y para arc bonito
@export var grenade_cooldown: float = 0.8       ## seg entre lanzamientos

var grenades_left: int = 0
var smokes_left: int = 0
var flashes_left: int = 0
var _grenade_cd: float = 0.0

@export_group("Boss orbit")
@export var boss_orbit_duration: float = 1.6     ## seg de duración del orbit
@export var boss_orbit_radius: float = 6.0       ## m de distancia al boss
@export var boss_orbit_height: float = 2.0       ## altura sobre el boss
@export var boss_orbit_revolutions: float = 0.85 ## fracción de vuelta
var _orbiting: bool = false
var _orbit_t: float = 0.0
var _orbit_target: Node3D = null
var _orbit_input_block: bool = false

@export_group("Health regen")
@export var health_regen_delay: float = 4.0    ## seg sin recibir daño antes de regenerar
@export var health_regen_per_second: float = 8.0
var _regen_timer: float = 0.0

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

	# Construir inventario de armas. Si hay loadout custom desde Settings,
	# úsalo; si no, fallback a CharacterData.starting_weapons.
	if Settings.loadout_weapon_ids.size() > 0 and data and data.starting_weapons:
		var lookup: Dictionary = {}
		for w in data.starting_weapons:
			if w:
				lookup[String(w.id)] = w
		# Permitimos también armas que no estén en starting_weapons pero
		# existan en resources/weapons/. Cargamos por ID.
		var by_path: Dictionary = {
			"rifle_basic": "res://resources/weapons/rifle_basic.tres",
			"pistol_basic": "res://resources/weapons/pistol_basic.tres",
			"knife_basic": "res://resources/weapons/knife_basic.tres",
			"shotgun_basic": "res://resources/weapons/shotgun_basic.tres",
			"rifle_sniper": "res://resources/weapons/rifle_sniper.tres",
		}
		for wid in Settings.loadout_weapon_ids:
			if lookup.has(wid):
				_weapons.append(lookup[wid])
			elif by_path.has(wid):
				var w := load(by_path[wid]) as WeaponData
				if w:
					_weapons.append(w)
	if _weapons.is_empty() and data:
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
	# Iron Mode: sin granadas y sin regen pasivo. Compensa con +60% score.
	if Settings.iron_mode:
		grenades_left = 0
		smokes_left = 0
		flashes_left = 0
		health_regen_per_second = 0.0
	else:
		grenades_left = Settings.loadout_grenade_count if Settings.loadout_grenade_count > 0 else grenade_count_start
		smokes_left = smoke_count_start
		flashes_left = flash_count_start


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
			# Si llevamos cuchillo, RMB lanza un cuchillo (alt-fire) en vez de ADS.
			if weapon and weapon.current and weapon.current.max_range < 5.0:
				_try_throw_knife()
			elif absf(_zoom_target_fov - ZOOM_DEFAULT_FOV) < 0.5:
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
		KEY_4:
			if _weapons.size() >= 4:
				_equip_weapon(3)
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

	# Health regen pasivo: tras N segundos sin daño, regenera lento.
	if health and health.is_alive():
		if _regen_timer > 0.0:
			_regen_timer -= delta
		elif health.current_health < health.max_health:
			health.heal(health_regen_per_second * delta)

	# Boss orbit cinematic: rota body.rotation.y para apuntar a una órbita
	# alrededor del target. Slow-mo + bloqueo de input mientras dura.
	if _orbiting:
		_tick_boss_orbit(delta)

	# Hold breath: solo activo si arma actual es sniper Y player está en ADS
	# Y tiene Shift pulsado. Consume hold_breath_remaining; si se agota,
	# desactiva y entra en recovery (no puede aguantar de nuevo hasta llenarse).
	var sniper_ads: bool = false
	if weapon and weapon.current and "id" in weapon.current:
		var w_id := String(weapon.current.id)
		sniper_ads = w_id.contains("sniper") and camera.fov < 50.0
	var want_hold: bool = sniper_ads and Input.is_action_pressed(&"sprint") and hold_breath_remaining > 0.1
	holding_breath_active = want_hold
	if holding_breath_active:
		hold_breath_remaining = maxf(0.0, hold_breath_remaining - delta)
	else:
		hold_breath_remaining = minf(hold_breath_max_duration, hold_breath_remaining + hold_breath_recovery * delta)

	# ADS visual: spring arm acerca + WeaponMount al centro de pantalla.
	# Detectamos ADS comparando el FOV objetivo con el default.
	var ads_factor: float = clampf((ZOOM_DEFAULT_FOV - _zoom_target_fov) / (ZOOM_DEFAULT_FOV - ZOOM_ADS_FOV), 0.0, 1.0)
	if spring_arm:
		var target_arm: float = lerpf(SPRING_ARM_DEFAULT, SPRING_ARM_ADS, ads_factor)
		spring_arm.spring_length = lerpf(spring_arm.spring_length, target_arm, delta * ads_lerp_speed)
	if weapon_mount:
		var target_mount: Vector3 = WEAPON_MOUNT_DEFAULT.lerp(WEAPON_MOUNT_ADS, ads_factor)
		weapon_mount.position = weapon_mount.position.lerp(target_mount, delta * ads_lerp_speed)

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


func _physics_process(delta: float) -> void:
	if _orbit_input_block:
		# Durante orbit cinematic, congelar input de fuego/recarga/granada.
		if movement:
			movement.external_wish_dir = Vector3.ZERO
		return

	# Dash: detectar double-tap de cualquier dirección y aplicar impulso.
	if _dash_cd > 0.0:
		_dash_cd = maxf(0.0, _dash_cd - delta)
	if _dashing:
		_tick_dash(delta)
	else:
		_check_dash_input()

	weapon.handle_fire_input(
		Input.is_action_pressed(&"fire"),
		Input.is_action_just_pressed(&"fire")
	)
	if Input.is_action_just_pressed(&"reload"):
		weapon.try_reload()
	if _grenade_cd > 0.0:
		_grenade_cd = maxf(0.0, _grenade_cd - delta)
	if Input.is_action_just_pressed(&"throw_grenade"):
		_try_throw_grenade(0)
	if Input.is_action_just_pressed(&"throw_smoke"):
		_try_throw_grenade(1)
	if Input.is_action_just_pressed(&"throw_flash"):
		_try_throw_grenade(2)
	if _quick_melee_cd > 0.0:
		_quick_melee_cd = maxf(0.0, _quick_melee_cd - delta)
	if _thrown_knife_cd > 0.0:
		_thrown_knife_cd = maxf(0.0, _thrown_knife_cd - delta)
	if Input.is_action_just_pressed(&"quick_melee"):
		_try_quick_melee()


func _check_dash_input() -> void:
	if _dash_cd > 0.0:
		return
	var now: float = Time.get_ticks_msec() * 0.001
	for action in _last_press_t.keys():
		if Input.is_action_just_pressed(action):
			var since: float = now - _last_press_t[action]
			_last_press_t[action] = now
			if since < dash_double_tap_window:
				# Double-tap! dash en la dirección de la acción
				_start_dash(_dir_for_action(action))
				return


func _dir_for_action(action: StringName) -> Vector3:
	var basis := global_transform.basis
	match action:
		&"move_forward": return -basis.z
		&"move_back": return basis.z
		&"move_left": return -basis.x
		&"move_right": return basis.x
	return -basis.z


func _start_dash(dir: Vector3) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.001:
		return
	_dashing = true
	_dash_t = 0.0
	_dash_dir = dir.normalized()
	_dash_cd = dash_cooldown
	# Invuln durante el dash + ventana corta extra.
	if health:
		health.invulnerable = true
		var t := get_tree().create_timer(dash_invuln_duration)
		t.timeout.connect(func():
			if health:
				health.invulnerable = false
		)
	# FOV punch para vender el feel.
	camera.fov = clampf(camera.fov + 8.0, ZOOM_MIN_FOV, ZOOM_MAX_FOV)
	# Sound (reutilizamos swoosh).
	AudioManager.play_3d(&"knife_swoosh", global_position, -10.0, 0.10, 25.0)


func _tick_dash(delta: float) -> void:
	_dash_t += delta
	var p: float = clampf(_dash_t / dash_duration, 0.0, 1.0)
	# Velocidad horizontal constante = distance / duration; aplicada como velocity
	# para que move_and_slide del MovementComponent la consuma.
	var speed: float = dash_distance / max(dash_duration, 0.01)
	if movement:
		# Usamos external_wish_dir + velocidad mediante seteo directo del body.
		velocity.x = _dash_dir.x * speed
		velocity.z = _dash_dir.z * speed
	if p >= 1.0:
		_dashing = false


func start_boss_orbit(target: Node3D) -> void:
	if not is_instance_valid(target):
		return
	_orbiting = true
	_orbit_t = 0.0
	_orbit_target = target
	_orbit_input_block = true
	# Slow-mo profundo durante el orbit (el timer escala con time_scale=false
	# para que NO se afecte por el slow-mo y restaure exacto).
	Engine.time_scale = 0.45
	var t := get_tree().create_timer(boss_orbit_duration * 0.45, true, false, true)
	t.timeout.connect(func():
		Engine.time_scale = 1.0
		_orbiting = false
		_orbit_input_block = false
		_orbit_target = null
	)


func _tick_boss_orbit(delta: float) -> void:
	if _orbit_target == null or not is_instance_valid(_orbit_target):
		_orbiting = false
		return
	_orbit_t += delta
	var p: float = clampf(_orbit_t / boss_orbit_duration, 0.0, 1.0)
	# Smoothstep para entrada/salida suave
	var s: float = smoothstep(0.0, 1.0, p)
	var angle: float = s * boss_orbit_revolutions * TAU
	var target_pos: Vector3 = _orbit_target.global_position
	var orbit_pos: Vector3 = target_pos + Vector3(cos(angle), 0.0, sin(angle)) * boss_orbit_radius
	# Body rotation para mirar al boss desde la posición orbital.
	var to_target: Vector3 = (target_pos - orbit_pos).normalized()
	var yaw: float = atan2(to_target.x, to_target.z) + PI
	rotation.y = yaw
	# Para que la cámara realmente esté en orbit_pos, movemos al body. Es un
	# hack barato pero efectivo: el player "vuela" alrededor del boss.
	global_position = global_position.lerp(orbit_pos + Vector3(0, boss_orbit_height, 0), delta * 6.0)


func _try_throw_knife() -> void:
	if _thrown_knife_cd > 0.0 or thrown_knife_scene == null:
		return
	_thrown_knife_cd = thrown_knife_cooldown
	if animator:
		animator.trigger_attack(0.32)
	AudioManager.play_3d(&"knife_swoosh", global_position, -6.0, 0.10, 25.0)
	var k := thrown_knife_scene.instantiate() as RigidBody3D
	if k == null:
		return
	get_tree().current_scene.add_child(k)
	var cam_basis := camera.global_transform.basis
	var spawn_pos: Vector3 = camera.global_position + (-cam_basis.z) * 0.6
	# Orientar el cuchillo hacia la dirección de tiro (forward = -Z local).
	k.global_transform = Transform3D(cam_basis, spawn_pos)
	k.linear_velocity = -cam_basis.z * thrown_knife_speed + Vector3.UP * 1.5
	if "thrower" in k:
		k.thrower = self


func _try_quick_melee() -> void:
	if _quick_melee_cd > 0.0:
		return
	_quick_melee_cd = quick_melee_cooldown
	# Animación visual: trigger attack en el animator (slash arm).
	if animator:
		animator.trigger_attack(0.32)
	AudioManager.play_3d(&"knife_swoosh", global_position, -6.0, 0.10, 25.0)
	# Hitscan corto desde la cámara hacia adelante.
	var space := get_world_3d().direct_space_state
	var origin: Vector3 = camera.global_position
	var dir: Vector3 = -camera.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * quick_melee_range)
	query.exclude = [get_rid()]
	var result := space.intersect_ray(query)
	if result.is_empty():
		return
	var collider: Object = result.get("collider")
	# Healthcomponent del colisor
	var hp: HealthComponent = null
	if collider is Node:
		for ch in (collider as Node).get_children():
			if ch is HealthComponent:
				hp = ch
				break
	if hp == null:
		return
	var dmg: float = quick_melee_damage * GameState.damage_multiplier()
	hp.take_damage(dmg, self)
	EventBus.damage_dealt.emit(collider, dmg, self)
	EventBus.impact.emit(result.get("position", origin), result.get("normal", Vector3.UP), collider)


func _try_throw_grenade(type: int) -> void:
	# type: 0=STANDARD, 1=SMOKE, 2=FLASH
	if _grenade_cd > 0.0 or grenade_scene == null:
		return
	var inv: int = 0
	match type:
		0: inv = grenades_left
		1: inv = smokes_left
		2: inv = flashes_left
	if inv <= 0:
		return
	var g := grenade_scene.instantiate() as RigidBody3D
	if g == null:
		return
	get_tree().current_scene.add_child(g)
	if "grenade_type" in g:
		g.grenade_type = type
	var cam_basis := camera.global_transform.basis
	var spawn_pos: Vector3 = camera.global_position + (-cam_basis.z) * 0.6 + Vector3(0, -0.1, 0)
	g.global_position = spawn_pos
	var dir: Vector3 = -cam_basis.z
	g.linear_velocity = dir * grenade_throw_force + Vector3.UP * grenade_throw_up
	g.angular_velocity = Vector3(RNG.randf_range(-3, 3), RNG.randf_range(-3, 3), RNG.randf_range(-3, 3))
	if "thrower" in g:
		g.thrower = self
	match type:
		0: grenades_left -= 1
		1: smokes_left -= 1
		2: flashes_left -= 1
	_grenade_cd = grenade_cooldown
	EventBus.grenade_thrown.emit(grenades_left)


func _on_reload_started() -> void:
	if animator and weapon.current:
		animator.trigger_reload(weapon.current.reload_time)
	# Cronometrar 3 sonidos con las 3 fases visuales: mag-out → mag-in → bolt-pull.
	if weapon.current:
		var dur: float = weapon.current.reload_time
		AudioManager.play_3d(&"reload_mag_out", global_position, -8.0, 0.04, 30.0)
		var t1 := get_tree().create_timer(dur * 0.45)
		t1.timeout.connect(func(): AudioManager.play_3d(&"reload_mag_in", global_position, -8.0, 0.04, 30.0))
		var t2 := get_tree().create_timer(dur * 0.85)
		t2.timeout.connect(func(): AudioManager.play_3d(&"reload_bolt", global_position, -10.0, 0.04, 30.0))


func _on_step() -> void:
	AudioManager.play_3d(&"footstep", global_position, -10.0, 0.10, 35.0)


func _on_weapon_shot_fired(data: WeaponData, _end_point: Vector3, _hit_data: Dictionary) -> void:
	if weapon.current == null:
		return
	var kick: Vector2 = weapon.current.recoil_kick
	_recoil_pitch += kick.y * recoil_pitch_factor
	_recoil_yaw += RNG.randf_range(-1.0, 1.0) * kick.x * recoil_yaw_factor
	# Slash animation + swoosh cuando golpea con cuchillo (max_range corto = melee)
	if data and data.max_range < 5.0:
		if animator:
			animator.trigger_attack(0.32)
		AudioManager.play_3d(&"knife_swoosh", global_position, -6.0, 0.10, 25.0)


func _on_player_damaged(amount: float, _source: Node) -> void:
	if animator:
		animator.flash_hit(0.12)
	_shake_intensity = clampf(_shake_intensity + amount * 0.04, 0.0, shake_max)
	_regen_timer = health_regen_delay
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

	# Death cam: si murió por un enemigo, gira el body para apuntar al killer
	# antes de la animación de caída. Slow-mo breve para feel cinemático.
	var killer: Node = health.last_damage_source if health else null
	if killer is Node3D and is_instance_valid(killer):
		var to_killer: Vector3 = (killer as Node3D).global_position - global_position
		to_killer.y = 0.0
		if to_killer.length_squared() > 0.001:
			var target_yaw: float = atan2(to_killer.x, to_killer.z) + PI
			# Tween rotación Y del body para encarar al killer.
			var face_tween := create_tween()
			face_tween.tween_property(self, "rotation:y", target_yaw, 0.45) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# Slow-mo durante la muerte (ignora pause del Engine).
		Engine.time_scale = 0.5
		var rest_t := get_tree().create_timer(0.6, true, false, true)
		rest_t.timeout.connect(func(): Engine.time_scale = 1.0)

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
