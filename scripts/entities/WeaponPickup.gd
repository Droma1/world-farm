class_name WeaponPickup
extends Pickup
## Pickup de arma soltada por un enemy muerto. Cuando el player camina sobre
## ella, recarga su munición de reserva con el `mag_size` del arma. Si el
## player NO tenía esa arma todavía, la añade a su inventario.

@export var weapon_data: WeaponData
@export var ammo_amount_multiplier: int = 2  # mag_size × N = ammo añadida


func _apply_to_player(player: Player) -> void:
	if weapon_data == null:
		return
	# ¿El player ya tiene esta arma? Comparamos por id.
	var has_it: bool = false
	for w in player._weapons:
		if w and w.id == weapon_data.id:
			has_it = true
			break
	if has_it:
		# Recargamos reserva del arma equipada (si es la misma) o sumamos
		# a la reserva guardada en _weapon_states (si es otra).
		var added: int = weapon_data.mag_size * ammo_amount_multiplier
		if player.weapon and player.weapon.current and player.weapon.current.id == weapon_data.id:
			player.weapon.reserve += added
			player.weapon.ammo_changed.emit(player.weapon.in_mag, player.weapon.reserve)
		else:
			# Sumar al estado guardado
			for i in range(player._weapons.size()):
				if player._weapons[i] and player._weapons[i].id == weapon_data.id:
					if i < player._weapon_states.size():
						var st: Dictionary = player._weapon_states[i]
						st["reserve"] = st.get("reserve", 0) + added
						player._weapon_states[i] = st
					break
		EventBus.pickup_collected.emit(&"ammo", float(added))
	else:
		# Arma nueva: la añadimos al final del inventario.
		player._weapons.append(weapon_data)
		player._weapon_states.append({
			"in_mag": weapon_data.mag_size,
			"reserve": weapon_data.reserve_ammo,
		})
		EventBus.pickup_collected.emit(&"weapon_new", 1.0)
