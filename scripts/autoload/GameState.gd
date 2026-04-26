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

# Referencia al Player controlado por este cliente. La asigna el propio
# Player en _ready(). Cualquier UI/HUD se suscribe a local_player_changed
# para vincularse sin necesidad de path absoluto.
var local_player: Node = null:
	set(value):
		if local_player == value:
			return
		local_player = value
		local_player_changed.emit(value)


func add_score(points: int) -> void:
	score = score + points


func reset() -> void:
	score = 0
	mode = Mode.PLAYING
