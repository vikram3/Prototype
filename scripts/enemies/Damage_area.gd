extends Area2D


var player: Node2D = null


func _ready() -> void:

	area_entered.connect(
		_on_area_entered
	)

	area_exited.connect(
		_on_area_exited
	)


func _on_area_entered(area: Area2D) -> void:

	if area.name != "DamageHitbox":
		return


	var possible_player := area.get_parent()


	if not possible_player.is_in_group("player"):
		return


	player = possible_player


	# Hidden players cannot be damaged.
	if player.has_method("is_hidden"):

		if player.is_hidden():
			return


	if player.has_method("take_damage"):

		player.take_damage(
			get_parent().contact_damage
		)


	if player.has_method("apply_knockback"):

		player.apply_knockback(
			global_position
		)


	if get_parent().has_method("damage_flash"):

		get_parent().damage_flash()


func _on_area_exited(area: Area2D) -> void:

	if area.name != "DamageHitbox":
		return

	if player == area.get_parent():
		player = null
