extends Node
## Hub global de signals. Sistemas publican/escuchan aquí sin
## importarse entre sí. Mantener este archivo SOLO con declaraciones
## de signal y, si acaso, helpers triviales.

# --- Combat ---
signal weapon_fired(weapon: Node, origin: Vector3, direction: Vector3)
signal damage_dealt(target: Object, amount: float, source: Node)
signal impact(position: Vector3, normal: Vector3, collider: Object)
signal weapon_swapped(weapon_data: Resource, slot_index: int)
signal headshot(target: Object, source: Node)  ## Hit en la cabeza (×headshot_multiplier)
signal grenade_thrown(grenades_left: int)  ## Player lanzó granada (HUD actualiza contador)
signal pellet_fired(data: Resource, origin: Vector3, end_point: Vector3, hit_data: Dictionary)  ## Cada pellet de shotgun
signal smoke_deployed(position: Vector3, radius: float, duration: float)  ## Smoke grenade activa
signal flashbang_exploded(position: Vector3, radius: float, stun_duration: float)  ## Flash grenade activa

# --- Health / lifecycle ---
signal entity_damaged(entity: Node, amount: float)
signal entity_died(entity: Node)
signal player_died(player: Node)

# --- Waves ---
signal wave_started(index: int, total: int, data: Resource)
signal wave_completed(index: int)
signal wave_alive_count_changed(count: int)
signal wave_affix_changed(affix: int, name: String)  ## Random modifier por wave 3+
signal all_waves_completed

# --- Inventory / pickups ---
signal item_picked_up(item: Resource, picker: Node)
signal pickup_collected(kind: StringName, amount: float)

# --- Score / kill streak ---
signal kill_streak_changed(streak: int, multiplier: float)
signal multikill(count: int)  ## 2/3/4+ kills en ventana corta (DOBLE/TRIPLE/MITICO)
signal kill_streak_reward(streak: int)  ## Emitido en hitos (5, 10) para activar buffs
signal alpha_called_reinforcements(alpha_enemy: Node)  ## ALPHA llama refuerzos al -50% HP
signal boss_spawned(boss: Node)  ## ALPHA u otro boss spawnea (trigger cinemática)
