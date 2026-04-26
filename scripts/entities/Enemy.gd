class_name Enemy
extends CharacterBody3D
## Bot enemigo. Comparte estructura con Player (humanoide + arma) pero
## con AI en vez de input humano.

@export var data: EnemyData

@onready var health: HealthComponent = $HealthComponent
@onready var movement: MovementComponent = $MovementComponent
@onready var weapon: WeaponComponent = $WeaponComponent
@onready var ai: EnemyAI = $EnemyAI
@onready var animator: HumanoidAnimator = $HumanoidAnimator


func _ready() -> void:
	if data:
		health.max_health = data.max_health
		health.current_health = data.max_health
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)


func _process(_delta: float) -> void:
	if animator:
		animator.local_velocity = movement.local_velocity
		animator.is_on_floor = is_on_floor()
		animator.is_crouching = movement.is_crouching


func _on_damaged(_amount: float, _source: Node) -> void:
	if animator:
		animator.flash_hit(0.10)


func _on_died() -> void:
	if ai:
		ai.mark_dead()
	EventBus.entity_died.emit(self)
	# Pequeño delay para que el último flash se vea
	var t := get_tree().create_timer(0.25)
	t.timeout.connect(queue_free)
