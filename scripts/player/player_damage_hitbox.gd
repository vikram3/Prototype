extends Area2D

@export var damage: int = 1

var hitboxes_inside: Array[Area2D] = []


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _on_area_entered(area: Area2D) -> void:
	if area.name != "DamageHitbox":
		return

	var player := area.get_parent()

	if not player.is_in_group("player"):
		return

	if hitboxes_inside.has(area):
		return

	hitboxes_inside.append(area)

	if player.has_method("take_damage"):
		player.take_damage(damage)

	if player.has_method("apply_knockback"):
		player.apply_knockback(global_position)


func _on_area_exited(area: Area2D) -> void:
	hitboxes_inside.erase(area)
