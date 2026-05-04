extends Node
## Configuración persistente del usuario. Se guarda en user://settings.cfg
## (formato Godot ConfigFile). Cualquier sistema que dependa de un setting
## se suscribe a `changed` o lee la propiedad directamente.

signal changed(key: StringName, value: Variant)

const SAVE_PATH: String = "user://settings.cfg"

# --- Defaults ---
var mouse_sensitivity: float = 0.003:
	set(value):
		mouse_sensitivity = value
		changed.emit(&"mouse_sensitivity", value)
		_save()

var master_volume: float = 0.8:
	set(value):
		master_volume = clampf(value, 0.0, 1.0)
		_apply_volumes()
		changed.emit(&"master_volume", master_volume)
		_save()

var sfx_volume: float = 1.0:
	set(value):
		sfx_volume = clampf(value, 0.0, 1.0)
		_apply_volumes()
		changed.emit(&"sfx_volume", sfx_volume)
		_save()

var music_volume: float = 0.7:
	set(value):
		music_volume = clampf(value, 0.0, 1.0)
		_apply_volumes()
		changed.emit(&"music_volume", music_volume)
		_save()

# High score persistido. Al terminar la partida, GameState llama a
# Settings.maybe_record_score(score) y se actualiza si supera el anterior.
var high_score: int = 0
var highest_streak: int = 0
var waves_completed: int = 0   ## Total acumulado entre todas las partidas
var tutorial_done: bool = false  ## True tras la primera partida — skip intro N.O.A.

# Dificultad: 0=Easy, 1=Normal, 2=Hard. Aplicada en Enemy._ready vía
# Settings.enemy_health_multiplier() / damage_multiplier() / etc.
enum Difficulty { EASY, NORMAL, HARD }
var difficulty: int = Difficulty.NORMAL:
	set(value):
		difficulty = clampi(value, 0, 2)
		changed.emit(&"difficulty", difficulty)
		_save()

# Loadout: array de strings con los `id` de WeaponData seleccionados (max 4).
# Si está vacío → Player usa data.starting_weapons como fallback.
var loadout_weapon_ids: PackedStringArray = PackedStringArray()
var loadout_grenade_count: int = 2

# Iron Mode: modifier extremo. Sin granadas, sin health regen, sin slow-mo
# en boss/death. A cambio, score ×1.6 y achievements bonus (futuros).
var iron_mode: bool = false:
	set(value):
		iron_mode = value
		changed.emit(&"iron_mode", value)
		_save()


func iron_mode_score_multiplier() -> float:
	return 1.6 if iron_mode else 1.0

# Lifetime stats — acumulados entre todas las partidas. Se guardan al
# terminar cada run (game_over o victory) en GameState.mode setter.
var lifetime_kills: int = 0
var lifetime_headshots: int = 0
var lifetime_playtime_s: float = 0.0
var lifetime_runs: int = 0


func add_lifetime_stats(kills: int, headshots: int, playtime_s: float) -> void:
	lifetime_kills += kills
	lifetime_headshots += headshots
	lifetime_playtime_s += playtime_s
	lifetime_runs += 1
	_save()


## Rank derivado de lifetime_kills + waves_completed. Usado por MainMenu y HUD
## end-screen para dar sensación de progresión. Umbrales tunables.
const RANK_THRESHOLDS: Array[Dictionary] = [
	{"name": "RECLUTA", "kills": 0, "waves": 0, "color": Color(0.7, 0.7, 0.75)},
	{"name": "OPERADOR", "kills": 25, "waves": 5, "color": Color(0.85, 0.95, 1.0)},
	{"name": "VETERANO", "kills": 100, "waves": 18, "color": Color(0.55, 0.95, 0.7)},
	{"name": "SOMBRA", "kills": 250, "waves": 40, "color": Color(1.0, 0.85, 0.4)},
	{"name": "HELIX-1", "kills": 600, "waves": 80, "color": Color(1.0, 0.5, 0.5)},
]


func current_rank() -> Dictionary:
	# El rank se otorga si SE CUMPLEN ambas condiciones (kills Y waves).
	var current: Dictionary = RANK_THRESHOLDS[0]
	for r in RANK_THRESHOLDS:
		if lifetime_kills >= r["kills"] and waves_completed >= r["waves"]:
			current = r
	return current


## Devuelve el índice del rank actual (0..4).
func current_rank_index() -> int:
	var idx: int = 0
	for i in range(RANK_THRESHOLDS.size()):
		var r: Dictionary = RANK_THRESHOLDS[i]
		if lifetime_kills >= r["kills"] and waves_completed >= r["waves"]:
			idx = i
	return idx


## Mapping arma_id → rank mínimo requerido para usarla en el loadout.
const WEAPON_RANK_REQUIREMENT: Dictionary = {
	"rifle_basic": 0,
	"pistol_basic": 0,
	"knife_basic": 0,
	"shotgun_basic": 1,    # OPERADOR
	"rifle_sniper": 2,     # VETERANO
}


func is_weapon_unlocked(weapon_id: String) -> bool:
	var req: int = WEAPON_RANK_REQUIREMENT.get(weapon_id, 999)
	return current_rank_index() >= req


func format_playtime() -> String:
	var t: int = int(lifetime_playtime_s)
	var h: int = t / 3600
	var m: int = (t / 60) % 60
	var s: int = t % 60
	if h > 0:
		return "%dh %02dm" % [h, m]
	return "%dm %02ds" % [m, s]


func set_loadout(weapon_ids: PackedStringArray, grenade_count: int) -> void:
	loadout_weapon_ids = weapon_ids
	loadout_grenade_count = clampi(grenade_count, 0, 5)
	_save()
	changed.emit(&"loadout", null)


func enemy_health_multiplier() -> float:
	match difficulty:
		Difficulty.EASY: return 0.7
		Difficulty.HARD: return 1.6
		_: return 1.0


func enemy_damage_multiplier() -> float:
	match difficulty:
		Difficulty.EASY: return 0.65
		Difficulty.HARD: return 1.5
		_: return 1.0


func difficulty_name() -> String:
	match difficulty:
		Difficulty.EASY: return "FACIL"
		Difficulty.HARD: return "DIFICIL"
		_: return "NORMAL"


func maybe_record_score(score: int) -> bool:
	## Devuelve true si fue un nuevo record.
	var is_record := score > high_score
	if is_record:
		high_score = score
		_save()
	return is_record


func maybe_record_streak(streak: int) -> void:
	if streak > highest_streak:
		highest_streak = streak
		_save()


func add_completed_wave() -> void:
	waves_completed += 1
	_save()


func _ready() -> void:
	_load()
	_apply_volumes()


# ============================================================
#  Persistencia
# ============================================================

func _load() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK:
		return  # primera vez — usar defaults
	mouse_sensitivity = cfg.get_value("input", "mouse_sensitivity", mouse_sensitivity)
	master_volume = cfg.get_value("audio", "master_volume", master_volume)
	sfx_volume = cfg.get_value("audio", "sfx_volume", sfx_volume)
	music_volume = cfg.get_value("audio", "music_volume", music_volume)
	high_score = cfg.get_value("progress", "high_score", 0)
	highest_streak = cfg.get_value("progress", "highest_streak", 0)
	waves_completed = cfg.get_value("progress", "waves_completed", 0)
	tutorial_done = cfg.get_value("progress", "tutorial_done", false)
	difficulty = cfg.get_value("progress", "difficulty", Difficulty.NORMAL)
	loadout_weapon_ids = PackedStringArray(cfg.get_value("loadout", "weapon_ids", []))
	loadout_grenade_count = cfg.get_value("loadout", "grenade_count", 2)
	iron_mode = cfg.get_value("modifiers", "iron_mode", false)
	lifetime_kills = cfg.get_value("lifetime", "kills", 0)
	lifetime_headshots = cfg.get_value("lifetime", "headshots", 0)
	lifetime_playtime_s = cfg.get_value("lifetime", "playtime_s", 0.0)
	lifetime_runs = cfg.get_value("lifetime", "runs", 0)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("progress", "high_score", high_score)
	cfg.set_value("progress", "highest_streak", highest_streak)
	cfg.set_value("progress", "waves_completed", waves_completed)
	cfg.set_value("progress", "tutorial_done", tutorial_done)
	cfg.set_value("progress", "difficulty", difficulty)
	cfg.set_value("loadout", "weapon_ids", Array(loadout_weapon_ids))
	cfg.set_value("loadout", "grenade_count", loadout_grenade_count)
	cfg.set_value("modifiers", "iron_mode", iron_mode)
	cfg.set_value("lifetime", "kills", lifetime_kills)
	cfg.set_value("lifetime", "headshots", lifetime_headshots)
	cfg.set_value("lifetime", "playtime_s", lifetime_playtime_s)
	cfg.set_value("lifetime", "runs", lifetime_runs)
	cfg.save(SAVE_PATH)


func mark_tutorial_done() -> void:
	if not tutorial_done:
		tutorial_done = true
		_save()


# ============================================================
#  Aplicación a buses de audio
# ============================================================

func _apply_volumes() -> void:
	# Master controla volumen general. Music y SFX son buses hijos con su
	# propio volumen. Se aplican vía AudioServer.set_bus_volume_db.
	_set_bus_db(&"Master", master_volume)
	_set_bus_db(&"Music", music_volume)
	_set_bus_db(&"SFX", sfx_volume)


func _set_bus_db(bus: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
