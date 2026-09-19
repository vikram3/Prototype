extends Area2D

@export var damage: int = 1

var players_inside: Array[Node2D] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	body_exited.connect(_on_body_exited)
	area_exited.connect(_on_area_exited)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	_damage_player(body)


func _on_area_entered(area: Area2D) -> void:
	if area.name != "DamageHitbox":
		return

	var player := area.get_parent()

	if not player.is_in_group("player"):
		return

	_damage_player(player)


func _damage_player(player: Node2D) -> void:
	if players_inside.has(player):
		return

	players_inside.append(player)

	if player.has_method("take_damage"):
		player.take_damage(damage)

	if player.has_method("apply_knockback"):
		player.apply_knockback(global_position)


func _on_body_exited(body: Node2D) -> void:
	players_inside.erase(body)


func _on_area_exited(area: Area2D) -> void:
	if area.name != "DamageHitbox":
		return

	var player := area.get_parent()

	if player.is_in_group("player"):
		players_inside.erase(player)
