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


func _ready() -> void:
	body = get_parent() as CharacterBody3D
	assert(body != null, "MovementComponent: el padre debe ser CharacterBody3D")
	_collision_shape = body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	# Duplicar el Shape para que cada instancia tenga el suyo (si no, todos
	# los Players/Enemies compartirían la misma cápsula y crouch los afectaría
	# a todos).
	if _collision_shape and _collision_shape.shape:
		_collision_shape.shape = _collision_shape.shape.duplicate()


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

	if want_crouch and want_sprint:
		want_sprint = false
	if want_crouch != is_crouching:
		is_crouching = want_crouch
		crouch_changed.emit(is_crouching)
	is_sprinting = want_sprint and wish_dir.length_squared() > 0.01 and not is_crouching

	var target_speed: float
	if is_crouching:
		target_speed = crouch_speed
	elif is_sprinting:
		target_speed = sprint_speed
	else:
		target_speed = walk_speed

	var accel: float = acceleration if body.is_on_floor() else acceleration * air_control

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
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
