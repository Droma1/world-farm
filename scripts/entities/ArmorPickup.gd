class_name ArmorPickup
extends Pickup
## Pickup que aumenta `max_health` del player y lo cura al máximo nuevo.
## Permanente para esta partida (no expira). Tope para no romper balance.

@export var bonus_max_health: float = 25.0
@export var max_health_cap: float = 200.0


func _apply_to_player(player: Player) -> void:
	if player.health == null:
		return
	var new_max: float = minf(player.health.max_health + bonus_max_health, max_health_cap)
	var added: float = new_max - player.health.max_health
	player.health.max_health = new_max
	player.health.current_health = minf(player.health.current_health + added, new_max)
	EventBus.pickup_collected.emit(&"armor", added)
