class_name WindQueen
extends PlatformerActor

enum State { IDLE, GROUND, LEVITATE, FLY, POWER_UP, INTERCEPT, RESCUE, STORY_CONTROLLED }
@export var flight_speed: float = 320.0
@export var levitation_height: float = 80.0
var state: State = State.IDLE
var story_target: Vector2

func _physics_process(delta: float) -> void:
	_process_damage_timer(delta)
	if state == State.GROUND:
		apply_gravity(delta)
		move_and_slide()
		return
	if state == State.IDLE:
		apply_gravity(delta)
		move_and_slide()
		return
	var offset := story_target - global_position
	if offset.length() > 4.0:
		velocity = offset.normalized() * minf(flight_speed, offset.length() / maxf(delta, 0.01))
		if absf(velocity.x) > 1.0:
			facing = signf(velocity.x)
			if sprite != null: sprite.flip_h = facing < 0.0
	else:
		velocity = Vector2.ZERO
	move_and_slide()

func levitate() -> void:
	state = State.LEVITATE
	story_target = global_position + Vector2(0.0, -levitation_height)
	say("The wind answers when I call.", true)

func power_up() -> void:
	state = State.POWER_UP
	say("Stand down. This storm is not for you.", true)

func intercept(target: Vector2) -> void:
	state = State.INTERCEPT
	story_target = target
	say("I will not let the Bulls reach Alex.", true)

func rescue(target: Vector2) -> void:
	state = State.RESCUE
	story_target = target
	say("Guards, hold the ship. I will guide it down.", true)

func perform_showcase(_target: Node2D) -> void:
	levitate()
	await get_tree().create_timer(0.8).timeout
	power_up()
	await get_tree().create_timer(0.7).timeout
	rescue(global_position + Vector2(180.0, -45.0))
