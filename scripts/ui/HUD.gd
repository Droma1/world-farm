class_name HUD
extends CanvasLayer
## HUD del Player local: crosshair, vida, ammo, recarga, score, oleadas,
## flash de daño, overlay de game-over/victoria, pause menu con sliders.

@onready var health_bar: ProgressBar = $Root/HealthPanel/HealthBar
@onready var health_label: Label = $Root/HealthPanel/HealthLabel
@onready var ammo_label: Label = $Root/AmmoPanel/AmmoLabel
@onready var reload_label: Label = $Root/AmmoPanel/ReloadLabel
@onready var weapon_name_label: Label = $Root/AmmoPanel/WeaponNameLabel
@onready var damage_vignette: ColorRect = $Root/DamageVignette
@onready var wave_label: Label = $Root/WavePanel/WaveLabel
@onready var enemies_label: Label = $Root/WavePanel/EnemiesLabel
@onready var end_overlay: ColorRect = $Root/EndOverlay
@onready var end_title: Label = $Root/EndOverlay/EndTitle
@onready var end_hint: Label = $Root/EndOverlay/EndHint
@onready var score_label: Label = $Root/ScorePanel/ScoreLabel
@onready var streak_label: Label = $Root/ScorePanel/StreakLabel

@onready var hit_marker: Control = $Root/Crosshair/HitMarker
@onready var pickup_feed: VBoxContainer = $Root/PickupFeed
@onready var pause_menu: Control = $PauseMenu
@onready var sens_slider: HSlider = $PauseMenu/Container/SensRow/SensSlider
@onready var vol_slider: HSlider = $PauseMenu/Container/VolRow/VolSlider
@onready var resume_btn: Button = $PauseMenu/Container/ResumeButton
@onready var quit_btn: Button = $PauseMenu/Container/QuitButton

var _player: Player
var _flash_tween: Tween
var _hit_marker_tween: Tween


func _ready() -> void:
	reload_label.visible = false
	damage_vignette.modulate.a = 0.0
	end_overlay.visible = false
	pause_menu.visible = false
	wave_label.text = "PREPARANDO..."
	enemies_label.text = ""
	score_label.text = "SCORE  0"

	# Sliders sincronizados con Settings
	sens_slider.value = Settings.mouse_sensitivity
	vol_slider.value = Settings.master_volume
	sens_slider.value_changed.connect(_on_sens_changed)
	vol_slider.value_changed.connect(_on_vol_changed)
	resume_btn.pressed.connect(_toggle_pause)
	quit_btn.pressed.connect(_on_quit_pressed)

	GameState.local_player_changed.connect(_on_local_player_changed)
	GameState.mode_changed.connect(_on_game_mode_changed)
	GameState.score_changed.connect(_on_score_changed)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_alive_count_changed.connect(_on_wave_alive_changed)
	EventBus.wave_completed.connect(_on_wave_completed)
	EventBus.all_waves_completed.connect(_on_all_waves_completed)
	EventBus.weapon_swapped.connect(_on_weapon_swapped)
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.pickup_collected.connect(_on_pickup_collected)
	EventBus.kill_streak_changed.connect(_on_streak_changed)
	hit_marker.modulate.a = 0.0
	streak_label.text = ""

	if GameState.local_player is Player:
		_bind(GameState.local_player)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var k := event as InputEventKey
		var terminal := (GameState.mode == GameState.Mode.GAME_OVER
				or GameState.mode == GameState.Mode.VICTORY)
		if terminal and k.keycode == KEY_R:
			get_tree().reload_current_scene()
			get_viewport().set_input_as_handled()
		elif terminal and k.keycode == KEY_M:
			get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
			get_viewport().set_input_as_handled()
		elif k.keycode == KEY_ESCAPE and GameState.mode == GameState.Mode.PLAYING:
			_toggle_pause()
			get_viewport().set_input_as_handled()


# ============================================================
#  Pause
# ============================================================

func _toggle_pause() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	pause_menu.visible = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED


func _on_sens_changed(value: float) -> void:
	Settings.mouse_sensitivity = value
	if _player:
		_player._mouse_sensitivity = value


func _on_vol_changed(value: float) -> void:
	Settings.master_volume = value


func _on_quit_pressed() -> void:
	get_tree().quit()


# ============================================================
#  Player binding
# ============================================================

func _on_local_player_changed(player: Node) -> void:
	if player == null:
		_unbind()
	elif player is Player:
		_bind(player)


func _bind(player: Player) -> void:
	_unbind()
	_player = player
	if not is_instance_valid(_player):
		return
	if _player.health:
		_player.health.damaged.connect(_on_player_damaged)
		_player.health.healed.connect(_on_player_healed)
		_refresh_health()
	if _player.weapon:
		_player.weapon.ammo_changed.connect(_on_ammo_changed)
		_player.weapon.weapon_equipped.connect(_on_weapon_equipped)
		_player.weapon.reload_started.connect(_on_reload_started)
		_player.weapon.reload_finished.connect(_on_reload_finished)
		if _player.weapon.current:
			_on_weapon_equipped(_player.weapon.current)
			_on_ammo_changed(_player.weapon.in_mag, _player.weapon.reserve)


func _unbind() -> void:
	# En SP los signals se auto-desconectan al freeing del Player. Para MP /
	# respawn-sin-reload necesitaríamos disconnect explícitos aquí.
	_player = null
	reload_label.visible = false


# ============================================================
#  Health
# ============================================================

func _refresh_health() -> void:
	if _player == null or _player.health == null:
		return
	var hp := _player.health.current_health
	var max_hp := _player.health.max_health
	health_bar.max_value = max_hp
	health_bar.value = hp
	health_label.text = "HP  %d / %d" % [int(hp), int(max_hp)]


func _on_player_damaged(_amount: float, _source: Node) -> void:
	_refresh_health()
	_flash_damage()


func _on_player_healed(_amount: float) -> void:
	_refresh_health()


func _flash_damage() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	damage_vignette.modulate.a = 0.45
	_flash_tween = create_tween()
	_flash_tween.tween_property(damage_vignette, "modulate:a", 0.0, 0.45)


func _on_damage_dealt(_target: Object, _amount: float, source: Node) -> void:
	# Hit marker solo cuando NOSOTROS confirmamos un impacto.
	if source != GameState.local_player:
		return
	if _hit_marker_tween and _hit_marker_tween.is_valid():
		_hit_marker_tween.kill()
	hit_marker.modulate.a = 1.0
	_hit_marker_tween = create_tween()
	_hit_marker_tween.tween_property(hit_marker, "modulate:a", 0.0, 0.18)


func _on_streak_changed(streak: int, multiplier: float) -> void:
	if streak < 2:
		streak_label.text = ""
		return
	streak_label.text = "x%d STREAK  ×%.1f" % [streak, multiplier]


func _on_pickup_collected(kind: StringName, amount: float) -> void:
	var label := Label.new()
	label.theme_override_font_sizes["font_size"] = 22
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match kind:
		&"health":
			label.text = "+%d HP" % int(amount)
			label.modulate = Color(0.4, 1.0, 0.5, 1.0)
		&"ammo":
			label.text = "+%d MUNICIÓN" % int(amount)
			label.modulate = Color(1.0, 0.9, 0.3, 1.0)
		_:
			label.text = "+%d" % int(amount)
			label.modulate = Color(1, 1, 1, 1)
	pickup_feed.add_child(label)

	var tween := create_tween().set_parallel(true)
	tween.tween_interval(0.0)
	tween.tween_property(label, "position:y", label.position.y - 30.0, 1.6)
	tween.tween_property(label, "modulate:a", 0.0, 1.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(0.4)
	tween.chain().tween_callback(label.queue_free)


# ============================================================
#  Weapon
# ============================================================

func _on_weapon_equipped(data: WeaponData) -> void:
	if data:
		weapon_name_label.text = data.display_name
	if _player and _player.weapon:
		_on_ammo_changed(_player.weapon.in_mag, _player.weapon.reserve)


func _on_ammo_changed(in_mag: int, reserve: int) -> void:
	ammo_label.text = "%d / %d" % [in_mag, reserve]


func _on_reload_started() -> void:
	reload_label.visible = true


func _on_reload_finished() -> void:
	reload_label.visible = false


func _on_weapon_swapped(weapon_data: Resource, _slot: int) -> void:
	if weapon_data and "display_name" in weapon_data:
		weapon_name_label.text = weapon_data.display_name


# ============================================================
#  Waves & game state
# ============================================================

func _on_wave_started(index: int, total: int, data: Resource) -> void:
	var wave_name: String = data.name if data and "name" in data else "Wave"
	wave_label.text = "OLEADA %d / %d  —  %s" % [index + 1, total, wave_name]


func _on_wave_alive_changed(count: int) -> void:
	enemies_label.text = "%d enemigos restantes" % count if count > 0 else ""


func _on_wave_completed(_index: int) -> void:
	wave_label.text = "¡OLEADA SUPERADA!"
	enemies_label.text = ""


func _on_all_waves_completed() -> void:
	wave_label.text = "¡VICTORIA!"
	enemies_label.text = ""


func _on_score_changed(new_score: int) -> void:
	score_label.text = "SCORE  %d" % new_score


func _on_game_mode_changed(new_mode: int) -> void:
	match new_mode:
		GameState.Mode.GAME_OVER:
			end_overlay.visible = true
			end_title.text = "DERROTADO"
			end_title.modulate = Color(1, 0.4, 0.35, 1)
			end_hint.text = "R: reintentar"
			# Si estábamos pausados, despausar (el end overlay reemplaza el pause)
			if get_tree().paused:
				get_tree().paused = false
				pause_menu.visible = false
		GameState.Mode.VICTORY:
			end_overlay.visible = true
			end_title.text = "¡VICTORIA!"
			end_title.modulate = Color(0.5, 1, 0.6, 1)
			end_hint.text = "R: jugar de nuevo"
			if get_tree().paused:
				get_tree().paused = false
				pause_menu.visible = false
		GameState.Mode.PLAYING:
			end_overlay.visible = false
