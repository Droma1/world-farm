class_name Grenade
extends RigidBody3D
## Granada lanzada por el player. Vuela en arco, explota tras `fuse_time` o
## al primer impacto fuerte. Tipos: STANDARD (daño área), SMOKE (oculta LoS
## a enemigos durante duración), FLASH (stunea a enemigos en LoS).

enum GrenadeType { STANDARD, SMOKE, FLASH }

signal exploded(position: Vector3)

@export var grenade_type: GrenadeType = GrenadeType.STANDARD
@export var fuse_time: float = 1.8
@export var damage_radius: float = 4.5
@export var damage: float = 95.0
@export var impulse_radial: float = 6.0  ## fuerza de "blowback" (visual; aplicado a CB3D que tengan velocity)
@export_flags_3d_physics var damage_mask: int = 0xFFFFFFFF
@export var thrower: Node = null   ## quién lanzó (excluido del daño)
@export var smoke_duration: float = 5.0
@export var smoke_radius: float = 5.0
@export var flash_stun_duration: float = 2.0
@export var flash_radius: float = 8.0

var _t: float = 0.0
var _exploded: bool = false


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	_t += delta
	if _t >= fuse_time:
		_explode()


func _on_body_entered(body: Node) -> void:
	# Si rebota muy fuerte, dejamos que se siga moviendo. Solo explotamos al
	# tocar al player o un enemy directo (cuerpo dinámico). Para muros y
	# suelo simplemente se queda y espera el fuse.
	if _exploded:
		return
	if body is CharacterBody3D and body != thrower:
		_explode()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	var pos := global_position
	exploded.emit(pos)
	match grenade_type:
		GrenadeType.STANDARD:
			_apply_area_damage(pos)
			_spawn_explosion_vfx(pos)
		GrenadeType.SMOKE:
			_spawn_smoke_cloud(pos)
		GrenadeType.FLASH:
			_apply_flash_stun(pos)
			_spawn_flash_vfx(pos)
	queue_free()


func _spawn_smoke_cloud(pos: Vector3) -> void:
	var cloud := CPUParticles3D.new()
	cloud.emitting = true
	cloud.amount = 80
	cloud.lifetime = smoke_duration
	cloud.preprocess = 0.5
	cloud.direction = Vector3.UP
	cloud.spread = 90.0
	cloud.initial_velocity_min = 0.5
	cloud.initial_velocity_max = 1.2
	cloud.gravity = Vector3.ZERO
	cloud.scale_amount_min = 1.4
	cloud.scale_amount_max = 2.4
	cloud.color = Color(0.85, 0.85, 0.92, 0.85)
	var sm := SphereMesh.new()
	sm.radius = 0.6
	sm.height = 1.2
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.albedo_color = Color(0.9, 0.9, 0.95, 0.4)
	sm.material = smat
	cloud.mesh = sm
	get_tree().current_scene.add_child(cloud)
	cloud.global_position = pos + Vector3(0, 0.5, 0)
	# Notificar a EnemyAI que hay un smoke en `pos` con `smoke_radius` para
	# que EnemyAI bloquee LoS dentro del cloud (efecto: enemigos no nos ven).
	EventBus.smoke_deployed.emit(pos, smoke_radius, smoke_duration)
	get_tree().create_timer(smoke_duration + 0.5).timeout.connect(cloud.queue_free)


func _apply_flash_stun(pos: Vector3) -> void:
	# Los enemigos que tengan LoS al epicentro reciben stun (su EnemyAI tiene
	# stagger_t — emitimos signal y los AIs deciden si aplicar).
	EventBus.flashbang_exploded.emit(pos, flash_radius, flash_stun_duration)


func _spawn_flash_vfx(pos: Vector3) -> void:
	# Flash blanco pantalla completa via signal — el HUD lo dibuja.
	var light := OmniLight3D.new()
	light.light_color = Color(1, 1, 1, 1)
	light.light_energy = 14.0
	light.omni_range = flash_radius * 2.0
	get_tree().current_scene.add_child(light)
	light.global_position = pos
	var lt := create_tween()
	lt.tween_property(light, "light_energy", 0.0, 0.4).set_ease(Tween.EASE_OUT)
	lt.tween_callback(light.queue_free)


func _apply_area_damage(epicenter: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = damage_radius
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, epicenter)
	query.collision_mask = damage_mask
	var hits := space.intersect_shape(query, 32)
	for hit in hits:
		var collider: Object = hit.get("collider")
		if collider == thrower:
			continue
		var hp: HealthComponent = null
		if collider is Node:
			for child in (collider as Node).get_children():
				if child is HealthComponent:
					hp = child
					break
		if hp == null:
			continue
		var dist: float = epicenter.distance_to((collider as Node3D).global_position)
		var falloff: float = clampf(1.0 - dist / damage_radius, 0.1, 1.0)
		var dmg: float = damage * falloff
		hp.take_damage(dmg, thrower)
		EventBus.damage_dealt.emit(collider, dmg, thrower)


func _spawn_explosion_vfx(pos: Vector3) -> void:
	## Flash + omni light + particulas naranjas. Rapido y feo pero efectivo.
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25, 1.0)
	light.light_energy = 8.0
	light.omni_range = 8.0
	get_tree().current_scene.add_child(light)
	light.global_position = pos
	var lt := create_tween()
	lt.tween_property(light, "light_energy", 0.0, 0.35).set_ease(Tween.EASE_OUT)
	lt.tween_callback(light.queue_free)

	var p := CPUParticles3D.new()
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 60
	p.lifetime = 0.6
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 9.0
	p.gravity = Vector3(0, -6, 0)
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.45
	p.color = Color(1.0, 0.55, 0.20, 1.0)
	var sm := SphereMesh.new()
	sm.radius = 0.10
	sm.height = 0.20
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.emission_enabled = true
	smat.emission = Color(1.0, 0.55, 0.20, 1.0)
	smat.emission_energy_multiplier = 4.0
	sm.material = smat
	p.mesh = sm
	get_tree().current_scene.add_child(p)
	p.global_position = pos
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)

	# Audio: usar explosionCrunch del Kenney sci-fi pack si lo tenemos
	# (lo añadimos en una iteración previa). Sino fallback al shoot.
	AudioManager.play_3d(&"explosion", pos, 2.0, 0.04, 50.0)
