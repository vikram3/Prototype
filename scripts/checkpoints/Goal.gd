extends Area2D

signal player_reached_goal

var activated: bool = false
var triggered: bool = false


func _ready() -> void:

	body_entered.connect(_on_body_entered)

	monitoring = false


func activate() -> void:
	if activated:
		return

	activated = true
	triggered = false

	set_deferred("monitoring", true)




func deactivate() -> void:
	if not activated:
		return

	activated = false

	# IMPORTANT:
	# This can be called while body_entered is being processed.
	# Therefore monitoring must be changed deferred.
	set_deferred("monitoring", false)

	print("GOAL DEACTIVATED")


func _on_body_entered(body: Node2D) -> void:

	if not activated:
		return

	if triggered:
		return

	if not body.is_in_group("player"):
		return

	triggered = true



	player_reached_goal.emit()
