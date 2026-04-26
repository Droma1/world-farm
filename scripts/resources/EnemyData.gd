class_name EnemyData
extends Resource
## Stats de un enemigo. La AI los lee en _ready.

@export var display_name: String = "Grunt"
@export var max_health: float = 60.0
@export var move_speed: float = 3.0
@export var weapon: WeaponData
@export_group("AI")
@export var detection_range: float = 22.0
@export var attack_range: float = 12.0
@export var stop_range: float = 6.5         # no se acerca más de esto al atacar
@export var lose_target_range: float = 30.0 # más allá de esto deja de perseguir
@export var turn_speed: float = 6.0         # rad/s al apuntar
