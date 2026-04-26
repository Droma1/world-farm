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
		_apply_master_volume()
		changed.emit(&"master_volume", master_volume)
		_save()

var sfx_volume: float = 1.0:
	set(value):
		sfx_volume = clampf(value, 0.0, 1.0)
		_apply_master_volume()
		changed.emit(&"sfx_volume", sfx_volume)
		_save()


func _ready() -> void:
	_load()
	_apply_master_volume()


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


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.save(SAVE_PATH)


# ============================================================
#  Aplicación a buses de audio
# ============================================================

func _apply_master_volume() -> void:
	var master_idx := AudioServer.get_bus_index(&"Master")
	if master_idx >= 0:
		var combined: float = master_volume * sfx_volume
		AudioServer.set_bus_volume_db(master_idx, linear_to_db(maxf(combined, 0.0001)))
