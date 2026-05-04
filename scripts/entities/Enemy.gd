class_name Enemy
extends CharacterBody3D
## Bot enemigo. Comparte estructura con Player (humanoide + arma) pero
## con AI en vez de input humano. Aplica tint al ready, suma score al
## morir y tiene oportunidad de droppear un pickup.

@export var data: EnemyData
@export var health_pickup_scene: PackedScene
@export var ammo_pickup_scene: PackedScene
@export var speed_pickup_scene: PackedScene
@export var armor_pickup_scene: PackedScene
@export var weapon_pickup_scene: PackedScene
@export var weapon_drop_chance: float = 0.20  ## prob. extra de soltar SU arma

@onready var health: HealthComponent = $HealthComponent
@onready var movement: MovementComponent = $MovementComponent
@onready var weapon: WeaponComponent = $WeaponComponent
@onready var ai: EnemyAI = $EnemyAI
# El animator es duck-typed: HumanoidAnimator (puma) o BlockyAnimator (bloque).
# Ambos exponen los mismos métodos públicos (trigger_reload, trigger_attack,
# flash_hit, tint_body, set_dead, set_weapon_data) y propiedades de input.
@onready var animator: Node = _resolve_animator()
@onready var visuals: Node3D = $Visuals


func _resolve_animator() -> Node:
	for child in get_children():
		if child.has_method("trigger_reload") and child.has_method("trigger_attack"):
			return child
	return null

var _dying: bool = false


func _ready() -> void:
	if data:
		# Multipliers globales por dificultad. Aplicados aquí para que cada
		# enemy escale automáticamente sin tocar los .tres ni la AI.
		var hp_mult: float = Settings.enemy_health_multiplier()
		# Aplicar wave affix si hay uno activo:
		#   SWIFT (1) → +30% move_speed
		#   ARMORED (2) → +50% HP
		#   FURIOUS (3) → daño +25% (aplicado en WeaponComponent vía mult)
		#   GENEROUS (4) → drop_chance ×2
		# El affix vive en GameState.current_wave_affix.
		var speed_mult: float = 1.0
		var drop_mult: float = 1.0
		match GameState.current_wave_affix:
			1: speed_mult = 1.30  # SWIFT
			2: hp_mult *= 1.50    # ARMORED
			4: drop_mult = 2.0    # GENEROUS
		health.max_health = data.max_health * hp_mult
		health.current_health = health.max_health
		if movement:
			movement.walk_speed = data.move_speed * speed_mult
			movement.sprint_speed = data.move_speed * 1.6 * speed_mult
		# Drop multiplier guardado en metadata para _maybe_drop_pickup.
		if drop_mult != 1.0:
			set_meta("drop_chance_mult", drop_mult)
		if animator:
			animator.tint_body(data.body_tint)
		# Boss spawn: emite signal para cinemática (orbit cam + sting + boss bar).
		if data.archetype == EnemyData.Archetype.ALPHA:
			# Defer un frame para que Player ya esté en GameState.local_player.
			call_deferred("_emit_boss_spawned")
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	movement.step.connect(_on_step)
	# Enganchar arma → animator para que el enemigo recargue / golpee con
	# las mismas poses que el jugador (3 fases reload, slash arc).
	if weapon:
		weapon.reload_started.connect(_on_weapon_reload_started)
		weapon.shot_fired.connect(_on_weapon_shot_fired)


func _emit_boss_spawned() -> void:
	if is_instance_valid(self):
		EventBus.boss_spawned.emit(self)


func _physics_process(_delta: float) -> void:
	# Empuja la velocidad local al animator para que las piernas/brazos
	# se animen acorde al movimiento (igual que el player).
	if animator and movement:
		animator.local_velocity = movement.local_velocity
		animator.is_on_floor = is_on_floor()
		animator.is_crouching = movement.is_crouching


func _on_step() -> void:
	if _dying:
		return
	AudioManager.play_3d(&"footstep", global_position, -12.0, 0.12, 40.0)


func _on_weapon_reload_started() -> void:
	if animator and weapon and weapon.current:
		animator.trigger_reload(weapon.current.reload_time)


func _on_weapon_shot_fired(weapon_data: WeaponData, _end: Vector3, _hit: Dictionary) -> void:
	# Slash anim solo en melee (rango corto).
	if animator and weapon_data and weapon_data.max_range < 5.0:
		animator.trigger_attack(0.32)


func _on_damaged(_amount: float, source: Node) -> void:
	if animator:
		animator.flash_hit(0.10)
	# Hit stagger: notifica a la AI con la dirección del golpe (del source
	# hacia nosotros) para que aplique pushback.
	if ai and source is Node3D:
		var src_pos: Vector3 = (source as Node3D).global_position
		var impact_dir: Vector3 = global_position - src_pos
		ai.notify_hit(impact_dir)


func _on_died() -> void:
	if _dying:
		return
	_dying = true
	if ai:
		ai.mark_dead()
	if movement:
		movement.external_wish_dir = Vector3.ZERO
	# Score con kill streak multiplier
	if data:
		GameState.register_kill(data.score_value)
	# Drop posible (recurso aleatorio + arma del enemy)
	_maybe_drop_pickup()
	_maybe_drop_weapon()
	EventBus.entity_died.emit(self)
	# Animación de muerte: caer hacia adelante + queue_free
	set_process(false)
	if visuals:
		var tween := create_tween()
		tween.tween_property(visuals, "rotation:x", deg_to_rad(85), 0.55) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_interval(0.6)
		tween.tween_callback(queue_free)
	else:
		get_tree().create_timer(0.4).timeout.connect(queue_free)


func _maybe_drop_weapon() -> void:
	if weapon_pickup_scene == null or data == null or data.weapon == null:
		return
	if RNG.randf() > weapon_drop_chance:
		return
	# El cuchillo no merece la pena dropearlo (player ya lo tiene como melee).
	if data.weapon.max_range < 5.0:
		return
	var p := weapon_pickup_scene.instantiate() as Node
	if p == null:
		return
	p.set("weapon_data", data.weapon)
	get_tree().current_scene.add_child(p)
	if p is Node3D:
		(p as Node3D).global_position = global_position + Vector3(0.5, 0.6, 0)


func _maybe_drop_pickup() -> void:
	if data == null or data.drop_chance <= 0.0:
		return
	var dc: float = data.drop_chance * float(get_meta("drop_chance_mult", 1.0))
	if RNG.randf() > dc:
		return
	# Tabla de drops ponderada por EnemyData.drop_weight_*. Cada arquetipo
	# define su flavor (Alpha = mucho armor, Swift = mucho speed, etc.).
	var weights: Array[float] = [
		data.drop_weight_health,
		data.drop_weight_ammo,
		data.drop_weight_speed,
		data.drop_weight_armor,
	]
	var scenes: Array[PackedScene] = [
		health_pickup_scene,
		ammo_pickup_scene,
		speed_pickup_scene,
		armor_pickup_scene,
	]
	var total: float = 0.0
	for w in weights:
		total += maxf(w, 0.0)
	if total <= 0.0:
		return
	var roll: float = RNG.randf() * total
	var acc: float = 0.0
	var scene: PackedScene = null
	for i in range(weights.size()):
		acc += maxf(weights[i], 0.0)
		if roll <= acc and scenes[i] != null:
			scene = scenes[i]
			break
	if scene == null:
		# Fallback: el primero válido en orden.
		for s in scenes:
			if s != null:
				scene = s
				break
	if scene == null:
		return
	var pickup := scene.instantiate() as Node3D
	if pickup == null:
		return
	get_tree().current_scene.add_child(pickup)
	pickup.global_position = global_position + Vector3(0, 0.6, 0)
