class_name MovementComponent
extends Node
## Mueve un CharacterBody3D padre con WASD + jump + sprint + crouch.
## La dirección de movimiento es relativa al forward del propio body
## (que en TPS rota con el yaw de la cámara).
## Expone estado público (local_velocity, is_sprinting, is_crouching) para
## que el HumanoidAnimator decida la animación procedural.
##
## Crouch encoge la cápsula de colisión dinámicamente (lerp), de modo que
## el jugador puede pasar por túneles bajos solo agachándose.

signal jumped
signal landed
signal crouch_changed(crouching: bool)
signal step  ## Emitido cada step_distance metros caminados en el suelo.

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var crouch_speed: float = 2.5
@export var jump_velocity: float = 6.0
@export var acceleration: float = 25.0
@export var air_control: float = 0.4
@export var read_input: bool = true   # AI/NPC ponen esto en false

@export_group("Crouch collision")
@export var standing_height: float = 1.8
@export var crouch_height: float = 1.0
@export var crouch_resize_speed: float = 10.0

@export_group("Footsteps")
@export var step_distance: float = 1.7         # m entre pasos a velocidad normal
@export var step_distance_sprint: float = 2.2  # zancadas más largas en sprint
@export var step_min_speed: float = 0.5

@export_group("Slide")
@export var slide_initial_speed: float = 13.0
@export var slide_friction: float = 9.0       ## /s decay del slide
@export var slide_min_speed: float = 4.5      ## bajo este, slide termina
@export var slide_cooldown: float = 0.7

var is_sliding: bool = false
var _slide_velocity: Vector3 = Vector3.ZERO
var _slide_cd: float = 0.0

@export_group("Stamina")
@export var max_stamina: float = 100.0
@export var stamina_drain: float = 22.0         # /s al sprintar
@export var stamina_regen: float = 18.0         # /s al no sprintar
@export var stamina_regen_delay: float = 0.6    # s tras parar antes de regenerar
@export var stamina_min_to_sprint: float = 8.0  # umbral para empezar sprint

var stamina: float = 100.0
var _stamina_regen_timer: float = 0.0

# Estado público (animator lee)
var local_velocity: Vector3 = Vector3.ZERO
var is_sprinting: bool = false
var is_crouching: bool = false

# Si read_input == false, NPC inyecta wish_dir + sprint/crouch flags.
var external_wish_dir: Vector3 = Vector3.ZERO
var external_sprint: bool = false
var external_crouch: bool = false

var body: CharacterBody3D
var _was_on_floor: bool = false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _collision_shape: CollisionShape3D
var _walk_distance_acc: float = 0.0


func _ready() -> void:
	body = get_parent() as CharacterBody3D
	assert(body != null, "MovementComponent: el padre debe ser CharacterBody3D")
	_collision_shape = body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	# Duplicar el Shape para que cada instancia tenga el suyo (si no, todos
	# los Players/Enemies compartirían la misma cápsula y crouch los afectaría
	# a todos).
	if _collision_shape and _collision_shape.shape:
		_collision_shape.shape = _collision_shape.shape.duplicate()
	stamina = max_stamina


func _physics_process(delta: float) -> void:
	if body == null:
		return

	var velocity: Vector3 = body.velocity

	if not body.is_on_floor():
		velocity.y -= _gravity * delta

	if body.is_on_floor() and not _was_on_floor:
		landed.emit()
	_was_on_floor = body.is_on_floor()

	var wish_dir: Vector3
	var want_sprint: bool
	var want_crouch: bool
	if read_input:
		var input_vec := Vector2(
			Input.get_action_strength(&"move_right") - Input.get_action_strength(&"move_left"),
			Input.get_action_strength(&"move_forward") - Input.get_action_strength(&"move_back")
		)
		var basis := body.global_transform.basis
		var forward := -basis.z
		var right := basis.x
		forward.y = 0.0
		right.y = 0.0
		forward = forward.normalized()
		right = right.normalized()
		wish_dir = (right * input_vec.x + forward * input_vec.y).normalized() if input_vec.length() > 0.01 else Vector3.ZERO
		want_sprint = Input.is_action_pressed(&"sprint")
		want_crouch = Input.is_action_pressed(&"crouch")
	else:
		wish_dir = external_wish_dir
		want_sprint = external_sprint
		want_crouch = external_crouch

	# Slide: si el player estaba sprintando y pulsa crouch en este frame,
	# se inicia el slide. Mientras dura el slide, el body se mueve por
	# inercia con friction y crouch_height activa.
	if _slide_cd > 0.0:
		_slide_cd = maxf(0.0, _slide_cd - delta)
	if read_input and is_sprinting and Input.is_action_just_pressed(&"crouch") and _slide_cd <= 0.0 and body.is_on_floor():
		is_sliding = true
		_slide_cd = slide_cooldown
		# Velocidad inicial = forward del player × slide_initial_speed
		var fwd: Vector3 = -body.global_transform.basis.z
		fwd.y = 0.0
		_slide_velocity = fwd.normalized() * slide_initial_speed
		want_crouch = true  # forzar crouch durante slide
	if is_sliding:
		# Decay por fricción
		_slide_velocity = _slide_velocity.move_toward(Vector3.ZERO, slide_friction * delta)
		if _slide_velocity.length() < slide_min_speed or not body.is_on_floor():
			is_sliding = false
		else:
			want_crouch = true  # mantener crouch mientras dura

	if want_crouch and want_sprint:
		want_sprint = false
	if want_crouch != is_crouching:
		is_crouching = want_crouch
		crouch_changed.emit(is_crouching)
	# Solo player local consume stamina (NPCs no la tienen).
	var is_player: bool = read_input
	var can_sprint: bool = (not is_player) or stamina > stamina_min_to_sprint
	is_sprinting = want_sprint and wish_dir.length_squared() > 0.01 and not is_crouching and can_sprint
	if is_player:
		if is_sprinting:
			stamina = maxf(0.0, stamina - stamina_drain * delta)
			_stamina_regen_timer = stamina_regen_delay
		else:
			if _stamina_regen_timer > 0.0:
				_stamina_regen_timer -= delta
			else:
				stamina = minf(max_stamina, stamina + stamina_regen * delta)

	var target_speed: float
	if is_crouching:
		target_speed = crouch_speed
	elif is_sprinting:
		target_speed = sprint_speed
	else:
		target_speed = walk_speed

	var accel: float = acceleration if body.is_on_floor() else acceleration * air_control

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if is_sliding:
		# Durante slide, la velocidad horizontal viene del _slide_velocity
		# (no del wish_dir). Esto da la sensación de impulso por inercia.
		velocity.x = _slide_velocity.x
		velocity.z = _slide_velocity.z
	else:
		var target_horizontal := wish_dir * target_speed
		horizontal = horizontal.move_toward(target_horizontal, accel * delta)
		velocity.x = horizontal.x
		velocity.z = horizontal.z

	if read_input and Input.is_action_just_pressed(&"jump") and body.is_on_floor() and not is_crouching:
		velocity.y = jump_velocity
		jumped.emit()

	body.velocity = velocity
	body.move_and_slide()

	# Local velocity: animator decide caminar adelante / atrás
	local_velocity = body.global_transform.basis.inverse() * Vector3(body.velocity.x, 0.0, body.velocity.z)

	# Footsteps: acumula distancia mientras toca suelo y emite cada step_distance.
	if body.is_on_floor():
		var hspeed: float = Vector2(body.velocity.x, body.velocity.z).length()
		if hspeed > step_min_speed:
			_walk_distance_acc += hspeed * delta
			var threshold: float = step_distance_sprint if is_sprinting else step_distance
			if is_crouching:
				threshold *= 1.4  # pasos más espaciados al agacharse
			if _walk_distance_acc >= threshold:
				_walk_distance_acc = 0.0
				step.emit()
		else:
			_walk_distance_acc = 0.0
	else:
		_walk_distance_acc = 0.0

	# Resize dinámico de la cápsula (solo si la shape es CapsuleShape3D)
	if _collision_shape and _collision_shape.shape is CapsuleShape3D:
		var cap := _collision_shape.shape as CapsuleShape3D
		var target_height: float = crouch_height if is_crouching else standing_height
		cap.height = lerpf(cap.height, target_height, delta * crouch_resize_speed)
		_collision_shape.position.y = cap.height * 0.5


func request_jump() -> void:
	if body and body.is_on_floor() and not is_crouching:
		body.velocity.y = jump_velocity
		jumped.emit()
