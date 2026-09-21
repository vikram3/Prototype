extends Area2D

signal player_reached_goal

var activated: bool = false
var triggered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	monitoring = false

	print("GOAL READY: ", name)


func activate() -> void:
	if activated:
		return

	activated = true
	triggered = false
	monitoring = true

	print("GOAL ACTIVATED")


func deactivate() -> void:
	activated = false
	monitoring = false


func _on_body_entered(body: Node2D) -> void:
	print("GOAL BODY ENTERED: ", body.name)

	if not activated:
		print("GOAL IGNORE: not activated")
		return

	if triggered:
		return

	if not body.is_in_group("player"):
		print("GOAL IGNORE: body is not player")
		return

	triggered = true

	print("GOAL REACHED BY PLAYER")

	player_reached_goal.emit()
