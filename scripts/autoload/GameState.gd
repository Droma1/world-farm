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
var _streak_timer: float = 0.0

# Referencia al Player controlado por este cliente. La asigna el propio
# Player en _ready(). Cualquier UI/HUD se suscribe a local_player_changed
# para vincularse sin necesidad de path absoluto.
var local_player: Node = null:
	set(value):
		if local_player == value:
			return
		local_player = value
		local_player_changed.emit(value)


func _process(delta: float) -> void:
	if mode != Mode.PLAYING:
		return
	if _streak_timer > 0.0:
		_streak_timer -= delta
		if _streak_timer <= 0.0 and kill_streak > 0:
			_reset_streak()


func register_kill(base_score: int) -> int:
	## Llamado por entities cuando matan a otro entity. Devuelve el score
	## final aplicado (base × multiplicador).
	kill_streak += 1
	_streak_timer = STREAK_WINDOW
	var mult := streak_multiplier()
	var final_score: int = int(round(base_score * mult))
	score = score + final_score
	EventBus.kill_streak_changed.emit(kill_streak, mult)
	return final_score


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
	_streak_timer = 0.0
	mode = Mode.PLAYING
