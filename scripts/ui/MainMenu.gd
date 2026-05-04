extends Control
## Pantalla principal. Carga el escenario compacto al pulsar Jugar. Opciones reusan
## Settings autoload (mismo flow que el pause menu).

@export var play_scene: PackedScene

@onready var play_btn: Button = $Container/Buttons/PlayButton
@onready var play_hangar_btn: Button = $Container/Buttons/PlayHangarButton
@onready var options_btn: Button = $Container/Buttons/OptionsButton
@onready var quit_btn: Button = $Container/Buttons/QuitButton
@onready var status_label: Label = $Container/Status
@onready var options_panel: Control = $OptionsPanel
@onready var sens_slider: HSlider = $OptionsPanel/Container/SensRow/SensSlider
@onready var vol_slider: HSlider = $OptionsPanel/Container/VolRow/VolSlider
@onready var back_btn: Button = $OptionsPanel/Container/BackButton
@onready var diff_easy: Button = $OptionsPanel/Container/DiffRow/DiffEasy
@onready var diff_normal: Button = $OptionsPanel/Container/DiffRow/DiffNormal
@onready var diff_hard: Button = $OptionsPanel/Container/DiffRow/DiffHard
@onready var iron_check: CheckBox = $OptionsPanel/Container/IronModeRow/IronCheck
@onready var achievements_btn: Button = $Container/Buttons/AchievementsButton
@onready var achievements_panel: Control = $AchievementsPanel
@onready var achievements_back_btn: Button = $AchievementsPanel/Container/BackButton2
@onready var achievements_list: VBoxContainer = $AchievementsPanel/Container/ScrollContainer/List
@onready var achievements_progress: Label = $AchievementsPanel/Container/ProgressLabel
@onready var loadout_btn: Button = $Container/Buttons/LoadoutButton
@onready var loadout_panel: Control = $LoadoutPanel
@onready var lo_rifle: CheckBox = $LoadoutPanel/Container/WeaponsList/LRifle
@onready var lo_pistol: CheckBox = $LoadoutPanel/Container/WeaponsList/LPistol
@onready var lo_shotgun: CheckBox = $LoadoutPanel/Container/WeaponsList/LShotgun
@onready var lo_knife: CheckBox = $LoadoutPanel/Container/WeaponsList/LKnife
@onready var lo_sniper: CheckBox = $LoadoutPanel/Container/WeaponsList/LSniper
@onready var lo_grenades: SpinBox = $LoadoutPanel/Container/GrenadeRow/GSpinBox
@onready var lo_save_btn: Button = $LoadoutPanel/Container/LSaveButton
@onready var codex_btn: Button = $Container/Buttons/CodexButton
@onready var codex_panel: Control = $CodexPanel
@onready var codex_back_btn: Button = $CodexPanel/Container/CBackButton
@onready var codex_list: VBoxContainer = $CodexPanel/Container/Split/LeftScroll/EntryList
@onready var codex_progress: Label = $CodexPanel/Container/CProgressLabel
@onready var codex_entry_title: Label = $CodexPanel/Container/Split/RightPanel/RightVBox/EntryTitle
@onready var codex_entry_body: Label = $CodexPanel/Container/Split/RightPanel/RightVBox/EntryBody


func _ready() -> void:
	# Por si veníamos pausados de un retry: limpiar
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameState.reset()
	# Música de menú (loop ambient sci-fi)
	AudioManager.play_music(&"menu_ambient")

	options_panel.visible = false
	achievements_panel.visible = false
	loadout_panel.visible = false

	play_btn.pressed.connect(_on_play)
	play_hangar_btn.pressed.connect(_on_play_hangar)
	options_btn.pressed.connect(_show_options)
	quit_btn.pressed.connect(_on_quit)
	back_btn.pressed.connect(_hide_options)
	achievements_btn.pressed.connect(_show_achievements)
	achievements_back_btn.pressed.connect(_hide_achievements)
	loadout_btn.pressed.connect(_show_loadout)
	lo_save_btn.pressed.connect(_save_loadout)
	codex_btn.pressed.connect(_show_codex)
	codex_back_btn.pressed.connect(_hide_codex)
	codex_panel.visible = false

	sens_slider.value = Settings.mouse_sensitivity
	vol_slider.value = Settings.master_volume
	sens_slider.value_changed.connect(func(v): Settings.mouse_sensitivity = v)
	vol_slider.value_changed.connect(func(v): Settings.master_volume = v)

	diff_easy.pressed.connect(func(): _set_difficulty(Settings.Difficulty.EASY))
	diff_normal.pressed.connect(func(): _set_difficulty(Settings.Difficulty.NORMAL))
	diff_hard.pressed.connect(func(): _set_difficulty(Settings.Difficulty.HARD))
	_refresh_difficulty_buttons()

	iron_check.button_pressed = Settings.iron_mode
	iron_check.toggled.connect(func(p: bool): Settings.iron_mode = p)

	# Mostrar progreso persistido en el label de estado.
	if Settings.high_score > 0 or Settings.waves_completed > 0:
		var rank: Dictionary = Settings.current_rank()
		var line0 := "RANGO  %s" % rank["name"]
		var line1 := "MEJOR %d   ·   STREAK MAX %d   ·   WAVES %d" % [
			Settings.high_score, Settings.highest_streak, Settings.waves_completed
		]
		var line2 := "TOTAL: %d kills   ·   %d headshots   ·   %d runs   ·   %s jugadas" % [
			Settings.lifetime_kills, Settings.lifetime_headshots,
			Settings.lifetime_runs, Settings.format_playtime()
		]
		status_label.text = line0 + "\n" + line1 + "\n" + line2
		status_label.modulate = rank["color"]
	else:
		status_label.text = "SISTEMA LISTO  -  PRIMERA SIMULACION"


func _on_play() -> void:
	if play_scene:
		get_tree().change_scene_to_packed(play_scene)


func _on_play_hangar() -> void:
	get_tree().change_scene_to_file("res://scenes/levels/Hangar.tscn")


func _show_options() -> void:
	options_panel.visible = true


func _hide_options() -> void:
	options_panel.visible = false


func _show_achievements() -> void:
	achievements_panel.visible = true
	_populate_achievements_list()


func _hide_achievements() -> void:
	achievements_panel.visible = false


func _show_loadout() -> void:
	loadout_panel.visible = true
	# Bloqueamos checkboxes de armas no desbloqueadas por rank.
	_apply_weapon_lock(lo_rifle, "rifle_basic")
	_apply_weapon_lock(lo_pistol, "pistol_basic")
	_apply_weapon_lock(lo_shotgun, "shotgun_basic")
	_apply_weapon_lock(lo_knife, "knife_basic")
	_apply_weapon_lock(lo_sniper, "rifle_sniper")
	# Sync UI con Settings actual.
	var ids := Settings.loadout_weapon_ids
	if ids.is_empty():
		lo_rifle.button_pressed = Settings.is_weapon_unlocked("rifle_basic")
		lo_pistol.button_pressed = Settings.is_weapon_unlocked("pistol_basic")
		lo_shotgun.button_pressed = Settings.is_weapon_unlocked("shotgun_basic")
		lo_knife.button_pressed = Settings.is_weapon_unlocked("knife_basic")
		lo_sniper.button_pressed = false
	else:
		lo_rifle.button_pressed = ids.has("rifle_basic") and Settings.is_weapon_unlocked("rifle_basic")
		lo_pistol.button_pressed = ids.has("pistol_basic") and Settings.is_weapon_unlocked("pistol_basic")
		lo_shotgun.button_pressed = ids.has("shotgun_basic") and Settings.is_weapon_unlocked("shotgun_basic")
		lo_knife.button_pressed = ids.has("knife_basic") and Settings.is_weapon_unlocked("knife_basic")
		lo_sniper.button_pressed = ids.has("rifle_sniper") and Settings.is_weapon_unlocked("rifle_sniper")
	lo_grenades.value = Settings.loadout_grenade_count


func _apply_weapon_lock(checkbox: CheckBox, weapon_id: String) -> void:
	if Settings.is_weapon_unlocked(weapon_id):
		checkbox.disabled = false
		checkbox.modulate = Color(1, 1, 1, 1)
	else:
		var req_rank: int = Settings.WEAPON_RANK_REQUIREMENT.get(weapon_id, 0)
		var req_name: String = Settings.RANK_THRESHOLDS[req_rank]["name"]
		checkbox.disabled = true
		checkbox.button_pressed = false
		checkbox.modulate = Color(0.5, 0.5, 0.55, 1)
		# Suffix con el rank requerido
		var base: String = checkbox.text.split("  [")[0]
		checkbox.text = "%s  [bloqueado · %s]" % [base, req_name]


func _show_codex() -> void:
	codex_panel.visible = true
	_populate_codex_list()


func _hide_codex() -> void:
	codex_panel.visible = false


func _populate_codex_list() -> void:
	for child in codex_list.get_children():
		child.queue_free()
	var total: int = Codex.ENTRIES.size()
	var got: int = Codex.get_unlocked_count()
	codex_progress.text = "%d / %d fragmentos descubiertos" % [got, total]
	codex_entry_title.text = "Selecciona un fragmento"
	codex_entry_body.text = ""
	for id_key in Codex.ENTRIES.keys():
		var entry: Dictionary = Codex.ENTRIES[id_key]
		var unlocked: bool = Codex.is_unlocked(id_key)
		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.text = entry.get("title", String(id_key)) if unlocked else "??? (bloqueado)"
		btn.add_theme_font_size_override("font_size", 14)
		btn.modulate = Color(1, 1, 1, 1) if unlocked else Color(0.4, 0.4, 0.45, 1)
		btn.disabled = not unlocked
		btn.pressed.connect(_show_codex_entry.bind(id_key))
		codex_list.add_child(btn)


func _show_codex_entry(id: StringName) -> void:
	if not Codex.is_unlocked(id):
		return
	var entry: Dictionary = Codex.ENTRIES.get(id, {})
	codex_entry_title.text = entry.get("title", String(id))
	codex_entry_body.text = entry.get("body", "")


func _save_loadout() -> void:
	var ids := PackedStringArray()
	if lo_rifle.button_pressed: ids.append("rifle_basic")
	if lo_pistol.button_pressed: ids.append("pistol_basic")
	if lo_shotgun.button_pressed: ids.append("shotgun_basic")
	if lo_knife.button_pressed: ids.append("knife_basic")
	if lo_sniper.button_pressed: ids.append("rifle_sniper")
	if ids.is_empty():
		ids.append("rifle_basic")  # mínimo una arma
	Settings.set_loadout(ids, int(lo_grenades.value))
	loadout_panel.visible = false


func _populate_achievements_list() -> void:
	# Limpia la lista actual y rellena desde Achievements.CATALOG.
	for child in achievements_list.get_children():
		child.queue_free()
	var total: int = Achievements.CATALOG.size()
	var got: int = Achievements.get_unlocked_count()
	achievements_progress.text = "%d / %d desbloqueados" % [got, total]
	for id_key in Achievements.CATALOG.keys():
		var entry: Dictionary = Achievements.CATALOG[id_key]
		var unlocked: bool = Achievements.is_unlocked(id_key)
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var icon := Label.new()
		icon.text = "[X]" if unlocked else "[ ]"
		icon.add_theme_font_size_override("font_size", 18)
		icon.modulate = Color(0.55, 1.0, 0.6, 1.0) if unlocked else Color(0.5, 0.5, 0.5, 1.0)
		icon.custom_minimum_size = Vector2(40, 0)
		row.add_child(icon)
		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_lbl := Label.new()
		name_lbl.text = entry.get("name", String(id_key))
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.modulate = Color(1, 1, 1, 1) if unlocked else Color(0.6, 0.6, 0.65, 1.0)
		text_box.add_child(name_lbl)
		var desc_lbl := Label.new()
		desc_lbl.text = entry.get("desc", "")
		desc_lbl.add_theme_font_size_override("font_size", 13)
		desc_lbl.modulate = Color(0.7, 0.85, 1, 0.85) if unlocked else Color(0.5, 0.5, 0.5, 0.7)
		text_box.add_child(desc_lbl)
		row.add_child(text_box)
		achievements_list.add_child(row)


func _on_quit() -> void:
	get_tree().quit()


func _set_difficulty(d: int) -> void:
	Settings.difficulty = d
	_refresh_difficulty_buttons()


func _refresh_difficulty_buttons() -> void:
	# Resaltar el botón activo con un modulate cyan; los demás en gris.
	var active := Color(0.55, 0.95, 1.0, 1.0)
	var inactive := Color(0.6, 0.6, 0.65, 1.0)
	diff_easy.modulate = active if Settings.difficulty == Settings.Difficulty.EASY else inactive
	diff_normal.modulate = active if Settings.difficulty == Settings.Difficulty.NORMAL else inactive
	diff_hard.modulate = active if Settings.difficulty == Settings.Difficulty.HARD else inactive
