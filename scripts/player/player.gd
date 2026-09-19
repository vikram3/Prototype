extends CharacterBody2D

@export var move_speed: float = 220.0
@export var damage_cooldown: float = 0.7
@export var knockback_force: float = 520.0
@export var knockback_friction: float = 2200.0
@export var hit_stun_time: float = 0.12

var can_take_damage: bool = true
var knockback_velocity: Vector2 = Vector2.ZERO
var hit_stun_timer: float = 0.0


func _physics_process(delta: float) -> void:
	var input_vector := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	# Reduce knockback smoothly until it stops.
	knockback_velocity = knockback_velocity.move_toward(
		Vector2.ZERO,
		knockback_friction * delta
	)

	# Briefly disable player control after being hit.
	if hit_stun_timer > 0.0:
		hit_stun_timer -= delta
		velocity = knockback_velocity
	else:
		velocity = input_vector * move_speed + knockback_velocity

	if input_vector.x != 0:
		$Sprite2D.flip_h = input_vector.x < 0

	move_and_slide()


func take_damage(amount: int) -> void:
	if not can_take_damage:
		return

	can_take_damage = false

	print(
		"Player took %d damage."
		% amount
	)

	await get_tree().create_timer(damage_cooldown).timeout
	can_take_damage = true


func apply_knockback(source_position: Vector2) -> void:
	var direction: Vector2 = (
		global_position - source_position
	).normalized()

	knockback_velocity = direction * knockback_force
	hit_stun_timer = hit_stun_time
