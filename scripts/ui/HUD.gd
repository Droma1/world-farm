class_name HUD
extends CanvasLayer
## HUD del Player local: crosshair, vida, ammo, recarga, score, oleadas,
## flash de daño, overlay de game-over/victoria, pause menu con sliders.

@onready var health_bar: ProgressBar = $Root/HealthPanel/HealthBar
@onready var stamina_bar: ProgressBar = $Root/HealthPanel/StaminaBar
@onready var health_label: Label = $Root/HealthPanel/HealthLabel
@onready var ammo_label: Label = $Root/AmmoPanel/AmmoLabel
@onready var reload_label: Label = $Root/AmmoPanel/ReloadLabel
@onready var weapon_name_label: Label = $Root/AmmoPanel/WeaponNameLabel
@onready var grenade_label: Label = $Root/AmmoPanel/GrenadeLabel
@onready var damage_vignette: ColorRect = $Root/DamageVignette
@onready var glitch_overlay: ColorRect = $Root/GlitchOverlay
@onready var hit_dir_container: Control = $Root/HitDirContainer
@onready var countdown_label: Label = $Root/CountdownLabel
@onready var scope_overlay: Control = $Root/ScopeOverlay
@onready var wave_label: Label = $Root/WavePanel/WaveLabel
@onready var enemies_label: Label = $Root/WavePanel/EnemiesLabel
@onready var end_overlay: ColorRect = $Root/EndOverlay
@onready var end_title: Label = $Root/EndOverlay/EndTitle
@onready var end_hint: Label = $Root/EndOverlay/EndHint
@onready var score_label: Label = $Root/ScorePanel/ScoreLabel
@onready var streak_label: Label = $Root/ScorePanel/StreakLabel

@onready var boss_panel: Control = $Root/BossPanel
@onready var boss_label: Label = $Root/BossPanel/BossLabel
@onready var boss_bar: ProgressBar = $Root/BossPanel/BossBar
@onready var hack_panel: Control = $Root/HackPanel
@onready var hack_label: Label = $Root/HackPanel/HackLabel
@onready var hack_bar: ProgressBar = $Root/HackPanel/HackBar
@onready var crosshair: Control = $Root/Crosshair
@onready var crosshair_h_line: ColorRect = $Root/Crosshair/HLine
@onready var crosshair_v_line: ColorRect = $Root/Crosshair/VLine
@onready var crosshair_center: ColorRect = $Root/Crosshair/CenterDot
@onready var hit_marker: Control = $Root/Crosshair/HitMarker
@onready var pickup_feed: VBoxContainer = $Root/PickupFeed
@onready var pause_menu: Control = $PauseMenu

# Crosshair dinámico: cada arma define un preset (longitud, color, rotación,
# visibilidad de líneas/punto). El largo se expande con velocidad del player
# y spread del arma.
var _crosshair_base_length: float = 8.0
var _crosshair_base_thickness: float = 2.0
var _crosshair_show_lines: bool = true
var _crosshair_show_dot: bool = true
var _crosshair_rotation: float = 0.0
var _crosshair_color: Color = Color(1, 1, 1, 0.85)
@onready var sens_slider: HSlider = $PauseMenu/Container/SensRow/SensSlider
@onready var vol_slider: HSlider = $PauseMenu/Container/VolRow/VolSlider
@onready var music_slider: HSlider = $PauseMenu/Container/MusicRow/MusicSlider
@onready var sfx_slider: HSlider = $PauseMenu/Container/SfxRow/SfxSlider
@onready var resume_btn: Button = $PauseMenu/Container/ResumeButton
@onready var quit_btn: Button = $PauseMenu/Container/QuitButton

var _player: Player
var _flash_tween: Tween
var _hit_marker_tween: Tween

# F3 debug overlay (FPS, posición, enemigos)
var _debug_label: Label
var _debug_visible: bool = false
var _debug_acc: float = 0.0

# Boss tracking + cinemática
var _boss: Node = null
var _boss_health: HealthComponent = null

# Glitch system (Acto 3): activo desde wave_idx >= 5. Parpadeo del overlay,
# distorsión del wave_label, ocasional flicker del crosshair.
var _glitch_active: bool = false
var _glitch_intensity: float = 0.0
var _glitch_acc: float = 0.0


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
	music_slider.value = Settings.music_volume
	sfx_slider.value = Settings.sfx_volume
	sens_slider.value_changed.connect(_on_sens_changed)
	vol_slider.value_changed.connect(_on_vol_changed)
	music_slider.value_changed.connect(func(v): Settings.music_volume = v)
	sfx_slider.value_changed.connect(func(v): Settings.sfx_volume = v)
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
	EventBus.kill_streak_reward.connect(_on_streak_reward)
	EventBus.multikill.connect(_on_multikill)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.entity_died.connect(_on_entity_died_for_boss)
	EventBus.grenade_thrown.connect(_on_grenade_thrown)
	HackingSystem.hack_progress_changed.connect(_on_hack_progress)
	HackingSystem.hack_completed.connect(_on_hack_completed)
	HackingSystem.hack_reset.connect(_on_hack_reset)
	Achievements.unlocked.connect(_on_achievement_unlocked)
	Codex.entry_unlocked.connect(_on_codex_unlocked)
	hit_marker.modulate.a = 0.0
	streak_label.text = ""

	if GameState.local_player is Player:
		_bind(GameState.local_player)

	# Conectar el panel N.O.A. al sistema autoload.
	var noa_label := $Root/NoaPanel/NoaLabel as Label
	if noa_label and Engine.has_singleton("NoaDialog"):
		pass  # singleton via name; Godot autoloads no usan has_singleton, las accedemos por nombre
	if noa_label:
		NoaDialog.bind_label(noa_label)

	_debug_label = Label.new()
	_debug_label.add_theme_font_size_override("font_size", 14)
	_debug_label.modulate = Color(0.6, 1.0, 0.6, 0.95)
	_debug_label.position = Vector2(8, 8)
	_debug_label.z_index = 100
	_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_label.visible = false
	$Root.add_child(_debug_label)


func _process(delta: float) -> void:
	# Boss bar update
	if _boss_health and is_instance_valid(_boss_health):
		boss_bar.value = _boss_health.current_health

	# Stamina bar
	if _player and _player.movement and stamina_bar:
		stamina_bar.max_value = _player.movement.max_stamina
		stamina_bar.value = _player.movement.stamina
	# Sniper scope: visible solo cuando arma actual es sniper Y FOV está cerca de ADS.
	if scope_overlay and _player and _player.weapon and _player.weapon.current and _player.camera:
		var w_id := String(_player.weapon.current.id)
		var is_sniper: bool = w_id.contains("sniper")
		var is_ads: bool = _player.camera.fov < 50.0
		var should_show: bool = is_sniper and is_ads
		if scope_overlay.visible != should_show:
			scope_overlay.visible = should_show
			# El crosshair normal lo escondemos durante scope (la cruz del scope lo reemplaza).
			if crosshair:
				crosshair.visible = not should_show
	# Health bar suave (tween via lerp manual)
	if _player and _player.health and health_bar:
		health_bar.value = lerpf(health_bar.value, _player.health.current_health, delta * 12.0)

	# Glitch effect (Acto 3): parpadeo del overlay + jitter del wave_label.
	if _glitch_active and glitch_overlay:
		_glitch_acc += delta
		# Pulso aleatorio del overlay cyan
		var base_alpha: float = 0.10 + 0.20 * _glitch_intensity
		if RNG.randf() < 0.04 * _glitch_intensity:
			glitch_overlay.modulate.a = base_alpha + RNG.randf() * 0.6
		else:
			glitch_overlay.modulate.a = lerpf(glitch_overlay.modulate.a, 0.0, delta * 6.0)
		# Jitter del wave_label (X offset)
		if wave_label:
			wave_label.position.x = sin(_glitch_acc * 22.0) * 2.0 * _glitch_intensity
		# Score flicker
		if score_label and RNG.randf() < 0.02 * _glitch_intensity:
			score_label.modulate = Color(RNG.randf(), 1, RNG.randf(), 1)
		elif score_label:
			score_label.modulate = score_label.modulate.lerp(Color(1, 0.95, 0.7, 1), delta * 4.0)
	elif glitch_overlay and glitch_overlay.modulate.a > 0.001:
		glitch_overlay.modulate.a = lerpf(glitch_overlay.modulate.a, 0.0, delta * 6.0)
		if wave_label:
			wave_label.position.x = lerpf(wave_label.position.x, 0.0, delta * 8.0)

	# Debug overlay (F3)
	if _debug_visible and _debug_label:
		_debug_acc += delta
		if _debug_acc >= 0.2:  # update 5 veces/s
			_debug_acc = 0.0
			_debug_label.text = _build_debug_text()

	# Crosshair dinámico: las líneas H/V cruzan el centro y se ALARGAN cuando
	# el player se mueve o el arma tiene spread alto. ADS (FOV bajo) las
	# acorta ligeramente. Es la versión simple — 2 ColorRects existentes en
	# la escena, sin gap central.
	if _player == null or crosshair_h_line == null or crosshair_v_line == null:
		return
	var speed_factor: float = 0.0
	if _player.movement:
		var v: float = Vector2(_player.movement.local_velocity.x, _player.movement.local_velocity.z).length()
		speed_factor = clampf(v / 8.0, 0.0, 1.0)
	var spread_factor: float = 0.0
	if _player.weapon and _player.weapon.current:
		spread_factor = clampf(_player.weapon.current.spread_degrees / 5.0, 0.0, 1.0)
	var ads_factor: float = 0.0
	if _player.camera:
		ads_factor = clampf((70.0 - _player.camera.fov) / 35.0, 0.0, 1.0)
	var half_length: float = _crosshair_base_length + speed_factor * 6.0 + spread_factor * 4.0 - ads_factor * 3.0
	half_length = maxf(half_length, 2.0)
	var th: float = _crosshair_base_thickness
	# H line cruzando el centro: -half a +half horizontal, fina vertical.
	crosshair_h_line.anchor_left = 0.5
	crosshair_h_line.anchor_right = 0.5
	crosshair_h_line.offset_left = -half_length
	crosshair_h_line.offset_right = half_length
	crosshair_h_line.offset_top = -th * 0.5
	crosshair_h_line.offset_bottom = th * 0.5
	# V line cruzando el centro: fina horizontal, -half a +half vertical.
	crosshair_v_line.anchor_top = 0.5
	crosshair_v_line.anchor_bottom = 0.5
	crosshair_v_line.offset_top = -half_length
	crosshair_v_line.offset_bottom = half_length
	crosshair_v_line.offset_left = -th * 0.5
	crosshair_v_line.offset_right = th * 0.5


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var k := event as InputEventKey
		var terminal := (GameState.mode == GameState.Mode.GAME_OVER
				or GameState.mode == GameState.Mode.VICTORY)
		# Marcamos el input como handled ANTES de cambiar de escena. Una vez
		# que reload_current_scene/change_scene corren, el HUD puede estar
		# desconectado del árbol y get_viewport() devolvería null.
		var vp := get_viewport()
		if terminal and k.keycode == KEY_R:
			if vp:
				vp.set_input_as_handled()
			get_tree().reload_current_scene()
		elif terminal and k.keycode == KEY_M:
			if vp:
				vp.set_input_as_handled()
			get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
		elif k.keycode == KEY_ESCAPE and GameState.mode == GameState.Mode.PLAYING:
			if vp:
				vp.set_input_as_handled()
			_toggle_pause()
		elif k.keycode == KEY_F3:
			_debug_visible = not _debug_visible
			if _debug_label:
				_debug_label.visible = _debug_visible
			if vp:
				vp.set_input_as_handled()


func _build_debug_text() -> String:
	var fps: int = int(round(Engine.get_frames_per_second()))
	var pos := Vector3.ZERO
	var enemies := 0
	if _player and is_instance_valid(_player):
		pos = _player.global_position
	# Contar enemigos (CharacterBody3D con HealthComponent)
	var scene := get_tree().current_scene
	if scene:
		for child in scene.get_children():
			if child is CharacterBody3D and child != _player:
				enemies += 1
	var streak: int = GameState.kill_streak
	var dmg_mult: float = GameState.damage_multiplier()
	var rel_mult: float = GameState.reload_speed_multiplier()
	return "FPS  %d\nPOS  %.1f, %.1f, %.1f\nENEMIES  %d\nSTREAK  x%d  (dmg x%.1f, rel x%.2f)" % [
		fps, pos.x, pos.y, pos.z, enemies, streak, dmg_mult, rel_mult
	]


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
	# Inicializar contador de granadas
	_on_grenade_thrown(_player.grenades_left)


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


func _on_player_damaged(_amount: float, source: Node) -> void:
	_refresh_health()
	_flash_damage()
	_spawn_hit_indicator(source)


func _spawn_hit_indicator(source: Node) -> void:
	## Arco rojo apuntando al enemigo. Se posiciona en un radio fijo desde
	## el centro y rota según el ángulo body→source en el plano XZ del player.
	if hit_dir_container == null or _player == null or not (source is Node3D):
		return
	var src := source as Node3D
	if not is_instance_valid(src):
		return
	var to_src: Vector3 = src.global_position - _player.global_position
	to_src.y = 0.0
	if to_src.length_squared() < 0.001:
		return
	# Convertir a ángulo en el plano del player: 0 = adelante (-Z), positivo a la derecha.
	var basis := _player.global_transform.basis
	var local := basis.inverse() * to_src
	var angle: float = atan2(local.x, -local.z)  # 0 al frente, +PI/2 derecha

	# Container "rotor" centrado en (0,0) que rota según el ángulo. Sus hijos
	# (la barra del indicator + la flecha) se dibujan a -radius en Y, así que
	# al rotar parecen orbitar alrededor del centro de pantalla apuntando al
	# enemigo.
	var radius: float = 90.0
	var rotor := Control.new()
	rotor.position = Vector2.ZERO
	rotor.rotation = angle
	rotor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit_dir_container.add_child(rotor)

	var indicator := ColorRect.new()
	indicator.color = Color(1.0, 0.25, 0.20, 0.95)
	indicator.size = Vector2(60, 5)
	indicator.position = Vector2(-30, -radius)
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotor.add_child(indicator)

	var tip := ColorRect.new()
	tip.color = indicator.color
	tip.size = Vector2(3, 14)
	tip.position = Vector2(-1.5, -radius - 7)
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotor.add_child(tip)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(rotor, "modulate:a", 0.0, 1.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(0.4)
	tw.chain().tween_callback(rotor.queue_free)


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
	streak_label.text = "x%d STREAK  x%.1f" % [streak, multiplier]


func _on_boss_spawned(boss: Node) -> void:
	if boss == null or not is_instance_valid(boss):
		return
	_boss = boss
	_boss_health = boss.get_node_or_null("HealthComponent") as HealthComponent
	if _boss_health == null:
		return
	boss_panel.visible = true
	boss_bar.max_value = _boss_health.max_health
	boss_bar.value = _boss_health.current_health
	# Etiqueta usa display_name si existe.
	if boss.has_method("get") and "data" in boss and boss.data:
		boss_label.text = boss.data.display_name.to_upper()
	else:
		boss_label.text = "BOSS"
	# Cinemática corta: slow-mo + flash de pantalla, sin tomar control de la cámara.
	# El orbit real requeriría desactivar el input del player; con slow-mo + flash
	# conseguimos el "feel" sin las complicaciones.
	_boss_intro_cinematic()


func _boss_intro_cinematic() -> void:
	# El orbit real lo hace el Player (tiene la cámara). Aquí solo:
	# - Flash blanco breve para "boom" inicial
	# - Slow-mo más profundo (0.30) que el player gestiona desde su propio cinematic
	# - Le pasamos el boss al player para que sepa orbitar a su alrededor
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.45)
	flash.anchor_right = 1.0
	flash.anchor_bottom = 1.0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Root.add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.5).set_ease(Tween.EASE_OUT)
	tw.tween_callback(flash.queue_free)
	# Notifica al Player para iniciar el orbit (si existe el método).
	if _player and _player.has_method("start_boss_orbit") and _boss is Node3D:
		_player.start_boss_orbit(_boss as Node3D)


func _on_entity_died_for_boss(entity: Node) -> void:
	if entity == _boss:
		_boss = null
		_boss_health = null
		boss_panel.visible = false


func _on_grenade_thrown(_grenades_left: int) -> void:
	# Mostramos los 3 inventarios; el caller emite con el de la standard
	# pero releemos del player para los otros.
	if grenade_label and _player:
		grenade_label.text = "G x%d   T x%d   F x%d" % [
			_player.grenades_left, _player.smokes_left, _player.flashes_left
		]


func _on_hack_progress(percent: float) -> void:
	if hack_panel == null:
		return
	hack_panel.visible = HackingSystem.is_active() or percent > 0.0
	if hack_bar:
		hack_bar.value = percent
	if hack_label:
		hack_label.text = "N.O.A. - HACKEO EN PROGRESO  %d%%" % int(percent)


func _on_hack_completed() -> void:
	if hack_label:
		hack_label.text = "N.O.A. - ACCESO COMPLETO"
		hack_label.modulate = Color(0.5, 1.0, 0.6, 1.0)
	if hack_bar:
		hack_bar.value = 100.0
	get_tree().create_timer(2.0).timeout.connect(func():
		if hack_panel:
			hack_panel.visible = false
		if hack_label:
			hack_label.modulate = Color(0.55, 0.95, 1, 1)
	)


func _on_hack_reset() -> void:
	if hack_panel:
		hack_panel.visible = false


func _show_countdown_announce(text: String, color: Color = Color(1, 0.85, 0.4, 1)) -> void:
	## Anuncio grande centrado. Aparece, escala y desvanece. Color opcional.
	if countdown_label == null:
		return
	countdown_label.text = text
	countdown_label.modulate = Color(color.r, color.g, color.b, 0.0)
	countdown_label.scale = Vector2(0.5, 0.5)
	countdown_label.pivot_offset = countdown_label.size * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(countdown_label, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	tw.tween_property(countdown_label, "scale", Vector2(1.0, 1.0), 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(1.1)
	tw.chain().tween_property(countdown_label, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(func(): countdown_label.text = "")


func _on_codex_unlocked(_id: StringName, title: String) -> void:
	_show_toast("CODEX  -  " + title.to_upper(), Color(0.6, 0.85, 1, 1))


func _on_achievement_unlocked(_id: StringName, name: String) -> void:
	_show_toast("LOGRO  -  " + name.to_upper(), Color(1, 0.85, 0.4, 1))


func _show_toast(text: String, color: Color) -> void:
	# Toast genérico: usado para logros y codex unlocks. El texto suele venir
	# como "LOGRO  -  Nombre" o "CODEX  -  Titulo", el color lo define el caller.
	var panel := PanelContainer.new()
	panel.modulate = Color(1, 1, 1, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.modulate = color
	vbox.add_child(lbl)
	var screen_w: float = get_viewport().get_visible_rect().size.x
	panel.position = Vector2(screen_w - 320, 40)
	$Root.add_child(panel)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.3)
	tw.tween_property(panel, "position:x", screen_w - 340, 0.3)
	tw.chain().tween_interval(2.5)
	tw.chain().tween_property(panel, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(panel.queue_free)


func _on_multikill(count: int) -> void:
	var label := ""
	var col := Color(1, 0.85, 0.4, 1)
	match count:
		2:
			label = "DOBLE KILL"
			col = Color(1, 0.85, 0.40, 1)
		3:
			label = "TRIPLE KILL"
			col = Color(1, 0.55, 0.25, 1)
		4:
			label = "MULTI KILL"
			col = Color(1, 0.30, 0.30, 1)
		_:
			label = "MITICO  x%d" % count
			col = Color(0.55, 0.95, 1.0, 1)
	_show_countdown_announce(label, col)


func _on_streak_reward(streak: int) -> void:
	# Hito de recompensa: spawn texto grande tipo "RECARGA RAPIDA" / "DOBLE DAÑO".
	var msg := ""
	var col := Color(1.0, 0.85, 0.3, 1.0)
	match streak:
		5:
			msg = "RECARGA RAPIDA ACTIVA"
			col = Color(0.5, 1.0, 0.7, 1.0)
		10:
			msg = "DAÑO DOBLE ACTIVO"
			col = Color(1.0, 0.4, 0.4, 1.0)
		_:
			msg = "x%d STREAK" % streak
	var lbl := Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.modulate = col
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pickup_feed.add_child(lbl)
	var t := create_tween().set_parallel(true)
	t.tween_property(lbl, "position:y", lbl.position.y - 40.0, 1.5)
	t.tween_property(lbl, "modulate:a", 0.0, 1.5).set_delay(0.6)
	t.chain().tween_callback(lbl.queue_free)


func _on_pickup_collected(kind: StringName, amount: float) -> void:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match kind:
		&"health":
			label.text = "+%d HP" % int(amount)
			label.modulate = Color(0.4, 1.0, 0.5, 1.0)
		&"ammo":
			label.text = "+%d MUNICION" % int(amount)
			label.modulate = Color(1.0, 0.9, 0.3, 1.0)
		&"speed":
			label.text = "BOOST DE VELOCIDAD %ds" % int(amount)
			label.modulate = Color(0.45, 0.95, 1.0, 1.0)
		&"armor":
			label.text = "+%d MAX HP" % int(amount)
			label.modulate = Color(1.0, 0.85, 0.40, 1.0)
		&"grenade":
			label.text = "+%d GRANADA" % int(amount)
			label.modulate = Color(1.0, 0.55, 0.25, 1.0)
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
	# El cuchillo (melee) no usa balas — ocultar el contador de munición.
	var is_melee: bool = data != null and data.max_range < 5.0
	ammo_label.visible = not is_melee
	if is_melee:
		reload_label.visible = false
	if _player and _player.weapon:
		_on_ammo_changed(_player.weapon.in_mag, _player.weapon.reserve)
	_apply_crosshair_preset(data)


func _apply_crosshair_preset(data: WeaponData) -> void:
	## Selecciona apariencia del crosshair según el arma. La forma cambia
	## (cruz / X / punto / sniper) para que el player sienta el arma sin
	## mirar el panel de munición.
	if data == null:
		return
	var id := String(data.id)
	if id.begins_with("knife"):
		_crosshair_show_lines = true
		_crosshair_show_dot = false
		_crosshair_base_length = 7.0
		_crosshair_base_thickness = 2.0
		_crosshair_rotation = PI * 0.25  # X (rotada 45°)
		_crosshair_color = Color(1.0, 0.85, 0.40, 0.85)
	elif id.begins_with("pistol"):
		_crosshair_show_lines = true
		_crosshair_show_dot = true
		_crosshair_base_length = 5.0
		_crosshair_base_thickness = 2.0
		_crosshair_rotation = 0.0
		_crosshair_color = Color(0.95, 0.95, 1.0, 0.85)
	elif id.begins_with("shotgun"):
		# Shotgun: crosshair más abierto, color naranja, líneas gruesas.
		_crosshair_show_lines = true
		_crosshair_show_dot = false
		_crosshair_base_length = 14.0
		_crosshair_base_thickness = 3.0
		_crosshair_rotation = 0.0
		_crosshair_color = Color(1.0, 0.65, 0.30, 0.85)
	elif id.begins_with("rifle_sniper") or id.contains("sniper"):
		# Sniper: solo punto + líneas cortas y delgadas (mira "limpia" para apuntar)
		_crosshair_show_lines = true
		_crosshair_show_dot = true
		_crosshair_base_length = 4.0
		_crosshair_base_thickness = 1.0
		_crosshair_rotation = 0.0
		_crosshair_color = Color(1.0, 0.50, 0.50, 0.85)
	else:
		# Rifle por defecto
		_crosshair_show_lines = true
		_crosshair_show_dot = true
		_crosshair_base_length = 8.0
		_crosshair_base_thickness = 2.0
		_crosshair_rotation = 0.0
		_crosshair_color = Color(1.0, 1.0, 1.0, 0.85)
	if crosshair:
		crosshair.rotation = _crosshair_rotation
	if crosshair_center:
		crosshair_center.visible = _crosshair_show_dot
	if crosshair_h_line:
		crosshair_h_line.visible = _crosshair_show_lines
		crosshair_h_line.color = _crosshair_color
	if crosshair_v_line:
		crosshair_v_line.visible = _crosshair_show_lines
		crosshair_v_line.color = _crosshair_color


func _on_ammo_changed(in_mag: int, reserve: int) -> void:
	if not ammo_label.visible:
		return
	ammo_label.text = "%d / %d" % [in_mag, reserve]


func _on_reload_started() -> void:
	if _player and _player.weapon and _player.weapon.current \
			and _player.weapon.current.max_range < 5.0:
		return  # melee no recarga
	reload_label.visible = true


func _on_reload_finished() -> void:
	reload_label.visible = false


func _on_weapon_swapped(weapon_data: Resource, _slot: int) -> void:
	if weapon_data and "display_name" in weapon_data:
		weapon_name_label.text = weapon_data.display_name
	var is_melee: bool = weapon_data != null and "max_range" in weapon_data \
			and weapon_data.max_range < 5.0
	ammo_label.visible = not is_melee
	if is_melee:
		reload_label.visible = false


# ============================================================
#  Waves & game state
# ============================================================

func _on_wave_started(index: int, total: int, data: Resource) -> void:
	var wave_name: String = data.name if data and "name" in data else "Wave"
	var affix_name: String = GameState.current_wave_affix_name
	if affix_name != "":
		wave_label.text = "OLEADA %d / %d  -  %s  [%s]" % [index + 1, total, wave_name, affix_name]
		_show_countdown_announce("OLEADA %d\n[%s]" % [index + 1, affix_name])
	else:
		wave_label.text = "OLEADA %d / %d  -  %s" % [index + 1, total, wave_name]
		_show_countdown_announce("OLEADA %d" % (index + 1))
	# Acto 3: a partir de la wave 6 (index 5) la simulacion empieza a fallar.
	if index >= 5:
		_set_glitch_active(true, float(index - 4))
	else:
		_set_glitch_active(false, 0.0)


func _set_glitch_active(active: bool, intensity: float) -> void:
	_glitch_active = active
	_glitch_intensity = clampf(intensity, 0.0, 3.0)


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
			end_hint.text = _build_end_hint("R: reintentar    ·    M: menu")
			# Si estábamos pausados, despausar (el end overlay reemplaza el pause)
			if get_tree().paused:
				get_tree().paused = false
				pause_menu.visible = false
		GameState.Mode.VICTORY:
			end_overlay.visible = true
			end_title.text = "VICTORIA"
			end_title.modulate = Color(0.5, 1, 0.6, 1)
			end_hint.text = _build_end_hint("R: jugar de nuevo    ·    M: menu")
			if get_tree().paused:
				get_tree().paused = false
				pause_menu.visible = false
		GameState.Mode.PLAYING:
			end_overlay.visible = false


func _build_end_hint(action_line: String) -> String:
	var record_marker := ""
	if GameState.score > 0 and GameState.score >= Settings.high_score:
		record_marker = "  *NUEVO RECORD*"
	var dur := GameState.run_duration_seconds()
	var mins := int(dur) / 60
	var secs := int(dur) % 60
	var acc := GameState.accuracy() * 100.0
	return ("SCORE %d%s\n"
			+ "RECORD %d   ·   STREAK MAX %d\n"
			+ "\n"
			+ "KILLS %d   HEADSHOTS %d   PRECISION %.0f%%\n"
			+ "DMG +%d / -%d     TIEMPO  %d:%02d\n"
			+ "\n"
			+ "%s") % [
		GameState.score,
		record_marker,
		Settings.high_score,
		Settings.highest_streak,
		GameState.kills_this_run,
		GameState.headshots_this_run,
		acc,
		int(GameState.damage_dealt),
		int(GameState.damage_taken),
		mins, secs,
		action_line,
	]
