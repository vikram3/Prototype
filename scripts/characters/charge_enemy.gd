class_name ChargeEnemy
extends PlatformerActor

enum State { IDLE, PATROL, DETECT, CHARGE_PREP, CHARGE, COLLISION, TURN, RECOVER, DISABLED, STORY }
@export var detection_range: float = 650.0
@export var vertical_detection_range: float = 220.0
@export var patrol_speed: float = 90.0
@export var charge_speed: float = 650.0
@export var charge_duration: float = 0.75
@export var warning_duration: float = 0.6
@export var recovery_duration: float = 0.8
@export var charge_cooldown: float = 1.5
@export var charge_knockback: float = 620.0
@export var turn_at_edges: bool = true

var state: State = State.PATROL
var state_timer: float = 0.0
var cooldown_timer: float = 0.0
var charge_direction: float = 1.0
var charge_has_hit: bool = false
var edge_ray: RayCast2D

func _ready() -> void:
	super._ready()
	edge_ray = RayCast2D.new()
	edge_ray.collision_mask = 2
	edge_ray.enabled = true
	edge_ray.position = Vector2(26.0, 0.0)
	edge_ray.target_position = Vector2(0.0, 48.0)
	add_child(edge_ray)
	if story_mode:
		state = State.STORY

func _physics_process(delta: float) -> void:
	_process_damage_timer(delta)
	if disabled:
		state = State.DISABLED
		apply_gravity(delta)
		move_and_slide()
		return
	if state == State.STORY:
		apply_gravity(delta)
		move_horizontal(0.0, delta)
		move_and_slide()
		return
	cooldown_timer = maxf(cooldown_timer - delta, 0.0)
	var player := find_player()
	apply_gravity(delta)
	match state:
		State.PATROL, State.IDLE:
			_patrol(player, delta)
		State.DETECT:
			begin_charge_prep(player)
		State.CHARGE_PREP:
			_charge_prep(delta)
		State.CHARGE:
			_charge(delta, player)
		State.COLLISION, State.TURN:
			_turn(delta)
		State.RECOVER:
			_recover(delta)
	move_and_slide()

func _patrol(player: Node2D, delta: float) -> void:
	if _can_detect(player) and cooldown_timer <= 0.0:
		state = State.DETECT
		return
	if turn_at_edges and is_on_floor() and _at_edge(facing):
		facing *= -1.0
	move_horizontal(facing * patrol_speed, delta)

func begin_charge_prep(player: Node2D) -> void:
	if player == null:
		state = State.PATROL
		return
	charge_direction = signf(player.global_position.x - global_position.x)
	if is_zero_approx(charge_direction):
		charge_direction = facing
	facing = charge_direction
	if sprite != null:
		sprite.flip_h = facing < 0.0
	state = State.CHARGE_PREP
	state_timer = warning_duration
	charge_has_hit = false
	say("Make room. The charge is coming.", true)

func _charge_prep(delta: float) -> void:
	move_horizontal(0.0, delta)
	state_timer -= delta
	if state_timer <= 0.0:
		state = State.CHARGE
		state_timer = charge_duration

func _charge(delta: float, player: Node2D) -> void:
	# Direction is locked at launch: a readable side-dodge, never homing.
	velocity.x = charge_direction * charge_speed
	state_timer -= delta
	# A swept hit window avoids a high-speed charge tunnelling past CT between frames.
	if not charge_has_hit and player != null and absf(player.global_position.x - global_position.x) < 115.0 and absf(player.global_position.y - global_position.y) < 155.0:
		charge_has_hit = true
		damage_player(player)
		if player.has_method("apply_knockback"):
			player.apply_knockback(global_position - Vector2(charge_direction * charge_knockback, 0.0))
	if is_on_wall() or state_timer <= 0.0:
		state = State.COLLISION
		state_timer = recovery_duration
		cooldown_timer = charge_cooldown
		if is_on_wall():
			say("You got lucky. I am turning around.")

func _turn(delta: float) -> void:
	move_horizontal(0.0, delta)
	state_timer -= delta
	if state_timer <= 0.0:
		facing = -charge_direction
		state = State.RECOVER
		state_timer = recovery_duration

func _recover(delta: float) -> void:
	move_horizontal(0.0, delta)
	state_timer -= delta
	if state_timer <= 0.0:
		state = State.PATROL

func _can_detect(player: Node2D) -> bool:
	return player != null and absf(player.global_position.x - global_position.x) <= detection_range and absf(player.global_position.y - global_position.y) <= vertical_detection_range

func _at_edge(direction: float) -> bool:
	if edge_ray == null:
		return false
	edge_ray.position.x = 26.0 * direction
	edge_ray.force_raycast_update()
	return not edge_ray.is_colliding()
