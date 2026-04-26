extends Node
## Gestor de audio. Carga .ogg de assets/audio/sfx/ con variaciones por
## sonido y elige una al azar en cada play_3d (anti-robotic). Suscrito al
## EventBus para reaccionar a weapon_fired e impact.
##
## Para añadir un sonido nuevo: pon el .ogg en assets/audio/sfx/<categoría>/
## y añade la ruta a STREAM_VARIATIONS[<key>].

# StringName → Array de rutas. Cada call a play_*() pickea una al azar.
const STREAM_VARIATIONS: Dictionary = {
	&"shoot": [
		"res://assets/audio/sfx/weapon/shoot_01.ogg",
		"res://assets/audio/sfx/weapon/shoot_02.ogg",
		"res://assets/audio/sfx/weapon/shoot_03.ogg",
	],
	&"impact_wall": [
		"res://assets/audio/sfx/impact/wall_01.ogg",
		"res://assets/audio/sfx/impact/wall_02.ogg",
		"res://assets/audio/sfx/impact/wall_03.ogg",
	],
	&"hit_flesh": [
		"res://assets/audio/sfx/impact/flesh_01.ogg",
		"res://assets/audio/sfx/impact/flesh_02.ogg",
	],
	&"footstep": [
		"res://assets/audio/sfx/footstep/step_01.ogg",
		"res://assets/audio/sfx/footstep/step_02.ogg",
		"res://assets/audio/sfx/footstep/step_03.ogg",
		"res://assets/audio/sfx/footstep/step_04.ogg",
		"res://assets/audio/sfx/footstep/step_05.ogg",
	],
	&"reload_click": [
		"res://assets/audio/sfx/weapon/reload_click.ogg",
	],
}

var _streams: Dictionary = {}


func _ready() -> void:
	for key in STREAM_VARIATIONS.keys():
		var arr: Array[AudioStream] = []
		for path in STREAM_VARIATIONS[key]:
			var s := load(path) as AudioStream
			if s:
				arr.append(s)
			else:
				push_warning("AudioManager: no pudo cargar %s" % path)
		_streams[key] = arr

	EventBus.weapon_fired.connect(_on_weapon_fired)
	EventBus.impact.connect(_on_impact)


# ============================================================
#  API pública
# ============================================================

func play_3d(sound: StringName, world_pos: Vector3, volume_db: float = 0.0,
		pitch_jitter: float = 0.06, max_distance: float = 60.0) -> void:
	var stream := _pick_stream(sound)
	if stream == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + RNG.randf_range(-pitch_jitter, pitch_jitter)
	p.unit_size = 8.0
	p.max_distance = max_distance
	p.attenuation_filter_cutoff_hz = 8000.0
	get_tree().current_scene.add_child(p)
	p.global_position = world_pos
	p.play()
	p.finished.connect(p.queue_free)


func play_2d(sound: StringName, volume_db: float = 0.0,
		pitch_jitter: float = 0.04) -> void:
	var stream := _pick_stream(sound)
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + RNG.randf_range(-pitch_jitter, pitch_jitter)
	get_tree().current_scene.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


# ============================================================
#  Internals
# ============================================================

func _pick_stream(sound: StringName) -> AudioStream:
	var arr := _streams.get(sound, []) as Array
	if arr.is_empty():
		return null
	return arr[RNG.randi_range(0, arr.size() - 1)]


func _on_weapon_fired(_weapon: Node, origin: Vector3, _direction: Vector3) -> void:
	play_3d(&"shoot", origin, 0.0)


func _on_impact(position: Vector3, _normal: Vector3, collider: Object) -> void:
	if collider is CharacterBody3D:
		play_3d(&"hit_flesh", position, -2.0)
	else:
		play_3d(&"impact_wall", position, -4.0)
