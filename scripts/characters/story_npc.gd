class_name StoryPlatformerNPC
extends PlatformerActor

@export var dialogue_key: String = ""
@export var target_speed: float = 0.0

func _physics_process(delta: float) -> void:
	_process_damage_timer(delta)
	apply_gravity(delta)
	move_horizontal(0.0 if story_mode else target_speed, delta)
	move_and_slide()
	if not story_mode and speech_cooldown_timer <= 0.0:
		say_random(idle_lines)

func play_story_action(action: String) -> void:
	story_mode = true
	say(action, true)

func perform_showcase(_target: Node2D) -> void:
	say_random(idle_lines)
	if sprite != null:
		var tween := create_tween()
		tween.tween_property(sprite, "rotation", 0.08, 0.18)
		tween.tween_property(sprite, "rotation", -0.08, 0.18)
		tween.tween_property(sprite, "rotation", 0.0, 0.18)
