extends CharacterBody2D

@export var move_speed := 220.0

@export var max_health: int = 3
@export var death_delay: float = 0.6

var health: int = max_health
var is_dead: bool = false

@export var damage_cooldown := 0.7
@export var knockback_force := 520.0
@export var knockback_friction := 2200.0
@export var hit_stun_time := 0.12

var can_take_damage := true
var knockback_velocity: Vector2 = Vector2.ZERO
var hit_stun_timer: float = 0.0
var is_flashing: bool = false

var hit_stop_time: float = 0.05


# ============================================================
# STEALTH / HIDING
# ============================================================

var is_player_hidden: bool = false
var current_hiding_spot: Node = null


func enter_hiding(hiding_spot: Node) -> void:

	if current_hiding_spot != null and current_hiding_spot != hiding_spot:
		return

	current_hiding_spot = hiding_spot
	is_player_hidden = true

	$DamageHitbox.set_deferred("monitorable", false)

	print("CT entered hiding")


func exit_hiding(hiding_spot: Node) -> void:

	if current_hiding_spot != hiding_spot:
		return

	current_hiding_spot = null
	is_player_hidden = false

	$DamageHitbox.set_deferred("monitorable", true)

	print("CT left hiding")


func is_hidden() -> bool:
	return is_player_hidden


# ============================================================
# MOVEMENT
# ============================================================

func _physics_process(delta: float) -> void:

	var input_vector := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	# Knockback friction.
	knockback_velocity = knockback_velocity.move_toward(
		Vector2.ZERO,
		knockback_friction * delta
	)

	# Hit stun.
	if hit_stun_timer > 0.0:
		hit_stun_timer -= delta
		velocity = knockback_velocity

	else:
		velocity = input_vector * move_speed + knockback_velocity

	# Sprite direction.
	if input_vector.x != 0:
		$Sprite2D.flip_h = input_vector.x < 0

	move_and_slide()


# ============================================================
# DAMAGE
# ============================================================

func take_damage(amount: int) -> void:
	if is_dead:
		return

	if not can_take_damage:
		return

	if is_player_hidden:
		return

	can_take_damage = false

	health -= amount

	print("CT took damage: ", amount)
	print("CT health: ", health, "/", max_health)

	damage_flash()

	# Hit stop.
	Engine.time_scale = 0.0

	await get_tree().create_timer(
		hit_stop_time,
		true,
		false,
		true
	).timeout

	Engine.time_scale = 1.0

	if health <= 0:
		die()
		return

	await get_tree().create_timer(
		damage_cooldown
	).timeout

	if not is_dead:
		can_take_damage = true

func die() -> void:
	if is_dead:
		return

	is_dead = true
	can_take_damage = false

	Engine.time_scale = 1.0

	print("CT died.")

	# Stop the player immediately.
	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	hit_stun_timer = 0.0

	$DamageHitbox.set_deferred("monitorable", false)

	await get_tree().create_timer(
		death_delay,
		true,
		false,
		true
	).timeout

	CheckpointManager.restart_checkpoint()

func damage_flash() -> void:

	if is_flashing:
		return

	is_flashing = true

	var original_modulate := modulate

	modulate = Color(1.0, 0.35, 0.35, 1.0)

	await get_tree().create_timer(0.1).timeout

	modulate = original_modulate

	is_flashing = false


func apply_knockback(source_position: Vector2) -> void:
	var offset := global_position - source_position

	if offset.length_squared() < 0.001:
		return

	var direction := offset.normalized()

	knockback_velocity = direction * knockback_force
	hit_stun_timer = hit_stun_time
