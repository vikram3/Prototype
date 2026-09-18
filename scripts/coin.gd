extends Area2D

signal collected(value: int)

@export var value: int = 1

var is_collected: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if is_collected:
		return

	if body.is_in_group("player"):
		collect()


func collect() -> void:
	if is_collected:
		return

	is_collected = true

	collected.emit(value)

	queue_free()
