extends Area2D

signal collected(value: int)

@export var value: int = 1

var is_collected: bool = false


func _ready() -> void:
	print("========================================")
	print("COIN READY")
	print("Name: ", name)
	print("Value: ", value)
	print("Groups: ", get_groups())
	print("Collision Layer: ", collision_layer)
	print("Collision Mask: ", collision_mask)
	print("Monitoring: ", monitoring)
	print("Monitorable: ", monitorable)
	print("========================================")

	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	print("========================================")
	print("COIN BODY ENTERED")
	print("Coin: ", name)
	print("Body: ", body.name)
	print("Is Player: ", body.is_in_group("player"))
	print("========================================")

	if is_collected:
		print("COIN IGNORED: Already collected")
		return

	if not body.is_in_group("player"):
		print("COIN IGNORED: Body is not player")
		return

	collect()


func collect() -> void:
	if is_collected:
		return

	is_collected = true

	print("========================================")
	print("COIN COLLECTED")
	print("Coin: ", name)
	print("Value: ", value)
	print("Emitting collected signal")
	print("========================================")

	collected.emit(value)

	queue_free()
