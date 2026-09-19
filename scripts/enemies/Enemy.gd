class_name Enemy
extends CharacterBody2D

@export var move_speed: float = 80.0
@export var contact_damage: int = 1

var can_damage: bool = true
var is_flashing: bool = false


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

func damage_flash() -> void:
	if is_flashing:
		return

	is_flashing = true

	var sprite := $Sprite2D

	sprite.modulate = Color(1.0, 0.3, 0.3)

	await get_tree().create_timer(0.1).timeout

	sprite.modulate = Color.WHITE

	is_flashing = false
