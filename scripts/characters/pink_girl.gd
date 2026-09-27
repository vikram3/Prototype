class_name PinkGirl
extends StoryPlatformerNPC

enum State { IDLE, APPROACH, DEFEND, ATTACK, BLOCK, HIT, RECOVER, KO }
@export var duel_range: float = 150.0
@export var attack_interval: float = 1.0
var state: State = State.IDLE
var action_timer: float = 0.0
var opponent: Node2D

func _physics_process(delta: float) -> void:
	_process_damage_timer(delta)
	apply_gravity(delta)
	if state == State.KO:
		move_horizontal(0.0, delta); move_and_slide(); return
	if opponent == null or not is_instance_valid(opponent):
		var candidate := get_tree().get_first_node_in_group("enemy")
		opponent = candidate as Node2D if candidate is Node2D and candidate.name == "BigBoss" else null
	if opponent != null and not story_mode:
		var dx := opponent.global_position.x - global_position.x
		facing = signf(dx) if not is_zero_approx(dx) else facing
		if sprite != null: sprite.flip_h = facing < 0.0
		if absf(dx) > duel_range:
			state = State.APPROACH
			move_horizontal(facing * walk_speed, delta)
		else:
			action_timer -= delta
			if action_timer <= 0.0:
				state = State.BLOCK if state == State.ATTACK else State.ATTACK
				action_timer = attack_interval
				say("Not while I am standing here." if state == State.BLOCK else "Back away from CT!", true)
				if state == State.ATTACK and opponent.has_method("take_damage"):
					opponent.take_damage(1, global_position)
	else:
		move_horizontal(0.0, delta)
	move_and_slide()

func take_damage(amount: int = 1, source_position: Vector2 = Vector2.ZERO) -> void:
	if state == State.BLOCK: return
	state = State.HIT
	super.take_damage(amount, source_position)
	if health <= 0: state = State.KO
