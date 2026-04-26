class_name WaveSystem
extends Node
## Orquestador de oleadas. State machine BETWEEN → SPAWNING → ACTIVE → VICTORY.
## Soporta oleadas con mezcla de tipos vía WaveData.build_spawn_queue().

@export var waves: Array[WaveData] = []
@export var spawn_points_path: NodePath
@export var initial_delay: float = 3.0
@export var time_between_waves: float = 5.0

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
	EventBus.wave_started.emit(current_wave_idx, waves.size(), wave)
	EventBus.wave_alive_count_changed.emit(_spawn_queue.size())


func _spawn_one() -> void:
	var wave := waves[current_wave_idx]
	if wave == null or _spawn_points.is_empty() or _spawn_queue.is_empty():
		return
	var data: EnemyData = _spawn_queue.pop_front()
	var enemy := wave.enemy_scene.instantiate() as Node3D
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
