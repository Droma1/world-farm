class_name WaveSystem
extends Node
## Orquestador de oleadas. State machine BETWEEN → SPAWNING → ACTIVE → VICTORY.
## Soporta oleadas con mezcla de tipos vía WaveData.build_spawn_queue().

@export var waves: Array[WaveData] = []
@export var spawn_points_path: NodePath
@export var initial_delay: float = 3.0
@export var time_between_waves: float = 5.0
@export var endless_mode: bool = false   ## Cuando se acaben las waves, generar más infinitamente
@export var endless_pool: Array[EnemyData] = []  ## EnemyData usable en endless waves

# Affixes (modificadores aleatorios) que pueden aplicarse a una wave.
# Se elige uno random a partir de wave_idx >= 2 para añadir variedad.
enum Affix { NONE, SWIFT, ARMORED, FURIOUS, GENEROUS }
const AFFIX_NAMES: Dictionary = {
	Affix.NONE: "",
	Affix.SWIFT: "VELOCES",
	Affix.ARMORED: "BLINDADOS",
	Affix.FURIOUS: "FURIOSOS",
	Affix.GENEROUS: "HEMOFILICOS",
}
var current_affix: int = Affix.NONE

enum Phase { BETWEEN, SPAWNING, ACTIVE, VICTORY }

var phase: Phase = Phase.BETWEEN
var current_wave_idx: int = -1

var _phase_timer: float = 0.0
var _spawn_cooldown: float = 0.0
var _spawn_queue: Array[EnemyData] = []
var _alive: Array[Node] = []
var _spawn_points: Array[Node3D] = []


func _ready() -> void:
	var sp_parent := get_node_or_null(spawn_points_path)
	if sp_parent:
		for child in sp_parent.get_children():
			if child is Node3D:
				_spawn_points.append(child)
	if _spawn_points.is_empty():
		push_warning("WaveSystem: no hay spawn points en %s" % spawn_points_path)

	EventBus.entity_died.connect(_on_entity_died)
	EventBus.alpha_called_reinforcements.connect(_on_alpha_reinforcements)
	_phase_timer = initial_delay
	phase = Phase.BETWEEN


func _process(delta: float) -> void:
	if GameState.mode != GameState.Mode.PLAYING:
		return
	match phase:
		Phase.BETWEEN:
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_start_next_wave()
		Phase.SPAWNING:
			_spawn_cooldown -= delta
			if _spawn_cooldown <= 0.0 and not _spawn_queue.is_empty():
				_spawn_one()
			if _spawn_queue.is_empty():
				phase = Phase.ACTIVE
		Phase.ACTIVE:
			if _alive.is_empty():
				_complete_wave()
		Phase.VICTORY:
			pass


func _start_next_wave() -> void:
	current_wave_idx += 1
	if current_wave_idx >= waves.size():
		if endless_mode:
			# Genera una wave dinámica y la añade al array. Stats escalan
			# con (current_wave_idx - waves.size_initial). Damos la vuelta
			# eligiendo enemy_data del pool aleatoriamente.
			waves.append(_generate_endless_wave(current_wave_idx))
		else:
			phase = Phase.VICTORY
			EventBus.all_waves_completed.emit()
			GameState.mode = GameState.Mode.VICTORY
			return
	var wave := waves[current_wave_idx]
	if wave == null or wave.enemy_scene == null:
		push_warning("WaveSystem: oleada %d inválida" % current_wave_idx)
		_complete_wave()
		return
	_spawn_queue = wave.build_spawn_queue()
	_spawn_cooldown = 0.0
	phase = Phase.SPAWNING
	# Affix aleatorio a partir de wave 3 (index >= 2). Los enemigos lo leerán
	# en su _ready vía WaveSystem.current_affix (Enemy.gd los aplica).
	if current_wave_idx >= 2:
		current_affix = RNG.randi_range(Affix.SWIFT, Affix.GENEROUS)
	else:
		current_affix = Affix.NONE
	EventBus.wave_started.emit(current_wave_idx, waves.size(), wave)
	EventBus.wave_affix_changed.emit(current_affix, AFFIX_NAMES[current_affix])
	EventBus.wave_alive_count_changed.emit(_spawn_queue.size())


func _spawn_one() -> void:
	var wave := waves[current_wave_idx]
	if wave == null or _spawn_points.is_empty() or _spawn_queue.is_empty():
		return
	var data: EnemyData = _spawn_queue.pop_front()
	# Cada EnemyData puede definir su propia escena (ej: blocky usa
	# EnemyBlocky.tscn). Si no, fallback a la escena de la wave.
	var scene: PackedScene = data.scene if (data and data.scene) else wave.enemy_scene
	if scene == null:
		push_warning("WaveSystem: no hay escena ni en EnemyData ni en WaveData")
		return
	var enemy := scene.instantiate() as Node3D
	if enemy == null:
		return
	if data and "data" in enemy:
		enemy.data = data

	var sp := _spawn_points[RNG.randi_range(0, _spawn_points.size() - 1)]
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = sp.global_position
	_alive.append(enemy)

	_spawn_cooldown = wave.spawn_interval


func _complete_wave() -> void:
	EventBus.wave_completed.emit(current_wave_idx)
	if current_wave_idx >= waves.size() - 1:
		phase = Phase.VICTORY
		EventBus.all_waves_completed.emit()
		GameState.mode = GameState.Mode.VICTORY
	else:
		phase = Phase.BETWEEN
		_phase_timer = time_between_waves


func _on_entity_died(entity: Node) -> void:
	if entity in _alive:
		_alive.erase(entity)
		EventBus.wave_alive_count_changed.emit(_alive.size() + _spawn_queue.size())


func _generate_endless_wave(idx: int) -> WaveData:
	## Crea WaveData procedural cada vez que se necesita una wave nueva en
	## endless. La cantidad de enemigos crece logarítmicamente y el spawn
	## interval baja con el índice. El pool fija qué enemy_data se permiten.
	var w := WaveData.new()
	w.name = "ENDLESS  -  Oleada %d" % (idx + 1)
	# Si el pool está vacío, fallback a la última wave estática.
	var pool: Array[EnemyData] = endless_pool
	if pool.is_empty() and not waves.is_empty():
		var last_wave: WaveData = waves[waves.size() - 1]
		if last_wave and last_wave.enemy_data_list:
			pool = last_wave.enemy_data_list.duplicate()
	if pool.is_empty():
		return w  # vacía → wave skipped
	# Necesitamos enemy_scene fallback (la del primer wave estática) por si
	# algun EnemyData no tiene `scene` propio.
	var fallback_scene: PackedScene = null
	if not waves.is_empty() and waves[0]:
		fallback_scene = waves[0].enemy_scene
	w.enemy_scene = fallback_scene
	# Scaling: cada 3 waves de endless añade un tipo más al mix.
	var endless_idx: int = idx - max(0, waves.size() - 1)
	var distinct_types: int = mini(pool.size(), 2 + endless_idx / 3)
	# Pickear N tipos del pool
	var picks: Array[EnemyData] = []
	var available: Array[EnemyData] = pool.duplicate()
	for _i in range(distinct_types):
		if available.is_empty():
			break
		var pick_idx: int = RNG.randi_range(0, available.size() - 1)
		picks.append(available[pick_idx])
		available.remove_at(pick_idx)
	w.enemy_data_list = picks
	# Cantidades: base 2 + endless_idx/2 cada tipo, mínimo 1.
	var counts: Array[int] = []
	for _i in range(picks.size()):
		counts.append(maxi(1, 2 + endless_idx / 2 + RNG.randi_range(0, 2)))
	w.enemy_counts = counts
	# Spawn interval: baja de 1.0 a 0.4 progresivamente.
	w.spawn_interval = clampf(1.0 - endless_idx * 0.04, 0.4, 1.0)
	return w


func _on_alpha_reinforcements(_alpha: Node) -> void:
	## ALPHA invoca 2 swifts: los añadimos a la cola de spawn de la wave actual.
	if current_wave_idx < 0 or current_wave_idx >= waves.size():
		return
	var wave := waves[current_wave_idx]
	if wave == null or wave.enemy_data_list.is_empty():
		return
	# Buscar un swift en la lista actual de la wave; si no hay, usar el primero.
	var swift_data: EnemyData = null
	for d in wave.enemy_data_list:
		if d and d.archetype == EnemyData.Archetype.SWIFT:
			swift_data = d
			break
	if swift_data == null:
		swift_data = wave.enemy_data_list[0]
	for _i in range(2):
		_spawn_queue.append(swift_data)
	# Reactivamos SPAWNING si estaba en ACTIVE (los enemigos ya bajaron de la cola).
	if phase == Phase.ACTIVE:
		phase = Phase.SPAWNING
		_spawn_cooldown = 0.5
	EventBus.wave_alive_count_changed.emit(_alive.size() + _spawn_queue.size())
