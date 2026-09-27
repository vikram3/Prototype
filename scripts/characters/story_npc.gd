class_name StoryPlatformerNPC
extends PlatformerActor

@export var dialogue_key: String = ""
@export var target_speed: float = 0.0

func _physics_process(delta: float) -> void:
	_process_damage_timer(delta)
	apply_gravity(delta)
	move_horizontal(0.0 if story_mode else target_speed, delta)
	move_and_slide()

func play_story_action(action: String) -> void:
	story_mode = true
	say(action, true)
