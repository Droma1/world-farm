extends Node3D

@export var hero_path: NodePath = ^"Player"
@export var enemy_paths: Array[NodePath] = [^"EnemyLeft", ^"EnemyRight", ^"EnemyRear"]
@export var hero_walk_speed: float = 1.15
@export var enemy_walk_speed: float = 0.55

var _hero: Node3D
var _enemies: Array[Node3D] = []
var _time: float = 0.0


func _ready() -> void:
    _hero = get_node_or_null(hero_path) as Node3D
    if _hero:
        _prepare_showcase_actor(_hero)
        _clear_local_player_reference(_hero)

    for path in enemy_paths:
        var enemy := get_node_or_null(path) as Node3D
        if enemy:
            _prepare_showcase_actor(enemy)
            _enemies.append(enemy)

    GameState.local_player = null


func _process(delta: float) -> void:
    _time += delta

    if _hero:
        _hero.rotation.y = lerp_angle(_hero.rotation.y, deg_to_rad(-18.0) + sin(_time * 0.55) * 0.08, delta * 3.0)
        _pose_animator(_hero, Vector3(0.0, 0.0, -hero_walk_speed), true)

    for index in range(_enemies.size()):
        var enemy := _enemies[index]
        var phase := _time + float(index) * 1.9
        enemy.rotation.y = lerp_angle(enemy.rotation.y, deg_to_rad(155.0) + sin(phase * 0.8) * 0.12, delta * 2.0)
        _pose_animator(enemy, Vector3(0.0, 0.0, -enemy_walk_speed), true)


func _prepare_showcase_actor(actor: Node) -> void:
    actor.set_process(false)
    actor.set_physics_process(false)
    actor.set_process_input(false)
    actor.set_process_unhandled_input(false)

    if actor is CharacterBody3D:
        (actor as CharacterBody3D).velocity = Vector3.ZERO

    for child in actor.get_children():
        _prepare_showcase_child(child)


func _prepare_showcase_child(node: Node) -> void:
    if node is EnemyAI or node is MovementComponent or node is WeaponComponent:
        node.process_mode = Node.PROCESS_MODE_DISABLED
    elif node is CollisionShape3D:
        (node as CollisionShape3D).disabled = true
    elif node is NavigationAgent3D:
        (node as NavigationAgent3D).avoidance_enabled = false
    elif node is HumanoidAnimator:
        node.process_mode = Node.PROCESS_MODE_ALWAYS
        node.set_process(true)

    for child in node.get_children():
        _prepare_showcase_child(child)


func _pose_animator(actor: Node, local_velocity: Vector3, grounded: bool) -> void:
    var animator := actor.get_node_or_null("HumanoidAnimator") as HumanoidAnimator
    if animator == null:
        return
    animator.local_velocity = local_velocity
    animator.is_on_floor = grounded
    animator.is_crouching = false


func _clear_local_player_reference(actor: Node) -> void:
    if GameState.local_player == actor:
        GameState.local_player = null
