class_name TargetDummy
extends StaticBody3D
## Maniquí estático para probar el sistema de disparo y daño.
## Recibe daño vía HealthComponent y se elimina al morir.

@onready var health: HealthComponent = $HealthComponent
@onready var mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)


func _on_damaged(amount: float, _source: Node) -> void:
	print("[Dummy] -%.0f HP (queda %.0f)" % [amount, health.current_health])
	# Feedback visual mínimo: parpadeo rojo
	if mesh and mesh.material_override is StandardMaterial3D:
		var mat := (mesh.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		var original := mat.albedo_color
		mat.albedo_color = Color(1, 1, 1)
		mesh.material_override = mat
		await get_tree().create_timer(0.05).timeout
		if is_instance_valid(self) and mesh:
			mat.albedo_color = original
			mesh.material_override = mat


func _on_died() -> void:
	print("[Dummy] destruido")
	queue_free()
