extends Area2D

# ============================================================
# ELITE SKULL DAMAGE AREA
# ============================================================
# Attach to:
# EliteSkull/DamageArea
#
# Detects:
# CT/DamageHitbox
#
# Collision setup expected:
# Enemy DamageArea -> detects Player DamageHitbox.
# ============================================================

@export var damage_interval: float = 0.7
@export var default_damage: int = 1
@export var player_hitbox_name: String = "DamageHitbox"

var player: Node2D = null
var damage_timer: float = 0.0


func _ready() -> void:
	monitorable = true
	monitoring = false

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	if not area_exited.is_connected(_on_area_exited):
		area_exited.connect(_on_area_exited)


func _physics_process(delta: float) -> void:
	if not monitoring:
		return

	if player == null:
		return

	if not is_instance_valid(player):
		player = null
		damage_timer = 0.0
		return

	damage_timer -= delta

	if damage_timer > 0.0:
		return

	_damage_player()


func _on_area_entered(area: Area2D) -> void:
	if not monitoring:
		return

	if area == null:
		return

	if area.name != player_hitbox_name:
		return

	var possible_player := area.get_parent()

	if possible_player == null:
		return

	if not possible_player.is_in_group("player"):
		return

	player = possible_player as Node2D
	damage_timer = 0.0

	_damage_player()


func _on_area_exited(area: Area2D) -> void:
	if area == null:
		return

	if area.name != player_hitbox_name:
		return

	if player == area.get_parent():
		player = null
		damage_timer = 0.0


func _damage_player() -> void:
	if player == null:
		return

	if not is_instance_valid(player):
		player = null
		return

	if player.has_method("is_hidden") and player.is_hidden():
		return

	var enemy := get_parent()

	if enemy == null or not is_instance_valid(enemy):
		player = null
		return

	var damage := default_damage

	var configured_damage = enemy.get("attack_damage")

	if configured_damage != null:
		damage = int(configured_damage)

	if player.has_method("take_damage"):
		player.take_damage(damage)

	if player.has_method("apply_knockback"):
		player.apply_knockback(enemy.global_position)

	if enemy.has_method("damage_flash"):
		enemy.damage_flash()

	# Tell EliteSkull that the attack connected, preventing
	# its direct fallback attack from applying a second hit.
	if enemy.has_method("register_damage_area_hit"):
		enemy.register_damage_area_hit()

	damage_timer = damage_interval
