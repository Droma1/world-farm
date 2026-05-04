class_name EnemyData
extends Resource
## Stats de un enemigo. La AI los lee en _ready.

## Arquetipo de comportamiento. Cada uno tiene tweaks específicos en EnemyAI:
##   GRUNT  - balanceado, rusheo + dispara en attack_range (default).
##   SWIFT  - rushea agresivo, ignora cobertura, no se agacha.
##   HEAVY  - lento pero tanky, prefiere quedarse fijo y disparar.
##   SNIPER - mantiene distancia, busca cobertura, dispara dañazos.
##   ACID   - similar a grunt; al morir podría dejar charco (futuro).
##   ALPHA  - jefe; invoca refuerzos al -50% HP, daño aumentado.
##   DRONE  - blocky_drone; flota en su nivel, tiroteo a media distancia.
enum Archetype { GRUNT, SWIFT, HEAVY, SNIPER, ACID, ALPHA, DRONE }

@export var display_name: String = "Grunt"
@export var archetype: Archetype = Archetype.GRUNT
## Escena del enemigo. Si está vacío, WaveSystem usará la escena fallback de
## la WaveData. Esto permite mezclar puma + blocky + lo-que-sea en una misma
## wave: cada EnemyData decide qué escena instanciar.
@export var scene: PackedScene
@export var max_health: float = 60.0
@export var move_speed: float = 3.0
@export var weapon: WeaponData
@export var score_value: int = 100
@export var body_tint: Color = Color(1, 1, 1, 1)
@export var drop_chance: float = 0.35       # 0..1 — probabilidad de soltar pickup
## Pesos del loot table por tipo. Si todos los pesos son 0, fallback a la
## tabla por defecto en Enemy._maybe_drop_pickup. Útil para que cada
## arquetipo tenga su flavor (Alpha → más armor, Swift → más speed).
@export var drop_weight_health: float = 0.40
@export var drop_weight_ammo: float = 0.38
@export var drop_weight_speed: float = 0.14
@export var drop_weight_armor: float = 0.08
@export_group("AI")
@export var detection_range: float = 22.0
@export var attack_range: float = 12.0
@export var stop_range: float = 6.5
@export var lose_target_range: float = 30.0
@export var turn_speed: float = 6.0
