extends Area2D

signal player_reached_goal

var activated: bool = true


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not activated:
		return

	if body.is_in_group("player"):
		player_reached_goal.emit()
