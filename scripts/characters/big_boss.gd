class_name BigBoss
extends PlatformerActor

enum State { IDLE, APPROACH, TELEGRAPH, SWORD_SLASH, GROUND_SLAM, RECOVER, STORY }
@export var detection_range: float = 700.0
@export var attack_range: float = 250.0
@export var telegraph_duration: float = 0.8
@export var attack_cooldown: float = 2.0
@export var shockwave_speed: float = 720.0
var state: State = State.IDLE
var timer: float = 0.0
var next_slam: bool = false

func _ready() -> void:
	super._ready()
	invulnerable = true # Chapter 2 is a survival encounter by default.
	if story_mode: state = State.STORY

func _physics_process(delta: float) -> void:
	_process_damage_timer(delta)
	apply_gravity(delta)
	if state == State.STORY:
		move_horizontal(0.0, delta)
		move_and_slide()
		return
	var player := find_player()
	if player == null:
		move_horizontal(0.0, delta)
		move_and_slide()
		return
	var dx := player.global_position.x - global_position.x
	facing = signf(dx) if not is_zero_approx(dx) else facing
	if sprite != null: sprite.flip_h = facing < 0.0
	if state == State.IDLE or state == State.APPROACH:
		if absf(dx) > attack_range:
			state = State.APPROACH
			move_horizontal(facing * walk_speed, delta)
		else:
			state = State.TELEGRAPH
			timer = telegraph_duration
			say("Move now. This is your warning.", true)
	elif state == State.TELEGRAPH:
		move_horizontal(0.0, delta)
		timer -= delta
		if timer <= 0.0:
			state = State.GROUND_SLAM if next_slam else State.SWORD_SLASH
			next_slam = not next_slam
			perform_attack(player)
			timer = 0.22
	elif state == State.SWORD_SLASH or state == State.GROUND_SLAM:
		timer -= delta
		if timer <= 0.0:
			state = State.RECOVER
			timer = attack_cooldown
	elif state == State.RECOVER:
		move_horizontal(0.0, delta)
		timer -= delta
		if timer <= 0.0: state = State.IDLE
	move_and_slide()

func perform_attack(player: Node2D) -> void:
	if state == State.SWORD_SLASH:
		if absf(player.global_position.x - global_position.x) < attack_range + 90.0:
			damage_player(player, 2)
		say("One sword swing ends this!", true)
	else:
		var wave := StoryProjectile.new()
		wave.owner_actor = self
		wave.speed = shockwave_speed
		wave.lifetime = 1.2
		wave.direction = Vector2(facing, 0.0)
		wave.global_position = global_position + Vector2(facing * 80.0, 0.0)
		wave.collision_layer = 16
		wave.collision_mask = 3
		wave.body_entered.connect(wave._on_body_entered)
		get_tree().current_scene.add_child(wave)
		say("Feel the ground break!", true)
