extends Node
## Hub global de signals. Sistemas publican/escuchan aquí sin
## importarse entre sí. Mantener este archivo SOLO con declaraciones
## de signal y, si acaso, helpers triviales.

# --- Combat ---
signal weapon_fired(weapon: Node, origin: Vector3, direction: Vector3)
signal damage_dealt(target: Object, amount: float, source: Node)

# --- Health / lifecycle ---
signal entity_damaged(entity: Node, amount: float)
signal entity_died(entity: Node)
signal player_died(player: Node)

# --- Inventory / pickups (uso futuro) ---
signal item_picked_up(item: Resource, picker: Node)
