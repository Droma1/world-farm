class_name WaveData
extends Resource
## Configuración de una oleada. Soporta MEZCLA de tipos: dos arrays
## paralelos `enemy_data_list` + `enemy_counts` permiten p.ej. spawnear
## 3 grunts + 1 heavy + 2 snipers en la misma oleada.
##
## Ejemplo en .tscn:
##   enemy_data_list = [ExtRes("grunt"), ExtRes("heavy")]
##   enemy_counts    = [3, 1]                       → 4 enemigos total
## El orden de spawn es secuencial (todos los grunts primero, luego heavy).

@export var name: String = "Wave"
@export var enemy_scene: PackedScene
@export var enemy_data_list: Array[EnemyData] = []
@export var enemy_counts: Array[int] = []
@export var spawn_interval: float = 1.2


func total_count() -> int:
	var total := 0
	for c in enemy_counts:
		total += c
	return total


func build_spawn_queue() -> Array[EnemyData]:
	var queue: Array[EnemyData] = []
	var n: int = mini(enemy_data_list.size(), enemy_counts.size())
	for i in range(n):
		for _j in range(enemy_counts[i]):
			queue.append(enemy_data_list[i])
	return queue
