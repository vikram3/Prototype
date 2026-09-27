class_name PlatformerCompanion
extends PlatformerActor

@export var follow_distance: float = 120.0
@export var catch_up_distance: float = 480.0
@export var catch_up_speed: float = 330.0
@export var comment_interval: float = 12.0
@export var dialogue_lines: PackedStringArray = []
var comment_timer: float = 0.0

func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	_process_damage_timer(delta)
	if story_mode:
		move_horizontal(0.0, delta); move_and_slide(); return
	var player := find_player()
	if player == null:
		move_horizontal(0.0, delta); move_and_slide(); return
	var dx := player.global_position.x - global_position.x
	var desired := 0.0
	if absf(dx) > follow_distance:
		desired = signf(dx) * (catch_up_speed if absf(dx) > catch_up_distance else walk_speed)
	move_horizontal(desired, delta)
	# Companion collision never pushes CT around.
	set_collision_mask_value(1, false)
	comment_timer -= delta
	if comment_timer <= 0.0 and not dialogue_lines.is_empty():
		comment_timer = comment_interval
		say_random(dialogue_lines)
	move_and_slide()
