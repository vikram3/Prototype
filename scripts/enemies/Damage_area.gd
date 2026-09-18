extends Area2D

@export var damage: int = 1

var bodies_inside: Array[Node2D] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	if not bodies_inside.has(body):
		bodies_inside.append(body)

		if body.has_method("take_damage"):
			body.take_damage(damage)


func _on_body_exited(body: Node2D) -> void:
	bodies_inside.erase(body)
