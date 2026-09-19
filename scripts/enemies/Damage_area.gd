extends Area2D

@export var damage: int = 1

var players_inside: Array[Node2D] = []


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _on_area_entered(area: Area2D) -> void:
	print("Skull detected area: ", area.name)

	if area.name != "DamageHitbox":
		return

	var player := area.get_parent()

	if not player.is_in_group("player"):
		return

	if players_inside.has(player):
		return

	players_inside.append(player)

	if player.has_method("take_damage"):
		player.take_damage(damage)

	if player.has_method("apply_knockback"):
		player.apply_knockback(global_position)

	if owner.has_method("damage_flash"):
		owner.damage_flash()

func _on_area_exited(area: Area2D) -> void:
	if area.name != "DamageHitbox":
		return

	var player := area.get_parent()

	if player.is_in_group("player"):
		players_inside.erase(player)
