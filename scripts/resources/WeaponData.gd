class_name WeaponData
extends Resource
## Datos puros de un arma. NO contiene lógica — solo stats que el
## WeaponComponent leerá. Cambiar balance = cambiar el .tres.

enum FireMode { SEMI, AUTO, BURST }
enum DamageType { HITSCAN, PROJECTILE }

@export var id: StringName = &"weapon"
@export var display_name: String = "Weapon"

@export_group("Damage")
@export var damage: float = 25.0
@export var headshot_multiplier: float = 2.0
@export var damage_type: DamageType = DamageType.HITSCAN
@export var max_range: float = 100.0
@export var projectile_scene: PackedScene  # solo si PROJECTILE

@export_group("Fire")
@export var fire_mode: FireMode = FireMode.SEMI
@export var rounds_per_minute: float = 600.0
@export var spread_degrees: float = 1.5

@export_group("Ammo")
@export var mag_size: int = 12
@export var reserve_ammo: int = 60
@export var reload_time: float = 1.5

@export_group("Feel")
@export var recoil_kick: Vector2 = Vector2(0.4, 0.2)


func seconds_per_shot() -> float:
	return 60.0 / max(rounds_per_minute, 1.0)
