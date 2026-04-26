class_name EnemyData
extends Resource
## Stats de un enemigo. La AI los lee en _ready.

@export var display_name: String = "Grunt"
@export var max_health: float = 60.0
@export var move_speed: float = 3.0
@export var weapon: WeaponData
@export var score_value: int = 100
@export var body_tint: Color = Color(1, 1, 1, 1)
@export var drop_chance: float = 0.35       # 0..1 — probabilidad de soltar pickup
@export_group("AI")
@export var detection_range: float = 22.0
@export var attack_range: float = 12.0
@export var stop_range: float = 6.5
@export var lose_target_range: float = 30.0
@export var turn_speed: float = 6.0
