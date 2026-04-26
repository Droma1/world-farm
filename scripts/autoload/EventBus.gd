extends Node
## Hub global de signals. Sistemas publican/escuchan aquí sin
## importarse entre sí. Mantener este archivo SOLO con declaraciones
## de signal y, si acaso, helpers triviales.

# --- Combat ---
signal weapon_fired(weapon: Node, origin: Vector3, direction: Vector3)
signal damage_dealt(target: Object, amount: float, source: Node)
signal impact(position: Vector3, normal: Vector3, collider: Object)
signal weapon_swapped(weapon_data: Resource, slot_index: int)

# --- Health / lifecycle ---
signal entity_damaged(entity: Node, amount: float)
signal entity_died(entity: Node)
signal player_died(player: Node)

# --- Waves ---
signal wave_started(index: int, total: int, data: Resource)
signal wave_completed(index: int)
signal wave_alive_count_changed(count: int)
signal all_waves_completed

# --- Inventory / pickups ---
signal item_picked_up(item: Resource, picker: Node)
signal pickup_collected(kind: StringName, amount: float)

# --- Score / kill streak ---
signal kill_streak_changed(streak: int, multiplier: float)
