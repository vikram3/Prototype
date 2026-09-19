class_name Enemy
extends CharacterBody2D

@export var move_speed: float = 80.0
@export var contact_damage: int = 1

var can_damage: bool = true


func _physics_process(_delta: float) -> void:
	move_and_slide()


func take_damage(amount: int) -> void:
	print(
		"%s took %d damage."
		% [name, amount]
	)


func deal_contact_damage() -> int:
	if not can_damage:
		return 0

	can_damage = false
	return contact_damage
