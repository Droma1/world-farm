class_name ThrownKnife
extends RigidBody3D
## Cuchillo lanzado. Daño grande al primer impacto contra CharacterBody3D,
## se queda clavado o cae al suelo. Recogible (futuro) por proximidad.

@export var damage: float = 65.0
@export var lifetime: float = 8.0
@export_flags_3d_physics var damage_mask: int = 0xFFFFFFFF
var thrower: Node = null
var _impacted: bool = false
var _t: float = 0.0


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= lifetime:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if _impacted:
		return
	if body == thrower:
		return
	if body is CharacterBody3D:
		var hp: HealthComponent = null
		for child in body.get_children():
			if child is HealthComponent:
				hp = child
				break
		if hp:
			hp.take_damage(damage, thrower)
			EventBus.damage_dealt.emit(body, damage, thrower)
		EventBus.impact.emit(global_position, Vector3.UP, body)
		_impacted = true
		queue_free()
	else:
		# Pared/suelo: el cuchillo se queda quieto, "clavado".
		# Convertimos a estático para que no rebote infinito.
		freeze = true
		_t = lifetime - 1.5  # despawn en 1.5s tras clavarse
