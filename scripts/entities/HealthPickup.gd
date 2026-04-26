class_name HealthPickup
extends Pickup

@export var heal_amount: float = 30.0


func _apply_to_player(player: Player) -> void:
	if player.health:
		player.health.heal(heal_amount)
	EventBus.pickup_collected.emit(&"health", heal_amount)
