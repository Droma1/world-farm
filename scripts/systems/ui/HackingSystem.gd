extends Node
## Sistema de hacking de N.O.A. (Acto 2 narrativo). Mientras el player
## sobrevive, una progress bar sube. Si recibe daño, baja. Si llega a 100%,
## la wave actual termina antes (kills automáticos del resto de enemigos +
## bonus de score). Si vida cae a 0, reinicia el progreso.
##
## Diseñado para activarse desde Wave 2 (index >= 1) con NoaDialog avisando.

signal hack_progress_changed(percent: float)
signal hack_completed
signal hack_reset

const ACTIVATION_WAVE_INDEX: int = 1     ## A partir de qué wave (0-indexed) se activa
const PROGRESS_PER_SECOND: float = 5.0   ## %/s ganados sin recibir daño
const PROGRESS_LOSS_PER_DAMAGE: float = 2.5  ## % perdidos por punto de daño recibido
const COMPLETION_SCORE_BONUS: int = 500
const RESET_BELOW_HP_PERCENT: float = 0.20  ## bajo este % de vida, el hack se rompe

var _active: bool = false
var _progress: float = 0.0
var _wave_index: int = -1


func _ready() -> void:
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_completed.connect(_on_wave_completed)
	EventBus.entity_damaged.connect(_on_entity_damaged)
	EventBus.player_died.connect(_on_player_died)


func _process(delta: float) -> void:
	if not _active:
		return
	if GameState.mode != GameState.Mode.PLAYING:
		return
	_progress = clampf(_progress + PROGRESS_PER_SECOND * delta, 0.0, 100.0)
	hack_progress_changed.emit(_progress)
	if _progress >= 100.0:
		_complete()


func _complete() -> void:
	if not _active:
		return
	_active = false
	GameState.add_score(COMPLETION_SCORE_BONUS)
	hack_completed.emit()
	# Mata al resto de enemigos vivos como recompensa narrativa: N.O.A
	# desactivó las firmas hostiles del Consorcio.
	var scene := get_tree().current_scene
	if scene:
		for ch in scene.get_children():
			if ch is CharacterBody3D and ch != GameState.local_player:
				var hp := ch.get_node_or_null("HealthComponent") as HealthComponent
				if hp and hp.is_alive():
					hp.take_damage(99999.0, GameState.local_player)


func _on_wave_started(index: int, _total: int, _data: Resource) -> void:
	_wave_index = index
	if index >= ACTIVATION_WAVE_INDEX:
		_active = true
		_progress = 0.0
		hack_progress_changed.emit(_progress)
	else:
		_active = false
		hack_reset.emit()


func _on_wave_completed(_index: int) -> void:
	# Si la wave se completa por kills antes de que termine el hack, lo
	# pausamos hasta la siguiente wave.
	_active = false
	_progress = 0.0
	hack_reset.emit()


func _on_entity_damaged(entity: Node, amount: float) -> void:
	if not _active or entity != GameState.local_player:
		return
	_progress = clampf(_progress - amount * PROGRESS_LOSS_PER_DAMAGE, 0.0, 100.0)
	hack_progress_changed.emit(_progress)
	# Bajo X% HP, el hack colapsa.
	if entity.has_node("HealthComponent"):
		var hp := entity.get_node("HealthComponent") as HealthComponent
		if hp and hp.current_health / hp.max_health < RESET_BELOW_HP_PERCENT:
			_progress = 0.0
			hack_progress_changed.emit(_progress)
			hack_reset.emit()


func _on_player_died(_player: Node) -> void:
	_active = false
	_progress = 0.0
	hack_reset.emit()


func get_progress() -> float:
	return _progress


func is_active() -> bool:
	return _active
