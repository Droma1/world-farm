class_name HealthComponent
extends Node
## Component genérico de vida. Se attachea a Player, Enemy, dummies,
## destructibles… cualquier cosa que pueda recibir daño.

signal damaged(amount: float, source: Node)
signal healed(amount: float)
signal died

@export var max_health: float = 100.0

var current_health: float


func _ready() -> void:
	current_health = max_health


func take_damage(amount: float, source: Node = null) -> void:
	if current_health <= 0.0 or amount <= 0.0:
		return
	current_health = max(0.0, current_health - amount)
	damaged.emit(amount, source)
	EventBus.entity_damaged.emit(get_parent(), amount)
	if current_health == 0.0:
		died.emit()
		EventBus.entity_died.emit(get_parent())


func heal(amount: float) -> void:
	if current_health <= 0.0 or amount <= 0.0:
		return
	current_health = min(max_health, current_health + amount)
	healed.emit(amount)


func is_alive() -> bool:
	return current_health > 0.0
