class_name AmmoPickup
extends Pickup

@export var reserve_amount: int = 30


func _apply_to_player(player: Player) -> void:
	if player.weapon:
		player.weapon.reserve += reserve_amount
		player.weapon.ammo_changed.emit(player.weapon.in_mag, player.weapon.reserve)
