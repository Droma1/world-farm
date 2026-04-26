extends Node
## Estado global de la partida. NO contiene lógica de gameplay,
## solo flags, contadores y referencias compartidas.

signal local_player_changed(player: Node)

enum Mode { MENU, PLAYING, PAUSED, GAME_OVER }

var mode: Mode = Mode.PLAYING
var score: int = 0

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
	score += points


func reset() -> void:
	score = 0
	mode = Mode.PLAYING
