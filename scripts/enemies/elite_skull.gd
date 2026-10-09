class_name EliteSkull
extends CharacterBody2D

# ============================================================
# ELITE SKULL - platformer enemy (rewritten from scratch)
# ============================================================
# Scene: scenes/enemies/EliteSkull.tscn
#   EliteSkull (CharacterBody2D, this script)
#   ├── Sprite2D
#   ├── CollisionShape2D   body, feet at the origin
#   ├── SpeechLabel        optional
#   ├── EdgeRayLeft        floor check at the left foot
#   ├── EdgeRayRight       floor check at the right foot
#   └── DetectionRay       line of sight to CT
#
# Behaviour:
#   PATROL    walk, turn at ledges and walls
#   CHASE     run at CT along the floor, stop at gaps
#   CHARGE    short wind-up, then ATTACK
#   ATTACK    hit CT once if close enough
#   RETREAT   back off, then REENGAGE
#   SEARCH    walk to where CT was last seen, then PATROL
# ============================================================


@export_category("Movement")
@export var patrol_speed: float = 150.0
@export var chase_speed: float = 300.0
@export var retreat_speed: float = 300.0
@export var search_speed: float = 150.0
@export var acceleration: float = 1400.0
@export var deceleration: float = 1800.0
@export var gravity: float = 1800.0
@export var max_fall_speed: float = 1000.0

@export_category("Platform Edge")
@export var turn_at_edge: bool = true
@export var edge_check_start_height: float = 4.0
@export var edge_turn_cooldown: float = 0.18
@export var edge_blocked_give_up: float = 0.6

@export_category("Detection")
@export var detection_distance: float = 500.0
@export var detection_vertical_range: float = 180.0
@export var close_detection_distance: float = 90.0
@export var detection_behind_distance: float = 25.0
@export var lose_target_delay: float = 1.25
@export var require_line_of_sight: bool = true
@export_flags_2d_physics var detection_collision_mask: int = 2
@export var detection_debug: bool = false

@export_category("Combat")
@export var max_health: int = 3
@export var attack_damage: int = 1
@export var attack_distance: float = 105.0
@export var attack_hit_distance: float = 135.0
@export var charge_duration: float = 0.25
@export var attack_duration: float = 0.25
@export var retreat_duration: float = 0.4
@export var retreat_distance: float = 180.0
@export var reengage_delay: float = 0.3

@export_category("Damage")
@export var hit_stun_duration: float = 0.12
@export var damage_cooldown: float = 0.2
@export var knockback_strength: float = 260.0
@export var knockback_vertical: float = 100.0

@export_category("Search")
@export var search_duration: float = 4.0

@export_category("Speech")
@export var enemy_speech_enabled: bool = true
@export var speech_duration: float = 1.2


enum State {
	PATROL,
	CHASE,
	CHARGE,
	ATTACK,
	RETREAT,
	REENGAGE,
	SEARCH
}

var state: State = State.PATROL
var direction: float = 1.0
var health: int = 0
var dead: bool = false

var player: Node2D = null
var last_seen_position: Vector2 = Vector2.ZERO
var attack_has_hit: bool = false

var state_timer: float = 0.0
var lost_target_timer: float = 0.0
var edge_turn_timer: float = 0.0
var edge_blocked_timer: float = 0.0
var hit_stun_timer: float = 0.0
var damage_timer: float = 0.0
var speech_timer: float = 0.0

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var speech_label: Label = get_node_or_null("SpeechLabel")
@onready var edge_ray_left: RayCast2D = get_node_or_null("EdgeRayLeft")
@onready var edge_ray_right: RayCast2D = get_node_or_null("EdgeRayRight")
@onready var detection_ray: RayCast2D = get_node_or_null("DetectionRay")


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	health = max_health

	if sprite != null:
		direction = -1.0 if sprite.flip_h else 1.0

	for ray in [edge_ray_left, edge_ray_right]:
		if ray != null:
			ray.position.y = -edge_check_start_height
			ray.enabled = true

	if detection_ray != null:
		detection_ray.enabled = true
		detection_ray.collision_mask = detection_collision_mask

	if speech_label != null:
		speech_label.visible = false

	_update_facing()
	_find_player()


# ============================================================
# MAIN LOOP
# ============================================================

func _physics_process(delta: float) -> void:
	if dead:
		return

	_tick_timers(delta)
	_find_player()

	if hit_stun_timer > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
	else:
		match state:
			State.PATROL:
				_state_patrol(delta)
			State.CHASE:
				_state_chase(delta)
			State.CHARGE:
				_state_charge(delta)
			State.ATTACK:
				_state_attack(delta)
			State.RETREAT:
				_state_retreat(delta)
			State.REENGAGE:
				_state_reengage(delta)
			State.SEARCH:
				_state_search(delta)

	_apply_gravity(delta)
	move_and_slide()
	_update_facing()
	_update_speech(delta)


func _tick_timers(delta: float) -> void:
	hit_stun_timer = maxf(hit_stun_timer - delta, 0.0)
	damage_timer = maxf(damage_timer - delta, 0.0)
	edge_turn_timer = maxf(edge_turn_timer - delta, 0.0)
	lost_target_timer = maxf(lost_target_timer - delta, 0.0)


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		if velocity.y > 0.0:
			velocity.y = 0.0
	else:
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)


func _move_x(target_speed: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)


func _stop_x(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)


# ============================================================
# PLAYER / DETECTION
# ============================================================

func _find_player() -> void:
	if player != null and is_instance_valid(player):
		return

	var found := get_tree().get_first_node_in_group("player")

	if found is Node2D:
		player = found as Node2D
	else:
		player = null


func _has_player() -> bool:
	return player != null and is_instance_valid(player)


func _player_hidden() -> bool:
	return _has_player() and player.has_method("is_hidden") and bool(player.is_hidden())


func _sees_player() -> bool:
	if not _has_player() or _player_hidden():
		return false

	var offset := player.global_position - global_position

	if absf(offset.y) > detection_vertical_range:
		return false

	var dx := offset.x

	# Very close CT is always noticed, even from behind.
	if absf(dx) <= close_detection_distance:
		return true

	if absf(dx) > detection_distance:
		return false

	# Further away, the skull only sees in front of it.
	if direction > 0.0 and dx < -detection_behind_distance:
		return false
	if direction < 0.0 and dx > detection_behind_distance:
		return false

	return _has_line_of_sight()


func _has_line_of_sight() -> bool:
	if not require_line_of_sight or detection_ray == null:
		return true

	detection_ray.target_position = to_local(player.global_position)
	detection_ray.force_raycast_update()

	if not detection_ray.is_colliding():
		return true

	var collider := detection_ray.get_collider()

	if collider == player:
		return true

	if collider is Node and player.is_ancestor_of(collider):
		return true

	return false


# ============================================================
# EDGES / WALLS
# ============================================================

func _floor_ahead(dir: float) -> bool:
	var ray := edge_ray_right if dir > 0.0 else edge_ray_left

	if ray == null:
		return true

	ray.force_raycast_update()
	return ray.is_colliding()


# True when moving in dir would walk off a ledge (only while grounded).
func _edge_blocked(dir: float) -> bool:
	if not turn_at_edge or not is_on_floor():
		return false

	return not _floor_ahead(dir)


# Used by patrol: turn around at ledges and walls, with a short cooldown
# so the skull never flips back and forth on the same spot.
func _should_turn(dir: float) -> bool:
	if not turn_at_edge:
		return false

	if edge_turn_timer > 0.0:
		return false

	if is_on_wall():
		return true

	return _edge_blocked(dir)


func _turn_around() -> void:
	direction = -direction
	velocity.x = 0.0
	edge_turn_timer = edge_turn_cooldown
	_update_facing()


# ============================================================
# PATROL
# ============================================================

func _start_patrol() -> void:
	state = State.PATROL
	velocity.x = 0.0
	lost_target_timer = 0.0
	edge_blocked_timer = 0.0


func _state_patrol(delta: float) -> void:
	if _sees_player():
		_start_chase()
		return

	if _should_turn(direction):
		_turn_around()

	_move_x(direction * patrol_speed, delta)


# ============================================================
# CHASE
# ============================================================

func _start_chase() -> void:
	if not _has_player():
		_start_patrol()
		return

	_resume_chase()

	if detection_debug:
		print("[EliteSkull] chase started, distance=", player.global_position.distance_to(global_position))

	_say("GET BACK HERE!")
	_player_event("detected")
	_player_event("chase_started")


func _resume_chase() -> void:
	state = State.CHASE
	lost_target_timer = lose_target_delay
	edge_blocked_timer = 0.0
	last_seen_position = player.global_position


func _state_chase(delta: float) -> void:
	if not _has_player() or _player_hidden():
		_start_search()
		return

	if _sees_player():
		lost_target_timer = lose_target_delay
		last_seen_position = player.global_position
	elif lost_target_timer <= 0.0:
		_start_search()
		return

	var dx := player.global_position.x - global_position.x

	# Only attack CT when CT is in front of the skull.
	if absf(dx) <= attack_distance and (absf(dx) < 1.0 or signf(dx) == direction):
		_start_charge()
		return

	# Hysteresis: don't flip facing for tiny offsets.
	if absf(dx) > 12.0:
		direction = signf(dx)

	# CT is across a gap or behind a wall: wait briefly, then give up.
	if _edge_blocked(direction) or is_on_wall():
		_stop_x(delta)
		edge_blocked_timer += delta

		if edge_blocked_timer >= edge_blocked_give_up:
			_start_search()

		return

	edge_blocked_timer = 0.0
	_move_x(direction * chase_speed, delta)


# ============================================================
# CHARGE / ATTACK
# ============================================================

func _start_charge() -> void:
	state = State.CHARGE
	state_timer = charge_duration
	velocity.x = 0.0
	_face_player()
	_say("GOT YOU!")


func _state_charge(delta: float) -> void:
	velocity.x = 0.0

	if not _has_player():
		_start_search()
		return

	_face_player()

	state_timer -= delta

	if state_timer <= 0.0:
		_start_attack()


func _start_attack() -> void:
	state = State.ATTACK
	state_timer = attack_duration
	attack_has_hit = false
	velocity.x = 0.0
	_face_player()
	_try_hit()


func _state_attack(delta: float) -> void:
	velocity.x = 0.0
	_face_player()
	_try_hit()

	state_timer -= delta

	if state_timer > 0.0:
		return

	if attack_has_hit:
		_start_retreat()
	elif _has_player():
		_resume_chase()
	else:
		_start_patrol()


func _try_hit() -> void:
	if attack_has_hit or not _has_player() or _player_hidden():
		return

	var offset := player.global_position - global_position

	if absf(offset.x) > attack_hit_distance or absf(offset.y) > 120.0:
		return

	attack_has_hit = true

	if player.has_method("take_damage"):
		player.take_damage(attack_damage)

	if player.has_method("apply_knockback"):
		player.apply_knockback(global_position)


# ============================================================
# RETREAT / REENGAGE
# ============================================================

func _start_retreat() -> void:
	state = State.RETREAT
	state_timer = retreat_duration
	velocity.x = 0.0
	_say("BACK OFF!")


func _state_retreat(delta: float) -> void:
	if not _has_player():
		_start_patrol()
		return

	var away := signf(global_position.x - player.global_position.x)

	if away != 0.0:
		direction = away

	if _edge_blocked(direction) or is_on_wall():
		_stop_x(delta)
	else:
		_move_x(direction * retreat_speed, delta)

	state_timer -= delta

	if state_timer <= 0.0 or absf(player.global_position.x - global_position.x) >= retreat_distance:
		_start_reengage()


func _start_reengage() -> void:
	state = State.REENGAGE
	state_timer = reengage_delay
	velocity.x = 0.0


func _state_reengage(delta: float) -> void:
	_stop_x(delta)
	state_timer -= delta

	if state_timer > 0.0:
		return

	if _sees_player():
		_resume_chase()
	else:
		_start_search()


# ============================================================
# SEARCH
# ============================================================

func _start_search() -> void:
	state = State.SEARCH
	state_timer = search_duration
	velocity.x = 0.0
	_say("COME OUT!")
	_player_event("lost")


func _state_search(delta: float) -> void:
	if _sees_player():
		_start_chase()
		return

	state_timer -= delta

	if state_timer <= 0.0:
		_player_event("give_up")
		_start_patrol()
		return

	var dx := last_seen_position.x - global_position.x

	if absf(dx) < 20.0:
		_stop_x(delta)
		return

	direction = signf(dx)

	if _should_turn(direction):
		_start_patrol()
		return

	_move_x(direction * search_speed, delta)


# ============================================================
# FACING
# ============================================================

func _face_player() -> void:
	if not _has_player():
		return

	var dx := player.global_position.x - global_position.x

	if absf(dx) > 1.0:
		direction = signf(dx)

	_update_facing()


func _update_facing() -> void:
	if sprite != null:
		sprite.flip_h = direction < 0.0


# ============================================================
# HEALTH / DAMAGE (CT attacks call these)
# ============================================================

func take_damage(amount: int = 1, source_position: Vector2 = Vector2.ZERO) -> void:
	if dead or damage_timer > 0.0:
		return

	damage_timer = damage_cooldown
	health -= amount
	hit_stun_timer = hit_stun_duration

	damage_flash()

	if source_position != Vector2.ZERO:
		apply_knockback(source_position)

	if health <= 0:
		die()


func apply_knockback(source_position: Vector2) -> void:
	if dead:
		return

	var away := signf(global_position.x - source_position.x)

	if away == 0.0:
		away = -direction

	velocity.x = away * knockback_strength
	velocity.y = -knockback_vertical
	hit_stun_timer = hit_stun_duration


func damage_flash() -> void:
	if sprite == null:
		return

	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 0.35, 0.35, 1.0), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.10)


func die() -> void:
	if dead:
		return

	dead = true
	velocity = Vector2.ZERO

	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D

	if shape != null:
		shape.set_deferred("disabled", true)

	if speech_label != null:
		speech_label.visible = false

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)


func is_attacking() -> bool:
	return state == State.ATTACK


func get_state_name() -> String:
	match state:
		State.PATROL:
			return "PATROL"
		State.CHASE:
			return "CHASE"
		State.CHARGE:
			return "CHARGE"
		State.ATTACK:
			return "ATTACK"
		State.RETREAT:
			return "RETREAT"
		State.REENGAGE:
			return "REENGAGE"
		State.SEARCH:
			return "SEARCH"

	return "UNKNOWN"


# ============================================================
# SPEECH / PLAYER EVENTS
# ============================================================

func _say(text: String) -> void:
	if not enemy_speech_enabled or speech_label == null:
		return

	speech_label.text = text
	speech_label.visible = true
	speech_timer = speech_duration


func _update_speech(delta: float) -> void:
	if speech_label == null or not speech_label.visible:
		return

	speech_timer -= delta

	if speech_timer <= 0.0:
		speech_label.visible = false


func _player_event(event_name: String) -> void:
	if _has_player() and player.has_method("enemy_event"):
		player.enemy_event(event_name, "EliteSkull")
