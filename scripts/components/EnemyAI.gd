class_name EnemyAI
extends Node
## State machine simple para enemigos: IDLE → CHASE → ATTACK → DEAD.
## - IDLE: quieto, escanea hasta detectar al Player local.
## - CHASE: navega hacia el Player vía NavigationAgent3D (rodea muros).
##          Fallback a línea recta si no hay path o no es alcanzable.
## - ATTACK: se detiene a stop_range, gira a apuntar y dispara.
## - DEAD: nada (queue_free lo decide el entity).

signal state_changed(new_state: int)

enum State { IDLE, CHASE, ATTACK, DEAD }

@export var data: EnemyData
@export var aim_provider_path: NodePath  # Marker3D a la altura del pecho, "ojos"
@export var nav_agent_path: NodePath     # NavigationAgent3D opcional

var state: State = State.IDLE
var body: CharacterBody3D
var movement: MovementComponent
var weapon: WeaponComponent
var aim_provider: Node3D
var nav_agent: NavigationAgent3D


func _ready() -> void:
	body = get_parent() as CharacterBody3D
	assert(body != null, "EnemyAI: el padre debe ser CharacterBody3D")
	movement = body.get_node_or_null("MovementComponent") as MovementComponent
	weapon = body.get_node_or_null("WeaponComponent") as WeaponComponent
	aim_provider = get_node_or_null(aim_provider_path) as Node3D
	nav_agent = get_node_or_null(nav_agent_path) as NavigationAgent3D

	if movement:
		movement.read_input = false
		if data:
			movement.walk_speed = data.move_speed
	if weapon and aim_provider:
		weapon.setup(aim_provider, body)
		if data and data.weapon:
			weapon.equip(data.weapon)

	# Empezar agresivo: si hay un Player en la escena, ir directamente a
	# CHASE en vez de quedarse en IDLE esperando entrar en detection_range.
	# Esto es lo que el jugador espera en un mapa de entrenamiento: los
	# enemigos vienen a por él desde el momento del spawn.
	if GameState.local_player != null:
		state = State.CHASE


func mark_dead() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	state_changed.emit(state)
	if movement:
		movement.external_wish_dir = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if state == State.DEAD or movement == null:
		return
	# Si el juego no está activo (game over / victoria), congelar enemigos.
	if GameState.mode != GameState.Mode.PLAYING:
		movement.external_wish_dir = Vector3.ZERO
		return
	var player := GameState.local_player as Node3D
	if player == null:
		_set_idle()
		return

	var to_player := player.global_position - body.global_position
	to_player.y = 0.0
	var distance := to_player.length()
	var direct_dir: Vector3 = to_player.normalized() if distance > 0.001 else Vector3.ZERO

	match state:
		State.IDLE:
			movement.external_wish_dir = Vector3.ZERO
			if data and distance < data.detection_range:
				_change_state(State.CHASE)

		State.CHASE:
			if data == null:
				return
			if distance > data.lose_target_range:
				_change_state(State.IDLE)
			elif distance < data.attack_range and _has_line_of_sight(player):
				_change_state(State.ATTACK)
			else:
				var move_dir := _navigate_to(player.global_position, direct_dir)
				if distance > data.stop_range:
					movement.external_wish_dir = move_dir
				else:
					movement.external_wish_dir = Vector3.ZERO
				# Mirar en la dirección de movimiento (no hacia el player directo,
				# evita que vayan de costado al rodear obstáculos).
				_face_direction(move_dir if move_dir.length_squared() > 0.01 else direct_dir, delta)

		State.ATTACK:
			movement.external_wish_dir = Vector3.ZERO
			_face_direction(direct_dir, delta)
			if data == null:
				return
			if distance > data.attack_range * 1.15 or not _has_line_of_sight(player):
				_change_state(State.CHASE)
			elif weapon:
				weapon.handle_fire_input(true, false)


func _navigate_to(target_world: Vector3, fallback_dir: Vector3) -> Vector3:
	if nav_agent == null:
		return fallback_dir
	nav_agent.target_position = target_world
	# Si el target no es alcanzable o ya estamos en él, fallback directo.
	if nav_agent.is_navigation_finished():
		return Vector3.ZERO
	if not nav_agent.is_target_reachable():
		return fallback_dir
	var next_pos := nav_agent.get_next_path_position()
	var to_next := next_pos - body.global_position
	to_next.y = 0.0
	if to_next.length() < 0.05:
		return fallback_dir
	return to_next.normalized()


func _set_idle() -> void:
	if state != State.IDLE:
		_change_state(State.IDLE)
	if movement:
		movement.external_wish_dir = Vector3.ZERO


func _change_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(new_state)


func _face_direction(dir: Vector3, delta: float) -> void:
	if dir.length_squared() < 0.001:
		return
	var target_yaw := atan2(dir.x, dir.z) + PI
	var turn: float = data.turn_speed if data else 6.0
	body.rotation.y = lerp_angle(body.rotation.y, target_yaw, clampf(turn * delta, 0.0, 1.0))


func _has_line_of_sight(target: Node3D) -> bool:
	if aim_provider == null or not is_instance_valid(target):
		return true
	var space := body.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		aim_provider.global_position,
		target.global_position + Vector3(0, 1.4, 0)
	)
	query.exclude = [body.get_rid()]
	var result := space.intersect_ray(query)
	if result.is_empty():
		return true
	return result.get("collider") == target
