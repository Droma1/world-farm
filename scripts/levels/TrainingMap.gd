extends Node3D
## Script del nivel de entrenamiento. Su única responsabilidad es bakear
## el navmesh al cargar la escena: añade todos los StaticBody3D al grupo
## "navmesh" y dispara el bake del NavigationRegion3D.
##
## Nota: el NavigationMesh debe tener
##   - geometry_parsed_geometry_type = STATIC_COLLIDERS (1)
##   - geometry_source_geometry_mode = GROUPS_WITH_CHILDREN (1)
##   - geometry_source_group_name = "navmesh"

@export var nav_region_path: NodePath = ^"NavigationRegion3D"
@export var bake_on_thread: bool = true

var _nav_region: NavigationRegion3D


func _ready() -> void:
	# Reset al cargar (también después de un retry tras game over).
	GameState.mode = GameState.Mode.PLAYING

	_nav_region = get_node_or_null(nav_region_path) as NavigationRegion3D
	if _nav_region == null:
		push_warning("TrainingMap: NavigationRegion3D no encontrado en %s" % nav_region_path)
		return

	_collect_static_bodies(self)
	_nav_region.bake_finished.connect(_on_bake_finished, CONNECT_ONE_SHOT)
	_nav_region.bake_navigation_mesh(bake_on_thread)


func _collect_static_bodies(node: Node) -> void:
	if node is StaticBody3D:
		node.add_to_group(&"navmesh")
	for child in node.get_children():
		_collect_static_bodies(child)


func _on_bake_finished() -> void:
	print("[TrainingMap] navmesh bakeado")
