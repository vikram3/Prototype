extends Node
## CP02 platformer override.
## Attach as a child of the existing CT CharacterBody2D.
## It disables the old top-down physics loop and owns side-scroller movement.

@export_category("Movement")
@export var run_speed: float = 420.0
@export var acceleration: float = 2200.0
@export var deceleration: float = 2600.0
@export var jump_velocity: float = -780.0
@export var gravity_scale: float = 1.0
@export var max_fall_speed: float = 1500.0

@export_category("Jump Feel")
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12
@export var variable_jump_gravity: float = 1800.0

@export_category("Controls")
@export var left_action: StringName = &"move_left"
@export var right_action: StringName = &"move_right"
@export var jump_action: StringName = &"jump"

var player: CharacterBody2D
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0


func _ready() -> void:
	player = get_parent() as CharacterBody2D
	if player == null:
		push_error("CP02 PlatformerOverride must be a child of CharacterBody2D.")
		return

	# CP01 uses the old top-down _physics_process.
	# CP02 replaces only that loop; the existing health/story/dialogue API remains.
	player.set_physics_process(false)
	player.motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	player.up_direction = Vector2.UP


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	if "is_dead" in player and bool(player.is_dead):
		return

	# Keep the existing speech system alive.
	if player.has_method("_update_speech"):
		player._update_speech(delta)

	_update_jump_timers(delta)
	_apply_gravity(delta)
	_apply_horizontal(delta)
	_handle_jump()
	_apply_variable_jump(delta)

	player.move_and_slide()
	_face_direction()


func _update_jump_timers(delta: float) -> void:
	if player.is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)

	if Input.is_action_just_pressed(jump_action):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)


func _apply_gravity(delta: float) -> void:
	if not player.is_on_floor():
		player.velocity.y += player.get_gravity().y * gravity_scale * delta
		player.velocity.y = minf(player.velocity.y, max_fall_speed)
	else:
		if player.velocity.y > 0.0:
			player.velocity.y = 0.0


func _apply_horizontal(delta: float) -> void:
	var direction := Input.get_axis(left_action, right_action)

	if absf(direction) > 0.01:
		player.velocity.x = move_toward(
			player.velocity.x,
			direction * run_speed,
			acceleration * delta
		)
	else:
		player.velocity.x = move_toward(
			player.velocity.x,
			0.0,
			deceleration * delta
		)


func _handle_jump() -> void:
	if jump_buffer_timer <= 0.0:
		return

	if coyote_timer <= 0.0:
		return

	player.velocity.y = jump_velocity
	jump_buffer_timer = 0.0
	coyote_timer = 0.0


func _apply_variable_jump(delta: float) -> void:
	# Releasing jump early gives a shorter hop.
	if player.velocity.y < 0.0 and not Input.is_action_pressed(jump_action):
		player.velocity.y = minf(
			player.velocity.y + variable_jump_gravity * delta,
			0.0
		)


func _face_direction() -> void:
	if absf(player.velocity.x) < 5.0:
		return

	var sprite := player.get_node_or_null("Sprite2D")
	if sprite == null:
		return

	sprite.flip_h = player.velocity.x < 0.0
