extends Area2D

var player: Node2D = null
var damage_timer: float = 0.0


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _physics_process(delta: float) -> void:
	if player == null:
		return

	damage_timer -= delta

	if damage_timer > 0.0:
		return

	_damage_player()


func _on_area_entered(area: Area2D) -> void:
	if area.name != "DamageHitbox":
		return

	var possible_player := area.get_parent()

	if not possible_player.is_in_group("player"):
		return

	player = possible_player

	# Damage immediately on first contact.
	damage_timer = 0.0
	_damage_player()


func _on_area_exited(area: Area2D) -> void:
	if area.name != "DamageHitbox":
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

	if player.has_method("take_damage"):
		player.take_damage(get_parent().contact_damage)

	if player.has_method("apply_knockback"):
		player.apply_knockback(global_position)

	if get_parent().has_method("damage_flash"):
		get_parent().damage_flash()

	# Prevent damage every physics frame.
	damage_timer = 0.7
