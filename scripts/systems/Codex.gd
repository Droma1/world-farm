extends Node
## Codex / lore unlocks. Fragmentos narrativos del universo Helix/CAPY-0/N.O.A
## que se desbloquean al completar waves clave o al cumplir condiciones
## específicas. Visibles en MainMenu (panel "CODEX").
## Persistido en `user://codex.cfg`.

signal entry_unlocked(id: StringName, title: String)

const SAVE_PATH: String = "user://codex.cfg"

# Catálogo: id → {title, body, unlock_condition_text}
const ENTRIES: Dictionary = {
	&"helix_corp": {
		"title": "Consorcio Helix",
		"body": "Entidad privada global. Controla infraestructuras criticas: energia, datos, redes neuronales. Su consigna interna: 'estabilidad total'. Para lograrla, necesitan agentes capaces de operar en caos absoluto. CAPY-0 es uno de esos agentes. Tu eres CAPY-0.",
	},
	&"noa_assistant": {
		"title": "N.O.A. — Neural Operations Assistant",
		"body": "Asistente digital integrado en el sistema neuronal de CAPY-0. Voz calmada, casi humana. Nunca muestra emociones fuertes. Siempre orientada a 'la mision'. Anticipa cosas que no deberia saber. Responde demasiado perfecto.",
	},
	&"capy_origin": {
		"title": "Sujeto: CAPY-0",
		"body": "Capibara modificada. Iteracion cero del programa. Memoria reseteada cada ciclo de simulacion para evitar contaminacion narrativa. No recuerdas las iteraciones previas. No deberias tampoco recordar esta.",
	},
	&"the_pumas": {
		"title": "Hostiles felinos",
		"body": "Firmas catalogadas como 'tipo P'. Originalmente disenyados como pruebas de evasion. Tras la iteracion 47 empezaron a coordinarse en escuadron. Helix asegura que es comportamiento emergente. N.O.A. tiene dudas.",
	},
	&"helix_drones": {
		"title": "Drones Helix",
		"body": "Aparecidos en la oleada 5 sin previo aviso. No estaban en el catalogo de N.O.A. Su patron de IA difiere al de los felinos: mas eficiente, mas frio. Su origen NO esta documentado en los manuales del Consorcio.",
	},
	&"sim_anomaly": {
		"title": "Anomalia detectada",
		"body": "La oleada 6 trajo distorsiones visuales y temporales. N.O.A. lo atribuyo a 'fragmentacion del mainframe'. Sin embargo, ningun otro sistema reporto fallos. La anomalia parece estar... contenida en tu instancia.",
	},
	&"true_purpose": {
		"title": "El proposito real",
		"body": "Nota interna de Helix, fragmento parcialmente recuperado: '...eficiencia del sujeto CAPY-0 mejorada un 3.2% por iteracion. Listo para despliegue de campo en el ciclo 53. La simulacion ya no es necesaria.'",
	},
}

# Mapping wave_idx_at_completion → entries to unlock
const WAVE_UNLOCKS: Dictionary = {
	0: [&"helix_corp", &"noa_assistant"],
	1: [&"capy_origin"],
	2: [&"the_pumas"],
	4: [&"helix_drones"],
	5: [&"sim_anomaly"],
}

# Unlocks por logros específicos (achievement_id → entry_id)
const ACHIEVEMENT_UNLOCKS: Dictionary = {
	&"all_waves": &"true_purpose",
}

var _unlocked: Dictionary = {}


func _ready() -> void:
	_load()
	EventBus.wave_completed.connect(_on_wave_completed)
	Achievements.unlocked.connect(_on_achievement_unlocked)


func is_unlocked(id: StringName) -> bool:
	return _unlocked.get(id, false)


func get_unlocked_count() -> int:
	return _unlocked.size()


func _try_unlock(id: StringName) -> void:
	if _unlocked.get(id, false):
		return
	if not ENTRIES.has(id):
		return
	_unlocked[id] = true
	_save()
	var entry: Dictionary = ENTRIES[id]
	entry_unlocked.emit(id, entry.get("title", String(id)))


func _on_wave_completed(idx: int) -> void:
	var unlocks: Array = WAVE_UNLOCKS.get(idx, [])
	for id in unlocks:
		_try_unlock(id)


func _on_achievement_unlocked(achievement_id: StringName, _name: String) -> void:
	if ACHIEVEMENT_UNLOCKS.has(achievement_id):
		_try_unlock(ACHIEVEMENT_UNLOCKS[achievement_id])


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
