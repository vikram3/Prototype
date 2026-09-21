extends Area2D

signal player_reached_goal

var activated: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func activate() -> void:
	if activated:
		return

	activated = true
	monitoring = true

	print("Goal activated")


func _on_body_entered(body: Node2D) -> void:
	if not activated:
		return

	if not body.is_in_group("player"):
		return

	player_reached_goal.emit()
