extends Area2D

signal player_reached_goal

var activated: bool = false
var triggered: bool = false


func _ready() -> void:
	print("========================================")
	print("GOAL READY")
	print("Name: ", name)
	print("Collision Layer: ", collision_layer)
	print("Collision Mask: ", collision_mask)
	print("Monitoring: ", monitoring)
	print("Monitorable: ", monitorable)
	print("Collision Shape Count: ", get_children().size())
	print("========================================")

	body_entered.connect(_on_body_entered)

	monitoring = false


func activate() -> void:
	if activated:
		print("GOAL ACTIVATE IGNORED: already active")
		return

	activated = true
	triggered = false

	set_deferred("monitoring", true)

	print("========================================")
	print("GOAL ACTIVATED")
	print("Monitoring: ", monitoring)
	print("Collision Mask: ", collision_mask)
	print("========================================")


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
	print("========================================")
	print("GOAL BODY ENTERED")
	print("Body: ", body.name)
	print("Body Type: ", body.get_class())
	print("Body Collision Layer: ", body.collision_layer)
	print("Body Collision Mask: ", body.collision_mask)
	print("Is Player Group: ", body.is_in_group("player"))
	print("Goal Activated: ", activated)
	print("Goal Monitoring: ", monitoring)
	print("========================================")

	if not activated:
		print("GOAL REJECTED: Goal is not activated")
		return

	if triggered:
		print("GOAL REJECTED: Already triggered")
		return

	if not body.is_in_group("player"):
		print("GOAL REJECTED: Body is not in player group")
		return

	triggered = true

	print("========================================")
	print("GOAL REACHED BY PLAYER")
	print("Emitting player_reached_goal")
	print("========================================")

	player_reached_goal.emit()
