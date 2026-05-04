extends Node
## Sistema de logros. Detecta condiciones via EventBus + GameState, marca el
## logro como obtenido y emite signal para que HUD muestre toast.
## Persistido en user://achievements.cfg (independiente de Settings para
## no contaminar y para poder borrar progreso de logros sin perder settings).

signal unlocked(achievement_id: StringName, name: String)

const SAVE_PATH: String = "user://achievements.cfg"

# id → {name, desc, hidden}
const CATALOG: Dictionary = {
	&"first_blood": {
		"name": "Primera baja",
		"desc": "Elimina a tu primer hostil.",
	},
	&"streak_5": {
		"name": "Combo dorado",
		"desc": "Encadena 5 kills sin perder el streak.",
	},
	&"streak_10": {
		"name": "Maestro del ritmo",
		"desc": "Encadena 10 kills sin perder el streak.",
	},
	&"headshot_first": {
		"name": "Mirada precisa",
		"desc": "Tu primer headshot.",
	},
	&"headshots_10": {
		"name": "Cazador de cabezas",
		"desc": "10 headshots en una partida.",
	},
	&"survive_3_waves": {
		"name": "Resistente",
		"desc": "Supera 3 oleadas en una sola simulacion.",
	},
	&"all_waves": {
		"name": "Simulacion completa",
		"desc": "Completa todas las oleadas.",
	},
	&"hack_first": {
		"name": "Acceso concedido",
		"desc": "Completa el primer hackeo de N.O.A.",
	},
	&"alpha_killer": {
		"name": "Cazador de Alpha",
		"desc": "Mata a un Puma Alpha.",
	},
	&"grenade_kill": {
		"name": "Boom",
		"desc": "Mata a un enemigo con una granada.",
	},
	&"flawless_wave": {
		"name": "Sin un rasgunyo",
		"desc": "Completa una oleada sin recibir daño.",
	},
}

var _unlocked: Dictionary = {}
var _waves_survived_this_run: int = 0
var _damage_taken_this_wave: float = 0.0
var _last_damage_source: Node = null


func _ready() -> void:
	_load()
	EventBus.entity_died.connect(_on_entity_died)
	EventBus.headshot.connect(_on_headshot)
	EventBus.kill_streak_changed.connect(_on_streak_changed)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_completed.connect(_on_wave_completed)
	EventBus.all_waves_completed.connect(func(): _try_unlock(&"all_waves"))
	EventBus.entity_damaged.connect(_on_entity_damaged_track)
	EventBus.damage_dealt.connect(_on_damage_dealt_track)
	HackingSystem.hack_completed.connect(func(): _try_unlock(&"hack_first"))


func is_unlocked(id: StringName) -> bool:
	return _unlocked.get(id, false)


func get_unlocked_count() -> int:
	return _unlocked.size()


func _try_unlock(id: StringName) -> void:
	if _unlocked.get(id, false):
		return
	if not CATALOG.has(id):
		return
	_unlocked[id] = true
	_save()
	var entry: Dictionary = CATALOG[id]
	unlocked.emit(id, entry.get("name", String(id)))


func _on_entity_died(entity: Node) -> void:
	if entity == GameState.local_player:
		return
	if GameState.kills_this_run >= 1:
		_try_unlock(&"first_blood")
	# Detectar Alpha kill
	if entity is CharacterBody3D and "data" in entity and entity.data:
		if entity.data.archetype == EnemyData.Archetype.ALPHA:
			_try_unlock(&"alpha_killer")
	# Granada kill: si el último damage_source que apuntó a este entity era
	# el player (lo trackeamos aproximado en _last_damage_source — granadas
	# emiten damage_dealt con source=thrower).
	# Ver _on_damage_dealt_track más abajo (no necesario aquí).


func _on_headshot(_target: Object, source: Node) -> void:
	if source != GameState.local_player:
		return
	_try_unlock(&"headshot_first")
	if GameState.headshots_this_run >= 10:
		_try_unlock(&"headshots_10")


func _on_streak_changed(streak: int, _mult: float) -> void:
	if streak >= 5:
		_try_unlock(&"streak_5")
	if streak >= 10:
		_try_unlock(&"streak_10")


func _on_wave_started(_index: int, _total: int, _data: Resource) -> void:
	_damage_taken_this_wave = 0.0


func _on_wave_completed(_index: int) -> void:
	_waves_survived_this_run += 1
	if _waves_survived_this_run >= 3:
		_try_unlock(&"survive_3_waves")
	if _damage_taken_this_wave <= 0.0:
		_try_unlock(&"flawless_wave")


func _on_entity_damaged_track(entity: Node, amount: float) -> void:
	if entity == GameState.local_player:
		_damage_taken_this_wave += amount


func _on_damage_dealt_track(target: Object, _amount: float, source: Node) -> void:
	# Granada: cuando el target está vivo y este damage_dealt vino de la
	# granada (player es source y el target murió en el siguiente frame),
	# detectamos vía signal de death + comparación. Heurística simple: si
	# el daño es ≥ 50 (granada base) y mata al target, asumimos granada.
	if source != GameState.local_player or target == null:
		return
	if not (target is Node):
		return
	for child in (target as Node).get_children():
		if child is HealthComponent:
			var hp := child as HealthComponent
			if hp.current_health <= 0.0 and _amount >= 40.0:
				_try_unlock(&"grenade_kill")
			break


func _save() -> void:
	var cfg := ConfigFile.new()
	for k in _unlocked.keys():
		cfg.set_value("unlocked", String(k), _unlocked[k])
	cfg.save(SAVE_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	if cfg.has_section("unlocked"):
		for k in cfg.get_section_keys("unlocked"):
			_unlocked[StringName(k)] = cfg.get_value("unlocked", k, false)
