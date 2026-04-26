extends Node
## RNG con seed por partida. Usar este autoload en vez de randi()/randf()
## para cualquier cosa que afecte balance, replays o netcode.

var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()


func set_seed(value: int) -> void:
	rng.seed = value


func randf() -> float:
	return rng.randf()


func randf_range(from: float, to: float) -> float:
	return rng.randf_range(from, to)


func randi_range(from: int, to: int) -> int:
	return rng.randi_range(from, to)
