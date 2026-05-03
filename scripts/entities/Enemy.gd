class_name Enemy
extends CharacterBody3D
## Bot enemigo. Comparte estructura con Player (humanoide + arma) pero
## con AI en vez de input humano. Aplica tint al ready, suma score al
## morir y tiene oportunidad de droppear un pickup.

@export var data: EnemyData
@export var health_pickup_scene: PackedScene
@export var ammo_pickup_scene: PackedScene

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
		health.max_health = data.max_health
		health.current_health = data.max_health
		if animator:
			animator.tint_body(data.body_tint)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	movement.step.connect(_on_step)
	# Enganchar arma → animator para que el enemigo recargue / golpee con
	# las mismas poses que el jugador (3 fases reload, slash arc).
	if weapon:
		weapon.reload_started.connect(_on_weapon_reload_started)
		weapon.shot_fired.connect(_on_weapon_shot_fired)


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


func _on_damaged(_amount: float, _source: Node) -> void:
	if animator:
		animator.flash_hit(0.10)


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
	# Drop posible
	_maybe_drop_pickup()
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


func _maybe_drop_pickup() -> void:
	if data == null or data.drop_chance <= 0.0:
		return
	if RNG.randf() > data.drop_chance:
		return
	# 50/50 entre health y ammo
	var scene: PackedScene = health_pickup_scene if RNG.randf() < 0.5 else ammo_pickup_scene
	if scene == null:
		return
	var pickup := scene.instantiate() as Node3D
	if pickup == null:
		return
	get_tree().current_scene.add_child(pickup)
	pickup.global_position = global_position + Vector3(0, 0.6, 0)
