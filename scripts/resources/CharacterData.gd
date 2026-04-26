class_name CharacterData
extends Resource
## Stats base de un personaje (Player o NPC). Lo lee el entity
## en _ready() y configura sus components.

@export var display_name: String = "Player"
@export var max_health: float = 100.0
@export var move_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 6.0
@export var mouse_sensitivity: float = 0.003
@export var starting_weapon: WeaponData
