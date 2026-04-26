class_name HUD
extends CanvasLayer
## HUD del Player local: crosshair + barra de vida + ammo + aviso de
## recarga + flash rojo al recibir daño. Se vincula al Player vía
## GameState.local_player y se rebinda automáticamente si cambia.

@onready var health_bar: ProgressBar = $Root/HealthPanel/HealthBar
@onready var health_label: Label = $Root/HealthPanel/HealthLabel
@onready var ammo_label: Label = $Root/AmmoPanel/AmmoLabel
@onready var reload_label: Label = $Root/AmmoPanel/ReloadLabel
@onready var damage_vignette: ColorRect = $Root/DamageVignette

var _player: Player
var _flash_tween: Tween


func _ready() -> void:
	reload_label.visible = false
	damage_vignette.modulate.a = 0.0
	GameState.local_player_changed.connect(_on_local_player_changed)
	if GameState.local_player is Player:
		_bind(GameState.local_player)


func _on_local_player_changed(player: Node) -> void:
	if player == null:
		_unbind()
	elif player is Player:
		_bind(player)


func _bind(player: Player) -> void:
	_unbind()
	_player = player
	if not is_instance_valid(_player):
		return

	if _player.health:
		_player.health.damaged.connect(_on_player_damaged)
		_player.health.healed.connect(_on_player_healed)
		_refresh_health()

	if _player.weapon:
		_player.weapon.ammo_changed.connect(_on_ammo_changed)
		_player.weapon.weapon_equipped.connect(_on_weapon_equipped)
		_player.weapon.reload_started.connect(_on_reload_started)
		_player.weapon.reload_finished.connect(_on_reload_finished)
		if _player.weapon.current:
			_on_ammo_changed(_player.weapon.in_mag, _player.weapon.reserve)


func _unbind() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = null
		return
	if _player.health:
		if _player.health.damaged.is_connected(_on_player_damaged):
			_player.health.damaged.disconnect(_on_player_damaged)
		if _player.health.healed.is_connected(_on_player_healed):
			_player.health.healed.disconnect(_on_player_healed)
	if _player.weapon:
		if _player.weapon.ammo_changed.is_connected(_on_ammo_changed):
			_player.weapon.ammo_changed.disconnect(_on_ammo_changed)
		if _player.weapon.weapon_equipped.is_connected(_on_weapon_equipped):
			_player.weapon.weapon_equipped.disconnect(_on_weapon_equipped)
		if _player.weapon.reload_started.is_connected(_on_reload_started):
			_player.weapon.reload_started.disconnect(_on_reload_started)
		if _player.weapon.reload_finished.is_connected(_on_reload_finished):
			_player.weapon.reload_finished.disconnect(_on_reload_finished)
	_player = null
	reload_label.visible = false


# --- Health ---

func _refresh_health() -> void:
	if _player == null or _player.health == null:
		return
	var hp := _player.health.current_health
	var max_hp := _player.health.max_health
	health_bar.max_value = max_hp
	health_bar.value = hp
	health_label.text = "HP  %d / %d" % [int(hp), int(max_hp)]


func _on_player_damaged(_amount: float, _source: Node) -> void:
	_refresh_health()
	_flash_damage()


func _on_player_healed(_amount: float) -> void:
	_refresh_health()


func _flash_damage() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	damage_vignette.modulate.a = 0.45
	_flash_tween = create_tween()
	_flash_tween.tween_property(damage_vignette, "modulate:a", 0.0, 0.45)


# --- Weapon ---

func _on_weapon_equipped(_data: WeaponData) -> void:
	if _player and _player.weapon:
		_on_ammo_changed(_player.weapon.in_mag, _player.weapon.reserve)


func _on_ammo_changed(in_mag: int, reserve: int) -> void:
	ammo_label.text = "%d / %d" % [in_mag, reserve]


func _on_reload_started() -> void:
	reload_label.visible = true


func _on_reload_finished() -> void:
	reload_label.visible = false
