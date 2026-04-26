extends Node3D

func _ready() -> void:
    var player = get_node_or_null("Player")
    if player:
        # Disable physics mode recursively to keep the capybara still
        _disable_physics_recursively(player)

func _process(delta: float) -> void:
    # Rotate slowly for a nice showcase 
    rotate_y(delta * -0.2)

func _disable_physics_recursively(node: Node) -> void:
    node.set_physics_process(false)
    for child in node.get_children():
        _disable_physics_recursively(child)
