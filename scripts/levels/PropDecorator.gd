class_name PropDecorator
extends Node3D
## Auto-coloca props CC0 (Kenney Factory + Space kits) alrededor del mapa
## para que la arena no se sienta vacía. Se ejecuta una vez al cargar y
## añade los props como hijos de este nodo.
##
## Distribución: poisson-disk-like usando RNG.randf con rechazo cuando hay
## otro prop demasiado cerca, dentro de un radio configurado.

@export var spawn_radius: float = 35.0       ## radio alrededor del origen donde se siembran props
@export var inner_exclusion: float = 4.0     ## círculo central libre (zona de spawn del player)
@export var min_prop_separation: float = 3.5 ## distancia mínima entre props
@export var prop_count: int = 24             ## cuántos intentar colocar
@export var max_attempts_per_prop: int = 12
@export var random_seed: int = 1337          ## reproducible entre runs (cambia para variar layout)

# Pool de props (path → escala_min, escala_max). Mezclamos cajas (cobertura),
# barriles/maquinaria (silueta), y algún catwalk corto.
const PROP_POOL: Array[Dictionary] = [
	{"path": "res://assets/models/props/factory/box-large.glb", "scale_min": 1.0, "scale_max": 1.4},
	{"path": "res://assets/models/props/factory/box-wide.glb", "scale_min": 1.0, "scale_max": 1.3},
	{"path": "res://assets/models/props/factory/box-long.glb", "scale_min": 1.0, "scale_max": 1.2},
	{"path": "res://assets/models/props/factory/box-small.glb", "scale_min": 1.0, "scale_max": 1.5},
	{"path": "res://assets/models/props/factory/cog-a.glb", "scale_min": 1.5, "scale_max": 2.4},
	{"path": "res://assets/models/props/factory/cog-c.glb", "scale_min": 1.2, "scale_max": 1.8},
	{"path": "res://assets/models/props/factory/hopper-square.glb", "scale_min": 1.0, "scale_max": 1.4},
	{"path": "res://assets/models/props/factory/hopper-round.glb", "scale_min": 1.0, "scale_max": 1.4},
	{"path": "res://assets/models/props/factory/machine.glb", "scale_min": 1.0, "scale_max": 1.5},
	{"path": "res://assets/models/props/factory/machine-bed.glb", "scale_min": 1.0, "scale_max": 1.3},
	{"path": "res://assets/models/props/factory/machine-fortified.glb", "scale_min": 1.0, "scale_max": 1.3},
	{"path": "res://assets/models/props/factory/cone.glb", "scale_min": 1.5, "scale_max": 2.5},
	{"path": "res://assets/models/props/factory/door.glb", "scale_min": 1.5, "scale_max": 2.0},
]

@export var add_static_collision: bool = true  ## envuelve cada prop con un StaticBody3D para que sirva de cover
@export var add_to_navmesh_group: bool = true  ## los props bloquean al navmesh


func _ready() -> void:
	if PROP_POOL.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var placed: Array[Vector2] = []
	var origin := global_position
	for _i in range(prop_count):
		var pos := _try_find_position(rng, placed)
		if pos == Vector2.INF:
			continue
		placed.append(pos)
		_spawn_prop(rng, Vector3(pos.x, 0, pos.y) + Vector3(origin.x, 0, origin.z))


func _try_find_position(rng: RandomNumberGenerator, placed: Array[Vector2]) -> Vector2:
	for _attempt in range(max_attempts_per_prop):
		var angle := rng.randf() * TAU
		var dist := lerpf(inner_exclusion, spawn_radius, sqrt(rng.randf()))
		var p := Vector2(cos(angle), sin(angle)) * dist
		var ok := true
		for q in placed:
			if p.distance_to(q) < min_prop_separation:
				ok = false
				break
		if ok:
			return p
	return Vector2.INF


func _spawn_prop(rng: RandomNumberGenerator, world_pos: Vector3) -> void:
	var pick: Dictionary = PROP_POOL[rng.randi_range(0, PROP_POOL.size() - 1)]
	var scene := load(pick["path"]) as PackedScene
	if scene == null:
		push_warning("PropDecorator: no pude cargar %s" % pick["path"])
		return
	var inst := scene.instantiate() as Node3D
	if inst == null:
		return
	var s: float = lerpf(pick["scale_min"], pick["scale_max"], rng.randf())
	inst.scale = Vector3(s, s, s)
	inst.rotation.y = rng.randf() * TAU
	add_child(inst)
	inst.global_position = world_pos

	if add_static_collision:
		# Wrap en StaticBody3D con CollisionShape3D box aproximada al AABB.
		var aabb := _calc_visual_aabb(inst)
		if aabb.size.length_squared() > 0.001:
			var sb := StaticBody3D.new()
			var col := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = aabb.size
			col.shape = box
			col.position = aabb.position + aabb.size * 0.5
			sb.add_child(col)
			inst.add_child(sb)
			if add_to_navmesh_group:
				sb.add_to_group(&"navmesh")


func _calc_visual_aabb(node: Node) -> AABB:
	var aabb := AABB()
	var first := true
	for child in node.get_children():
		var sub := _calc_visual_aabb(child)
		if sub.size.length_squared() > 0.001:
			if first:
				aabb = sub
				first = false
			else:
				aabb = aabb.merge(sub)
	if node is MeshInstance3D:
		var m := (node as MeshInstance3D).get_aabb()
		if first:
			return m
		return aabb.merge(m)
	return aabb
