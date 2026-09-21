class_name HidingObject
extends StaticBody2D


signal player_entered(player)
signal player_exited(player)


@onready var hiding_area: Area2D = $HidingArea


func _ready() -> void:

	hiding_area.body_entered.connect(
		_on_body_entered
	)

	hiding_area.body_exited.connect(
		_on_body_exited
	)


func _on_body_entered(body: Node2D) -> void:

	if not body.is_in_group("player"):
		return

	if body.has_method("enter_hiding"):
		body.enter_hiding(self)

	player_entered.emit(body)


func _on_body_exited(body: Node2D) -> void:

	if not body.is_in_group("player"):
		return

	if body.has_method("exit_hiding"):
		body.exit_hiding(self)

	player_exited.emit(body)
