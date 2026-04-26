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
## Armas iniciales del Player. Index 0 es la primaria (1 key), 1 secundaria (2).
@export var starting_weapons: Array[WeaponData] = []
## Mantenido por compatibilidad con código antiguo. Si starting_weapons está
## vacío, se usa este como única arma inicial.
@export var starting_weapon: WeaponData
