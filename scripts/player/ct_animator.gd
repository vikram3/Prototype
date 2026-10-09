extends AnimatedSprite2D
## Drives the CT character animations from her body's motion.
## Attach to the AnimatedSprite2D inside CT_Character.tscn.
## The sprite is aligned with its feet at the origin (see CT_Character.tscn).

@export var body: CharacterBody2D
@export var walk_threshold: float = 5.0
@export var run_threshold: float = 300.0
## Where the head (eye point) sits inside each frame and the frame width.
## Flipping must mirror the offset too, or the art slides away from the collision.
@export var eye_x: float = 340.0
@export var canvas_w: float = 861.0
@export var feet_offset_y: float = -630.0

var _locked: bool = false


func _ready() -> void:
	if body == null:
		body = get_parent() as CharacterBody2D
	animation_finished.connect(_on_animation_finished)
	_apply_offset()
	play("idle")


func _process(_delta: float) -> void:
	if body == null:
		return

	if body.velocity.x != 0.0 and flip_h != (body.velocity.x < 0.0):
		flip_h = body.velocity.x < 0.0
		_apply_offset()

	if _locked:
		return

	var speed := absf(body.velocity.x)
	var airborne := not body.is_on_floor()

	if airborne:
		var next := "run_jump" if speed > walk_threshold else "Jump"
		_set_anim(next)
	elif speed > run_threshold:
		_set_anim("run")
	elif speed > walk_threshold:
		_set_anim("walk")
	else:
		_set_anim("idle")


## Plays a one-shot action (attack_1, combo_attack, hurt, death, ...) and
## holds it until it finishes. Movement animations resume afterwards.
func play_action(action_name: StringName) -> void:
	if sprite_frames == null or not sprite_frames.has_animation(action_name):
		return
	_locked = true
	play(action_name)


func _apply_offset() -> void:
	# Unflipped: the eye sits at the origin. Flipped: the mirrored eye sits at the origin.
	var x := (eye_x - canvas_w) if flip_h else -eye_x
	offset = Vector2(x, feet_offset_y)


func _set_anim(next: StringName) -> void:
	if animation != next:
		play(next)


func _on_animation_finished() -> void:
	var one_shot := sprite_frames != null and not sprite_frames.get_animation_loop(animation)
	if _locked and one_shot:
		_locked = false
