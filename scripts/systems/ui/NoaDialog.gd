extends Node
## N.O.A — Neural Operations Assistant. Sistema de diálogo radio entre waves.
## Mensajes scriptados por evento (wave_started, wave_completed, alpha_call,
## player_low_hp, etc.). Cola FIFO con typewriter effect.
##
## El HUD instancia este sistema y le pasa el Label objetivo. Los mensajes
## se cuelan vía señales del EventBus para mantener desacoplamiento.

signal message_displayed(text: String)
signal queue_emptied

const CHAR_DELAY: float = 0.025          ## seg por carácter
const MIN_DISPLAY_TIME: float = 2.5      ## tiempo mínimo visible tras completar
const PAUSE_BETWEEN_MESSAGES: float = 0.6

# Diálogos scriptados por evento. Las claves son los nombres de signals
# del EventBus + parámetros relevantes. Múltiples variantes → pick aleatorio.
const MESSAGES: Dictionary = {
	"tutorial_intro": [
		"N.O.A: Bienvenido, CAPY-0. Sistema neuronal sincronizado.",
	],
	"tutorial_movement": [
		"N.O.A: WASD para moverte. Espacio para saltar. Shift para correr.",
	],
	"tutorial_combat": [
		"N.O.A: Click izq para disparar. R para recargar. Boton derecho zoom.",
	],
	"tutorial_weapons": [
		"N.O.A: 1 = Rifle  ·  2 = Pistola  ·  3 = Cuchillo  ·  Q intercambio.",
	],
	"tutorial_ready": [
		"N.O.A: Hostiles entrando en zona. Buena suerte, Capy.",
	],
	"wave_started_0": [
		"N.O.A: Iniciando simulacion. Senales hostiles detectadas, Capy.",
		"N.O.A: Sistema activo. Tres unidades aproximandose.",
	],
	"wave_started_1": [
		"N.O.A: Refuerzos veloces entrando por el flanco. Mantente movil.",
		"N.O.A: Atencion: nueva firma, tipo Swift. Mas agiles que los Grunts.",
	],
	"wave_started_2": [
		"N.O.A: Detecto unidad francotiradora. Distancia critica.",
		"N.O.A: Compuestos toxicos en el aire. Sus rondas son letales.",
	],
	"wave_started_3": [
		"N.O.A: Senal Alpha confirmada. Repito: senal Alpha confirmada.",
		"N.O.A: El comandante hostil ha llegado. Suerte, Capy.",
	],
	"wave_started_4": [
		"N.O.A: Drones del Consorcio Helix activos. Su IA es... distinta.",
		"N.O.A: Drones detectados. Esto no estaba en el plan original.",
	],
	"wave_started_5": [
		"N.O.A: Anomalia detectada. La simulacion esta... fragmentandose.",
		"N.O.A: Capy. Algo va mal. Las firmas no encajan con el catalogo.",
		"N.O.A: ERROR PARCIAL. Mantente en zona segura. Estoy revisando.",
	],
	"wave_completed": [
		"N.O.A: Zona despejada. Tu eficiencia ha mejorado un 3.2%.",
		"N.O.A: Buen trabajo. Reabasteciendo modulos defensivos.",
		"N.O.A: Pausa breve. Las proximas seran mas dificiles.",
	],
	"alpha_reinforcements": [
		"N.O.A: Alarma. El Alpha esta llamando refuerzos.",
		"N.O.A: Senal de invocacion detectada. Cuidado por la espalda.",
	],
	"player_low_hp": [
		"N.O.A: Tu integridad esta en rojo. Busca un kit medico.",
		"N.O.A: Soporte vital al 25%. Considera retirarte temporalmente.",
	],
	"hack_started": [
		"N.O.A: Iniciando hackeo de defensas. Mantente con vida, Capy.",
		"N.O.A: Conectandome al sistema. Cada golpe que recibes me retrasa.",
	],
	"hack_completed": [
		"N.O.A: Acceso total. Hostiles desactivados. Excelente trabajo.",
		"N.O.A: Hecho. Ya tengo control de las firmas. Eres muy eficiente.",
	],
	"hack_reset": [
		"N.O.A: Conexion perdida. Necesito que aguantes mas, Capy.",
	],
	"multikill_3": [
		"N.O.A: Triple. Eficiencia notable.",
		"N.O.A: Tres simultaneos. El Consorcio toma nota.",
	],
	"multikill_4": [
		"N.O.A: Multi-kill registrado. Datos almacenados.",
		"N.O.A: Cuatro a la vez. Eso ya no es coincidencia.",
	],
	"multikill_5": [
		"N.O.A: ...esto no esta en el manual de entrenamiento.",
		"N.O.A: Mitico. Repetimos? El Consorcio querra ver esto otra vez.",
	],
	"victory": [
		"N.O.A: Simulacion completada. Datos transferidos al Consorcio.",
		"N.O.A: Excelente. Esto... ha sido informativo, Capy.",
	],
	"game_over": [
		"N.O.A: Soporte vital perdido. Reiniciando simulacion.",
		"N.O.A: Reintentando. La proxima iteracion sera distinta.",
	],
}

var _label: Label = null
var _queue: Array[String] = []
var _typing: bool = false
var _typewriter_t: float = 0.0
var _char_idx: int = 0
var _current_text: String = ""
var _display_t: float = 0.0
var _low_hp_warned: bool = false


func _ready() -> void:
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_completed.connect(_on_wave_completed)
	EventBus.alpha_called_reinforcements.connect(_on_alpha_reinforcements)
	EventBus.all_waves_completed.connect(_on_victory)
	EventBus.player_died.connect(_on_player_died)
	EventBus.entity_damaged.connect(_on_entity_damaged)
	HackingSystem.hack_completed.connect(func(): _say("hack_completed"))
	HackingSystem.hack_reset.connect(func(): _say("hack_reset"))
	EventBus.multikill.connect(_on_multikill)


## El HUD llama esto en _ready() para enlazar el Label visible.
func bind_label(label: Label) -> void:
	_label = label
	if _label:
		_label.text = ""


func enqueue(text: String) -> void:
	_queue.append(text)
	if not _typing:
		_advance_queue()


func _advance_queue() -> void:
	if _queue.is_empty():
		_typing = false
		queue_emptied.emit()
		return
	_current_text = _queue.pop_front()
	_typing = true
	_char_idx = 0
	_typewriter_t = 0.0
	_display_t = 0.0
	if _label:
		_label.text = ""


func _process(delta: float) -> void:
	if not _typing or _label == null:
		return
	if _char_idx < _current_text.length():
		_typewriter_t += delta
		while _typewriter_t >= CHAR_DELAY and _char_idx < _current_text.length():
			_typewriter_t -= CHAR_DELAY
			_char_idx += 1
			_label.text = _current_text.substr(0, _char_idx)
	else:
		_display_t += delta
		if _display_t >= MIN_DISPLAY_TIME:
			# Pausa breve y avanza
			_typing = false
			get_tree().create_timer(PAUSE_BETWEEN_MESSAGES).timeout.connect(func():
				if _label:
					_label.text = ""
				_advance_queue()
			)


# --- Pick + enqueue por evento ---

func _say(key: String) -> void:
	var arr: Array = MESSAGES.get(key, [])
	if arr.is_empty():
		return
	var pick: String = arr[RNG.randi_range(0, arr.size() - 1)]
	enqueue(pick)
	message_displayed.emit(pick)


func _on_wave_started(index: int, _total: int, _data: Resource) -> void:
	_low_hp_warned = false
	# Tutorial: solo la primera wave de la primera partida del jugador.
	if index == 0 and not Settings.tutorial_done:
		_say("tutorial_intro")
		_say("tutorial_movement")
		_say("tutorial_combat")
		_say("tutorial_weapons")
		_say("tutorial_ready")
		Settings.mark_tutorial_done()
		return
	# Wave 0..5 tienen mensajes propios; siguientes reutilizan el ultimo.
	var key: String = "wave_started_%d" % mini(index, 5)
	_say(key)


func _on_wave_completed(_index: int) -> void:
	_say("wave_completed")


func _on_alpha_reinforcements(_alpha: Node) -> void:
	_say("alpha_reinforcements")


func _on_victory() -> void:
	_say("victory")


func _on_player_died(_player: Node) -> void:
	_say("game_over")


func _on_multikill(count: int) -> void:
	if count >= 5:
		_say("multikill_5")
	elif count == 4:
		_say("multikill_4")
	elif count == 3:
		_say("multikill_3")


func _on_entity_damaged(entity: Node, _amount: float) -> void:
	# Aviso de low HP solo una vez por wave.
	if _low_hp_warned:
		return
	if entity != GameState.local_player:
		return
	var hp := entity.get_node_or_null("HealthComponent") as HealthComponent
	if hp == null:
		return
	if hp.current_health <= hp.max_health * 0.25:
		_low_hp_warned = true
		_say("player_low_hp")
