extends Node
## Gestor de audio. Carga .ogg de assets/audio/sfx/ con variaciones por
## sonido y elige una al azar en cada play_3d (anti-robotic). Suscrito al
## EventBus para reaccionar a weapon_fired, impact y waves (música dinámica).
##
## Para añadir un sonido nuevo: pon el .ogg en assets/audio/sfx/<categoría>/
## y añade la ruta a STREAM_VARIATIONS[<key>].
## Para añadir música: pon el .ogg en assets/audio/music/ y añádelo a MUSIC_TRACKS.

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
	# "hit_body" reemplaza al antiguo "hit_flesh": son golpes metálicos / de
	# armadura, acordes con la temática sci-fi del entrenamiento (CC0 Kenney).
	&"hit_body": [
		"res://assets/audio/sfx/impact/body_hit_01.ogg",
		"res://assets/audio/sfx/impact/body_hit_02.ogg",
		"res://assets/audio/sfx/impact/body_hit_03.ogg",
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
	# Sonidos cronometrados con la animación de recarga 3 fases (lift/side/return).
	&"reload_mag_out": [
		"res://assets/audio/sfx/weapon/reload_mag_out.ogg",
	],
	&"reload_mag_in": [
		"res://assets/audio/sfx/weapon/reload_mag_in.ogg",
	],
	&"reload_bolt": [
		"res://assets/audio/sfx/weapon/reload_bolt.ogg",
	],
	# Swoosh sci-fi del cuchillo (reemplaza el SFX de balazo en melee).
	&"knife_swoosh": [
		"res://assets/audio/sfx/weapon/knife_swoosh_01.ogg",
		"res://assets/audio/sfx/weapon/knife_swoosh_02.ogg",
	],
	# Explosion (granada).
	&"explosion": [
		"res://assets/audio/sfx/weapon/explosion_01.ogg",
		"res://assets/audio/sfx/weapon/explosion_02.ogg",
	],
}

# Pistas de música. La key se usa con play_music(key). CC0 OpenGameArt.
const MUSIC_TRACKS: Dictionary = {
	&"combat_loop": "res://assets/audio/music/combat_loop.ogg",
	&"combat_intense": "res://assets/audio/music/combat_intense.ogg",
	&"menu_ambient": "res://assets/audio/music/menu_ambient.mp3",
}

@export var music_default_db: float = -8.0  ## Volumen "objetivo" de la música
@export var music_fade_in: float = 1.5
@export var music_fade_out: float = 1.8

var _streams: Dictionary = {}
var _music_streams: Dictionary = {}
var _music_player: AudioStreamPlayer
var _music_tween: Tween
var _current_music_key: StringName = &""

# Bus fallback: si el proyecto NO tiene un bus_layout custom con Music/SFX,
# todos los players se mandan a Master. Esto se calcula en _ready.
var _bus_music: StringName = &"Master"
var _bus_sfx: StringName = &"Master"


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

	for key in MUSIC_TRACKS.keys():
		var s := load(MUSIC_TRACKS[key]) as AudioStream
		if s:
			# OGG Vorbis y MP3 soportan loop nativo en Godot.
			if s is AudioStreamOggVorbis:
				(s as AudioStreamOggVorbis).loop = true
			elif s is AudioStreamMP3:
				(s as AudioStreamMP3).loop = true
			_music_streams[key] = s
		else:
			push_warning("AudioManager: no pudo cargar música %s" % MUSIC_TRACKS[key])

	# Resolver buses: si el proyecto define Music/SFX (vía default_bus_layout)
	# los usamos; si no, fallback a Master. Evita warnings de "bus not found".
	if AudioServer.get_bus_index(&"Music") >= 0:
		_bus_music = &"Music"
	if AudioServer.get_bus_index(&"SFX") >= 0:
		_bus_sfx = &"SFX"
	# Player único de música. Bus dedicado "Music" (controlado independiente
	# del SFX). El volumen general (Master) sigue en Settings.master_volume.
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = _bus_music
	_music_player.volume_db = -80.0  # silencio inicial
	add_child(_music_player)

	EventBus.weapon_fired.connect(_on_weapon_fired)
	EventBus.impact.connect(_on_impact)
	# Música dinámica: suena al iniciar wave, baja al terminar.
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_completed.connect(_on_wave_completed)
	EventBus.all_waves_completed.connect(_on_all_waves_completed)
	EventBus.player_died.connect(_on_player_died)


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
	p.bus = _bus_sfx
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
	p.bus = _bus_sfx
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
		play_3d(&"hit_body", position, -2.0)
	else:
		play_3d(&"impact_wall", position, -4.0)


# ============================================================
#  Música dinámica
# ============================================================

## Inicia (o cambia) la pista de música con fade-in. Si ya está sonando la
## misma pista, no hace nada.
func play_music(key: StringName, fade_seconds: float = -1.0) -> void:
	if _music_player == null:
		return
	if key == _current_music_key and _music_player.playing:
		return
	var stream := _music_streams.get(key) as AudioStream
	if stream == null:
		push_warning("AudioManager.play_music: key desconocido %s" % key)
		return
	var fade: float = music_fade_in if fade_seconds < 0.0 else fade_seconds
	_current_music_key = key
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_player.stream = stream
	_music_player.volume_db = -80.0
	_music_player.play()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", music_default_db, fade) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Detiene la música actual con fade-out.
func stop_music(fade_seconds: float = -1.0) -> void:
	if _music_player == null or not _music_player.playing:
		return
	var fade: float = music_fade_out if fade_seconds < 0.0 else fade_seconds
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", -80.0, fade) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_music_tween.tween_callback(_music_player.stop)
	_current_music_key = &""


# Alterna entre las dos pistas (variedad por wave) — wave 1 + 3 + 5 = combat_loop;
# wave 2 + 4 + 6 = combat_intense.
func _on_wave_started(index: int, _total: int, _data: Resource) -> void:
	var key: StringName = &"combat_loop" if index % 2 == 0 else &"combat_intense"
	play_music(key)


func _on_wave_completed(_index: int) -> void:
	# Pequeño respiro entre waves: bajamos la música un poco (no del todo).
	if _music_player and _music_player.playing:
		if _music_tween and _music_tween.is_valid():
			_music_tween.kill()
		_music_tween = create_tween()
		_music_tween.tween_property(_music_player, "volume_db", music_default_db - 10.0, 0.8)


func _on_all_waves_completed() -> void:
	stop_music()


func _on_player_died(_player: Node) -> void:
	stop_music()
