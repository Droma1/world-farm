extends Control
## Pantalla principal. Carga el escenario compacto al pulsar Jugar. Opciones reusan
## Settings autoload (mismo flow que el pause menu).

@export var play_scene: PackedScene

@onready var play_btn: Button = $Container/Buttons/PlayButton
@onready var options_btn: Button = $Container/Buttons/OptionsButton
@onready var quit_btn: Button = $Container/Buttons/QuitButton
@onready var options_panel: Control = $OptionsPanel
@onready var sens_slider: HSlider = $OptionsPanel/Container/SensRow/SensSlider
@onready var vol_slider: HSlider = $OptionsPanel/Container/VolRow/VolSlider
@onready var back_btn: Button = $OptionsPanel/Container/BackButton


func _ready() -> void:
	# Por si veníamos pausados de un retry: limpiar
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameState.reset()

	options_panel.visible = false

	play_btn.pressed.connect(_on_play)
	options_btn.pressed.connect(_show_options)
	quit_btn.pressed.connect(_on_quit)
	back_btn.pressed.connect(_hide_options)

	sens_slider.value = Settings.mouse_sensitivity
	vol_slider.value = Settings.master_volume
	sens_slider.value_changed.connect(func(v): Settings.mouse_sensitivity = v)
	vol_slider.value_changed.connect(func(v): Settings.master_volume = v)


func _on_play() -> void:
	if play_scene:
		get_tree().change_scene_to_packed(play_scene)


func _show_options() -> void:
	options_panel.visible = true


func _hide_options() -> void:
	options_panel.visible = false


func _on_quit() -> void:
	get_tree().quit()
