class_name Pickup
extends Area3D
## Base de pickups: hover + spin + detección por overlap con Player.
## Subclases sobrescriben _apply_to_player() con su efecto concreto.

signal picked_up(picker: Node)

@export var spin_speed: float = 2.0          # rad/s
@export var hover_amplitude: float = 0.15    # m
@export var hover_speed: float = 2.5

var _t: float = 0.0
var _base_y: float = 0.0
var _base_y_captured: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	# Capturamos _base_y en el primer frame, NO en _ready, porque el spawner
	# (ej. Enemy._maybe_drop_pickup) suele setear global_position DESPUÉS de
	# add_child(). Si capturamos en _ready, _base_y queda en 0 y el pickup
	# salta a y≈0 (puede caer fuera del nivel y romper física/colisiones).
	if not _base_y_captured:
		_base_y = global_position.y
		_base_y_captured = true
	_t += delta
	rotate_y(spin_speed * delta)
	global_position.y = _base_y + sin(_t * hover_speed) * hover_amplitude


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		_apply_to_player(body)
		picked_up.emit(body)
		EventBus.item_picked_up.emit(self, body)
		queue_free()


# Override en subclase
func _apply_to_player(_player: Player) -> void:
	pass
