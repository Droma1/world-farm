class_name SpeedPickup
extends Pickup
## Pickup de boost de velocidad temporal. Multiplica walk_speed/sprint_speed
## del player durante `duration` segundos. Se acumula resetando el timer.

@export var duration: float = 6.0
@export var speed_multiplier: float = 1.7


func _apply_to_player(player: Player) -> void:
	if player.movement == null:
		return
	# Guardar valores base si aún no lo hicimos (en metadata del player).
	if not player.has_meta("_speed_boost_base"):
		player.set_meta("_speed_boost_base", {
			"walk": player.movement.walk_speed,
			"sprint": player.movement.sprint_speed,
		})
		player.movement.walk_speed *= speed_multiplier
		player.movement.sprint_speed *= speed_multiplier
	# Cancelar timer previo si lo había.
	if player.has_meta("_speed_boost_timer"):
		var prev := player.get_meta("_speed_boost_timer") as SceneTreeTimer
		if prev:
			prev.timeout.disconnect(_on_boost_end.bind(player))
	var timer := player.get_tree().create_timer(duration)
	player.set_meta("_speed_boost_timer", timer)
	timer.timeout.connect(_on_boost_end.bind(player))
	EventBus.pickup_collected.emit(&"speed", duration)


func _on_boost_end(player: Player) -> void:
	if not is_instance_valid(player) or not player.has_meta("_speed_boost_base"):
		return
	var base: Dictionary = player.get_meta("_speed_boost_base")
	if player.movement:
		player.movement.walk_speed = base.get("walk", 5.0)
		player.movement.sprint_speed = base.get("sprint", 8.0)
	player.remove_meta("_speed_boost_base")
	player.remove_meta("_speed_boost_timer")
