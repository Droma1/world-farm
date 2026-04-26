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


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Capturamos posición Y inicial para el bobbing
	_base_y = global_position.y


func _process(delta: float) -> void:
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
