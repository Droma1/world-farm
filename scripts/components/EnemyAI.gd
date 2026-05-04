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
var animator: HumanoidAnimator
var aim_provider: Node3D
var nav_agent: NavigationAgent3D

# Strafe en ATTACK: el enemigo da pasos laterales aleatorios para no ser
# un blanco estático. _strafe_remaining > 0 significa "moviéndose ahora".
# _strafe_cooldown contabiliza el tiempo hasta el próximo strafe.
var _strafe_cooldown: float = 1.5
var _strafe_remaining: float = 0.0
var _strafe_dir: Vector3 = Vector3.ZERO

# Hit stagger: cuando recibe daño, la AI se pausa ~0.12 s y el body se empuja
# levemente en la dirección del impacto. Hace que el feedback de "le pegué"
# sea inmediato y visible.
var _stagger_t: float = 0.0
@export var stagger_duration: float = 0.12
@export var stagger_pushback: float = 1.4

# Flag latch para que ALPHA solo invoque refuerzos UNA vez al cruzar 50% HP.
var _alpha_called_reinforcements: bool = false

# Smoke grenades activas. Cada entry: {pos, radius, expire_at_ms}.
static var _active_smokes: Array[Dictionary] = []

# Cover seeking: cuando el enemy está bajo 50% HP o recargando, busca un
# punto cercano detrás de un StaticBody para cubrirse. Probamos N puntos
# alrededor de la dirección opuesta al player y verificamos que la línea
# player → cover_point esté bloqueada.
@export var cover_search_attempts: int = 8
@export var cover_search_radius: float = 6.0
var _cover_target: Vector3 = Vector3.INF
var _cover_search_cd: float = 0.0

# Squad: cada enemigo tiene un ángulo "preferido" alrededor del player para
# que la escuadra se abra en abanico al perseguir, no se amontonen todos.
# Se calcula una vez en _ready a partir del instance_id.
var _squad_angle: float = 0.0

# Acciones tácticas aleatorias mientras persigue/ataca: agacharse para cubrirse,
# saltar para verse más dinámico. _tactical_timer cuenta hasta la próxima decisión.
var _tactical_timer: float = 0.0
var _crouch_release_at: float = -1.0  # tiempo (s desde inicio) al que liberar el crouch


func _ready() -> void:
	body = get_parent() as CharacterBody3D
	assert(body != null, "EnemyAI: el padre debe ser CharacterBody3D")
	movement = body.get_node_or_null("MovementComponent") as MovementComponent
	weapon = body.get_node_or_null("WeaponComponent") as WeaponComponent
	animator = body.get_node_or_null("HumanoidAnimator") as HumanoidAnimator
	aim_provider = get_node_or_null(aim_provider_path) as Node3D
	nav_agent = get_node_or_null(nav_agent_path) as NavigationAgent3D
	# Suscripciones a granadas tácticas
	EventBus.flashbang_exploded.connect(_on_flashbang_exploded)
	EventBus.smoke_deployed.connect(_on_smoke_deployed)

	if movement:
		movement.read_input = false
		if data:
			movement.walk_speed = data.move_speed
	if weapon and aim_provider:
		weapon.setup(aim_provider, body)
		if data and data.weapon:
			weapon.equip(data.weapon)
			# Notificar al animator para que use la pose correcta (rifle vs cuchillo)
			if animator:
				animator.set_weapon_data(data.weapon)

	# Squad angle: ángulo único por enemigo para que la escuadra se abra en
	# abanico alrededor del player en vez de amontonarse en un solo punto.
	# Hash del instance_id da un valor determinístico distinto por enemigo.
	_squad_angle = wrapf(float(get_instance_id()) * 0.6180339887, 0.0, TAU)
	_tactical_timer = RNG.randf_range(2.0, 5.0)

	# Empezar agresivo
	if GameState.local_player != null:
		state = State.CHASE


func mark_dead() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	state_changed.emit(state)
	if movement:
		movement.external_wish_dir = Vector3.ZERO


## Llamado por Enemy.gd cuando recibe daño. Pausa la AI brevemente y
## empuja el body en la dirección del impacto para que el hit se sienta.
func notify_hit(impact_dir: Vector3) -> void:
	if state == State.DEAD:
		return
	_stagger_t = stagger_duration
	if body and body.is_on_floor():
		# Empujón horizontal — preserva la velocidad vertical (gravedad/jump).
		var push := impact_dir
		push.y = 0.0
		if push.length_squared() > 0.001:
			push = push.normalized() * stagger_pushback
			body.velocity.x = push.x
			body.velocity.z = push.z


func _physics_process(delta: float) -> void:
	if state == State.DEAD or movement == null:
		return
	# Si el juego no está activo (game over / victoria), congelar enemigos.
	if GameState.mode != GameState.Mode.PLAYING:
		movement.external_wish_dir = Vector3.ZERO
		return

	# Hit stagger: la AI se pausa unos ms tras recibir daño. Dejamos que
	# movement aplique velocity pero sin nuevas decisiones de wish_dir.
	if _stagger_t > 0.0:
		_stagger_t -= delta
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
				# Squad target: posición offset alrededor del player según el
				# ángulo único de este enemigo. Hace que la escuadra se abra
				# en abanico en vez de pegarse todos al mismo punto.
				var squad_target := _squad_position_around(player.global_position)
				var move_dir := _navigate_to(squad_target, direct_dir)
				# El SWIFT ignora stop_range — siempre rushea hasta al lado.
				var rush := data.archetype == EnemyData.Archetype.SWIFT
				if rush or distance > data.stop_range:
					movement.external_wish_dir = move_dir
				else:
					movement.external_wish_dir = Vector3.ZERO
				_face_direction(move_dir if move_dir.length_squared() > 0.01 else direct_dir, delta)
				# Decisiones tácticas: salto ocasional al perseguir
				_tick_tactical(delta, false)

		State.ATTACK:
			_face_direction(direct_dir, delta)
			# Cover seeking: si está herido o recargando, busca cobertura.
			# Si encuentra un cover válido, sobrescribe el wish_dir hacia ahí.
			if _should_seek_cover():
				_tick_cover_seeking(delta, player)
			else:
				_cover_target = Vector3.INF
				_archetype_attack_movement(delta, distance, direct_dir)
			# Decisiones tácticas: agacharse para cubrirse mientras dispara
			_tick_tactical(delta, true)
			if data == null:
				return
			# SNIPER: si el player se acerca demasiado, retrocede a chase para
			# mantener distancia óptima.
			if data.archetype == EnemyData.Archetype.SNIPER and distance < data.stop_range * 0.8:
				_change_state(State.CHASE)
			elif distance > data.attack_range * 1.15 or not _has_line_of_sight(player):
				_change_state(State.CHASE)
			elif weapon:
				weapon.try_fire()
			# ALPHA: invoca refuerzos al -50% HP (una vez).
			_maybe_alpha_call_reinforcements()


func _archetype_attack_movement(delta: float, distance: float, direct_dir: Vector3) -> void:
	## Decide cómo se mueve el enemigo MIENTRAS dispara. Cada arquetipo tiene
	## su patrón propio (strafe, retroceso, kiting, fijo).
	if data == null:
		return
	match data.archetype:
		EnemyData.Archetype.SNIPER:
			# Retrocede si el player está cerca (kite). Si está bien posicionado, fijo.
			if distance < data.stop_range:
				movement.external_wish_dir = -direct_dir
			else:
				movement.external_wish_dir = Vector3.ZERO
		EnemyData.Archetype.HEAVY:
			# Tanky se planta y dispara. Sin strafe.
			movement.external_wish_dir = Vector3.ZERO
		EnemyData.Archetype.SWIFT:
			# Sigue rusheando incluso en attack. No se queda quieto.
			movement.external_wish_dir = direct_dir
		EnemyData.Archetype.ALPHA:
			# Strafe doble velocidad (más impredecible).
			_default_strafe(delta, 2.0)
		_:
			_default_strafe(delta, 1.0)


func _default_strafe(delta: float, intensity: float) -> void:
	_strafe_cooldown -= delta
	if _strafe_remaining > 0.0:
		_strafe_remaining -= delta
		movement.external_wish_dir = _strafe_dir * intensity
	elif _strafe_cooldown <= 0.0:
		var sign_x: float = 1.0 if RNG.randf() < 0.5 else -1.0
		_strafe_dir = body.global_transform.basis.x * sign_x
		_strafe_remaining = RNG.randf_range(0.4, 0.9)
		_strafe_cooldown = RNG.randf_range(1.5, 3.0) / intensity + _strafe_remaining
		movement.external_wish_dir = _strafe_dir * intensity
	else:
		movement.external_wish_dir = Vector3.ZERO


func _maybe_alpha_call_reinforcements() -> void:
	if data == null or data.archetype != EnemyData.Archetype.ALPHA:
		return
	if _alpha_called_reinforcements:
		return
	var hp := body.get_node_or_null("HealthComponent") as HealthComponent
	if hp == null:
		return
	if hp.current_health > hp.max_health * 0.5:
		return
	_alpha_called_reinforcements = true
	# Notifica al WaveSystem (si está) para que spawnee 2 swift extras.
	EventBus.alpha_called_reinforcements.emit(body)


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


func _squad_position_around(player_pos: Vector3) -> Vector3:
	## Punto en un círculo alrededor del player a un poco menos que attack_range,
	## en el ángulo único de este enemigo. Crea distribución en abanico.
	if data == null:
		return player_pos
	var radius: float = data.attack_range * 0.85
	return player_pos + Vector3(cos(_squad_angle), 0.0, sin(_squad_angle)) * radius


func _tick_tactical(delta: float, in_attack: bool) -> void:
	## Decide ocasionalmente si agacharse (cuando ataca) o saltar (cuando persigue).
	if movement == null:
		return
	# Liberar crouch si su tiempo ya pasó
	if _crouch_release_at >= 0.0:
		_crouch_release_at -= delta
		if _crouch_release_at <= 0.0:
			movement.external_crouch = false
			_crouch_release_at = -1.0
	# Decidir nueva acción cuando el timer expira
	_tactical_timer -= delta
	if _tactical_timer > 0.0:
		return
	_tactical_timer = RNG.randf_range(2.5, 5.5)
	var roll := RNG.randf()
	if in_attack and roll < 0.30 and _crouch_release_at < 0.0:
		# Cubrirse: agacharse 1.5-3s mientras dispara desde abajo
		movement.external_crouch = true
		_crouch_release_at = RNG.randf_range(1.5, 3.0)
	elif not in_attack and roll < 0.20 and body.is_on_floor():
		# Saltar mientras persigue (look más dinámico)
		movement.request_jump()


func _should_seek_cover() -> bool:
	if body == null:
		return false
	var hp := body.get_node_or_null("HealthComponent") as HealthComponent
	if hp == null:
		return false
	# Bajo 50% HP, o si está recargando.
	var low_hp: bool = hp.current_health < hp.max_health * 0.5
	var reloading: bool = weapon != null and weapon.has_method("is_reloading") and weapon.is_reloading()
	return low_hp or reloading


func _tick_cover_seeking(delta: float, player: Node3D) -> void:
	# Si no tenemos cover válido aún, buscamos uno (cooldown para no spammear raycasts).
	_cover_search_cd -= delta
	if _cover_target == Vector3.INF and _cover_search_cd <= 0.0:
		_cover_search_cd = 0.5
		_cover_target = _find_cover_point(player)
	if _cover_target == Vector3.INF:
		movement.external_wish_dir = Vector3.ZERO
		return
	var to_cover: Vector3 = _cover_target - body.global_position
	to_cover.y = 0.0
	if to_cover.length() < 0.6:
		# Llegamos al cover; nos quedamos quietos hasta que cambie la situación.
		movement.external_wish_dir = Vector3.ZERO
		return
	var move_dir := _navigate_to(_cover_target, to_cover.normalized())
	movement.external_wish_dir = move_dir


func _find_cover_point(player: Node3D) -> Vector3:
	## Probamos N puntos alrededor de la dirección "opuesta al player" y
	## elegimos el primero cuyo segmento player → cover_point esté bloqueado
	## por un StaticBody (= props decorativos, paredes).
	var space := body.get_world_3d().direct_space_state
	var from_player_to_me: Vector3 = body.global_position - player.global_position
	from_player_to_me.y = 0.0
	if from_player_to_me.length_squared() < 0.001:
		return Vector3.INF
	var base_dir: Vector3 = from_player_to_me.normalized()
	for i in range(cover_search_attempts):
		var angle: float = RNG.randf_range(-PI * 0.55, PI * 0.55)
		var dir := base_dir.rotated(Vector3.UP, angle)
		var candidate: Vector3 = body.global_position + dir * cover_search_radius
		# El raycast es de player a candidate. Si lo bloquea algo distinto al
		# propio enemy, ese punto SÍ es cover (objeto en medio).
		var query := PhysicsRayQueryParameters3D.create(
			player.global_position + Vector3(0, 1.4, 0),
			candidate + Vector3(0, 1.0, 0)
		)
		query.exclude = [body.get_rid()]
		var result := space.intersect_ray(query)
		if not result.is_empty():
			# Hay algo bloqueando — buen cover.
			return candidate
	return Vector3.INF


func _has_line_of_sight(target: Node3D) -> bool:
	if aim_provider == null or not is_instance_valid(target):
		return true
	# Smoke check: si el segmento aim→target cruza un smoke activo, no hay LoS.
	var now: int = Time.get_ticks_msec()
	for smoke in _active_smokes.duplicate():
		if smoke["expire_at_ms"] < now:
			_active_smokes.erase(smoke)
			continue
		# Distancia del centro del smoke al segmento aim → target.
		if _segment_intersects_sphere(
				aim_provider.global_position,
				target.global_position + Vector3(0, 1.4, 0),
				smoke["pos"], smoke["radius"]):
			return false
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


func _segment_intersects_sphere(a: Vector3, b: Vector3, c: Vector3, r: float) -> bool:
	var ab := b - a
	var t: float = clampf((c - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	var closest := a + ab * t
	return closest.distance_to(c) < r


func _on_flashbang_exploded(pos: Vector3, radius: float, stun_duration: float) -> void:
	if body == null or aim_provider == null:
		return
	if pos.distance_to(body.global_position) > radius:
		return
	# LoS check: solo afecta si veo el epicentro.
	var space := body.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(aim_provider.global_position, pos)
	query.exclude = [body.get_rid()]
	if not space.intersect_ray(query).is_empty():
		return
	_stagger_t = stun_duration


func _on_smoke_deployed(pos: Vector3, radius: float, duration: float) -> void:
	_active_smokes.append({
		"pos": pos,
		"radius": radius,
		"expire_at_ms": Time.get_ticks_msec() + int(duration * 1000.0),
	})
