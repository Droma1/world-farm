extends Node
## Estado global de la partida. NO contiene lógica de gameplay,
## solo flags, contadores y referencias compartidas.

signal local_player_changed(player: Node)
signal mode_changed(new_mode: int)
signal score_changed(new_score: int)

enum Mode { MENU, PLAYING, PAUSED, GAME_OVER, VICTORY }

var mode: Mode = Mode.PLAYING:
	set(value):
		if mode == value:
			return
		mode = value
		mode_changed.emit(value)
		# Persistir record al terminar la partida (game over o victoria).
		if value == Mode.GAME_OVER or value == Mode.VICTORY:
			Settings.maybe_record_score(score)
			Settings.maybe_record_streak(highest_streak_this_run)
			Settings.add_lifetime_stats(kills_this_run, headshots_this_run, run_duration_seconds())

var score: int = 0:
	set(value):
		if score == value:
			return
		score = value
		score_changed.emit(value)

# --- Kill streak ---
const STREAK_WINDOW: float = 3.0      # segundos para encadenar un kill
const STREAK_MULTIPLIER_STEP: float = 0.5  # streak 2 = x1.5, 3 = x2.0, 4 = x2.5...
const STREAK_MAX_MULTIPLIER: float = 4.0   # tope x4

var kill_streak: int = 0
var highest_streak_this_run: int = 0
var _streak_timer: float = 0.0

# Multikill tracking: ventana de 1.2s para encadenar 2/3/4+ kills.
const MULTIKILL_WINDOW: float = 1.2
var _multikill_count: int = 0
var _multikill_timer: float = 0.0

# Stats per-run para el end-screen.
var kills_this_run: int = 0
var headshots_this_run: int = 0
var shots_fired: int = 0
var shots_hit: int = 0
var damage_dealt: float = 0.0
var damage_taken: float = 0.0
var run_start_time_ms: int = 0


func accuracy() -> float:
	if shots_fired <= 0:
		return 0.0
	return clampf(float(shots_hit) / float(shots_fired), 0.0, 1.0)


func run_duration_seconds() -> float:
	if run_start_time_ms <= 0:
		return 0.0
	return float(Time.get_ticks_msec() - run_start_time_ms) / 1000.0

# Referencia al Player controlado por este cliente. La asigna el propio
# Player en _ready(). Cualquier UI/HUD se suscribe a local_player_changed
# para vincularse sin necesidad de path absoluto.
## Affix activo de la wave actual (mirror del WaveSystem para que cualquier
## sistema lo lea sin dependencia directa). Setea un Enemy en su _ready.
var current_wave_affix: int = 0  # Affix.NONE
var current_wave_affix_name: String = ""

var local_player: Node = null:
	set(value):
		if local_player == value:
			return
		local_player = value
		local_player_changed.emit(value)


func _ready() -> void:
	# Persistir wave_completed en Settings para mostrarlo en MainMenu.
	EventBus.wave_completed.connect(func(_idx): Settings.add_completed_wave())
	EventBus.wave_affix_changed.connect(func(a: int, n: String):
		current_wave_affix = a
		current_wave_affix_name = n
	)
	# Stats per-run
	EventBus.weapon_fired.connect(_on_weapon_fired_for_stats)
	EventBus.damage_dealt.connect(_on_damage_dealt_for_stats)
	EventBus.entity_damaged.connect(_on_entity_damaged_for_stats)
	EventBus.headshot.connect(_on_headshot_for_stats)
	run_start_time_ms = Time.get_ticks_msec()


func _on_headshot_for_stats(_target: Object, source: Node) -> void:
	if source == local_player:
		headshots_this_run += 1


func _on_weapon_fired_for_stats(weapon: Node, _origin: Vector3, _dir: Vector3) -> void:
	if weapon and weapon.get_parent() == local_player:
		shots_fired += 1


func _on_damage_dealt_for_stats(_target: Object, amount: float, source: Node) -> void:
	if source == local_player:
		shots_hit += 1
		damage_dealt += amount


func _on_entity_damaged_for_stats(entity: Node, amount: float) -> void:
	if entity == local_player:
		damage_taken += amount


func _process(delta: float) -> void:
	if mode != Mode.PLAYING:
		return
	if _streak_timer > 0.0:
		_streak_timer -= delta
		if _streak_timer <= 0.0 and kill_streak > 0:
			_reset_streak()
	if _multikill_timer > 0.0:
		_multikill_timer -= delta
		if _multikill_timer <= 0.0:
			_multikill_count = 0


func register_kill(base_score: int) -> int:
	## Llamado por entities cuando matan a otro entity. Devuelve el score
	## final aplicado (base × multiplicador).
	kill_streak += 1
	kills_this_run += 1
	if kill_streak > highest_streak_this_run:
		highest_streak_this_run = kill_streak
	_streak_timer = STREAK_WINDOW
	# Multikill: si el siguiente kill cae dentro del MULTIKILL_WINDOW
	# del previo, incrementa contador. A los 2+ emite signal.
	if _multikill_timer > 0.0:
		_multikill_count += 1
		if _multikill_count >= 2:
			EventBus.multikill.emit(_multikill_count)
	else:
		_multikill_count = 1
	_multikill_timer = MULTIKILL_WINDOW
	var mult := streak_multiplier() * Settings.iron_mode_score_multiplier()
	var final_score: int = int(round(base_score * mult))
	score = score + final_score
	EventBus.kill_streak_changed.emit(kill_streak, mult)
	# Hitos de recompensa: avisamos por EventBus para que el WeaponComponent
	# / Player apliquen buffs (recarga rápida x5, daño x2 a partir de x10).
	if kill_streak == 5 or kill_streak == 10:
		EventBus.kill_streak_reward.emit(kill_streak)
	return final_score


# Multiplicadores activos basados en el kill_streak. Los lee WeaponComponent
# y FastReload aplica.
func reload_speed_multiplier() -> float:
	if kill_streak >= 5:
		return 0.45  # 55% más rápido
	return 1.0


func damage_multiplier() -> float:
	if kill_streak >= 10:
		return 2.0
	return 1.0


func notify_player_damaged() -> void:
	## El Player perdiendo vida resetea el streak (penalización).
	if kill_streak > 0:
		_reset_streak()


func streak_multiplier() -> float:
	if kill_streak < 2:
		return 1.0
	var m: float = 1.0 + (kill_streak - 1) * STREAK_MULTIPLIER_STEP
	return minf(m, STREAK_MAX_MULTIPLIER)


func _reset_streak() -> void:
	kill_streak = 0
	_streak_timer = 0.0
	EventBus.kill_streak_changed.emit(0, 1.0)


func add_score(points: int) -> void:
	score = score + points


func reset() -> void:
	score = 0
	kill_streak = 0
	highest_streak_this_run = 0
	_streak_timer = 0.0
	kills_this_run = 0
	headshots_this_run = 0
	shots_fired = 0
	shots_hit = 0
	damage_dealt = 0.0
	damage_taken = 0.0
	run_start_time_ms = Time.get_ticks_msec()
	mode = Mode.PLAYING
