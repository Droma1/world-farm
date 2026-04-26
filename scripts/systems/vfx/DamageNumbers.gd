extends Node
## Spawnea Label3D flotantes "+N" cuando el local_player inflige daño.
## Se suscribe a EventBus.damage_dealt; filtra para mostrar solo daño
## saliente (el daño entrante se feedback'ea con el vignette + shake del
## HUD/Player).

@export var lifetime: float = 0.8
@export var rise: float = 1.2          # m que sube el número antes de fadeear
@export var color_normal: Color = Color(1.0, 0.92, 0.5, 1.0)
@export var color_high: Color = Color(1.0, 0.55, 0.20, 1.0)  # daños grandes
@export var high_threshold: float = 25.0
@export var font_size: int = 32


func _ready() -> void:
	EventBus.damage_dealt.connect(_on_damage_dealt)


func _on_damage_dealt(target: Object, amount: float, source: Node) -> void:
	# Solo daño que NOSOTROS infligimos.
	if source == null or source != GameState.local_player:
		return
	if not (target is Node3D):
		return
	_spawn_number(target as Node3D, amount)


func _spawn_number(target: Node3D, amount: float) -> void:
	var label := Label3D.new()
	label.text = "%d" % int(round(amount))
	label.font_size = font_size
	label.outline_size = 6
	label.outline_modulate = Color(0, 0, 0, 1)
	label.modulate = color_high if amount >= high_threshold else color_normal
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true                # se ve a través de paredes
	label.fixed_size = true                   # tamaño constante en pantalla
	label.shaded = false
	label.pixel_size = 0.005

	get_tree().current_scene.add_child(label)
	# Posicionar en el target con un pequeño offset aleatorio para que
	# disparos rápidos al mismo enemigo no superpongan números.
	var jitter := Vector3(
		RNG.randf_range(-0.25, 0.25),
		RNG.randf_range(0.0, 0.3),
		RNG.randf_range(-0.25, 0.25)
	)
	var start_pos := target.global_position + Vector3(0, 1.7, 0) + jitter
	label.global_position = start_pos

	var end_pos := start_pos + Vector3(0, rise, 0)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "global_position", end_pos, lifetime) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, lifetime) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)
