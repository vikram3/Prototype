
extends CharacterBody2D

# ============================================================
# ELITE SKULL - COMPLETE STANDALONE PLATFORMER ENEMY
# ============================================================
# No dependency on Skull.gd.
#
# Required scene children:
#   Sprite2D
#   CollisionShape2D
#   DamageHitbox       (optional)
#   SpeechLabel        (optional)
#
# The script automatically creates its own floor/edge raycasts.
#
# Platform rules:
#   - Patrols horizontally.
#   - Turns around at platform edges.
#   - Never intentionally crosses a platform gap.
#   - Never uses Path2D.
#
# CT compatibility:
#   take_damage()
#   apply_knockback()
#   damage_flash()
#   enemy_event()
#
# ============================================================


# ============================================================
# MOVEMENT
# ============================================================

@export_category("Movement")

@export var patrol_speed: float = 150.0
@export var chase_speed: float = 260.0
@export var retreat_speed: float = 190.0

@export var acceleration: float = 1200.0
@export var deceleration: float = 1600.0

@export var gravity: float = 1800.0
@export var max_fall_speed: float = 1000.0


# ============================================================
# PLATFORM SAFETY
# ============================================================

@export_category("Platform Safety")

@export var edge_check_distance: float = 30.0
@export var edge_check_depth: float = 90.0
@export var edge_check_height: float = 18.0
@export var turn_at_edge: bool = true


# ============================================================
# DETECTION
# ============================================================

@export_category("Detection")

@export var detection_horizontal_range: float = 850.0
@export var detection_vertical_range: float = 300.0
@export var close_detection_range: float = 180.0

# If enabled, Elite Skull does not require a traditional FOV.
@export var ignore_fov: bool = true

# Optional line-of-sight check.
@export var use_line_of_sight: bool = false

@export_flags_2d_physics var vision_collision_mask: int = 3


# ============================================================
# COMBAT
# ============================================================

@export_category("Combat")

@export var max_health: int = 3
@export var attack_damage: int = 1

@export var attack_distance: float = 105.0
@export var attack_hit_distance: float = 135.0

@export var charge_duration: float = 0.25
@export var attack_duration: float = 0.20

@export var retreat_duration: float = 0.40
@export var retreat_distance: float = 180.0

@export var reengage_delay: float = 0.30


# ============================================================
# KNOCKBACK / HIT
# ============================================================

@export_category("Damage")

@export var hit_stun_duration: float = 0.12
@export var knockback_strength: float = 260.0
@export var knockback_vertical: float = 100.0

@export var damage_cooldown: float = 0.20


# ============================================================
# SEARCH
# ============================================================

@export_category("Search")

@export var search_speed: float = 140.0
@export var search_duration: float = 4.0


# ============================================================
# SPEECH
# ============================================================

@export_category("Speech")

@export var enemy_speech_enabled: bool = true
@export var speech_duration: float = 1.2


# ============================================================
# STORY
# ============================================================

@export_category("Story")

@export var story_events_enabled: bool = true
@export var player_speech_enabled: bool = true


# ============================================================
# REFERENCES
# ============================================================

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var speech_label: Label = get_node_or_null("SpeechLabel")
@onready var damage_hitbox: Area2D = get_node_or_null("DamageHitbox")


# ============================================================
# STATE
# ============================================================

enum State {
	PATROL,
	CHASE,
	CHARGE,
	ATTACK,
	RETREAT,
	REENGAGE,
	SEARCH,
	DEAD
}

var state: State = State.PATROL

var player: Node2D = null
var story_controller: Node = null

var health: int
var direction: float = 1.0

var last_seen_position: Vector2 = Vector2.ZERO
var lost_sight_timer: float = 0.0
var aggression_timer: float = 0.0

var charge_timer: float = 0.0
var attack_timer: float = 0.0
var retreat_timer: float = 0.0
var reengage_timer: float = 0.0
var search_timer: float = 0.0

var speech_timer: float = 0.0
var hit_stun_timer: float = 0.0
var damage_timer: float = 0.0

var attack_has_hit: bool = false
var dead: bool = false

var story_detection_sent: bool = false
var story_chase_sent: bool = false
var story_lost_sent: bool = false

var floor_ray: RayCast2D
var edge_ray: RayCast2D


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	health = max_health

	story_controller = get_tree().get_first_node_in_group(
		"story_controller"
	)

	_find_player()
	_setup_rays()
	_setup_speech()

	_disable_attack_hitbox()

	# Start moving immediately.
	if sprite != null:
		direction = -1.0 if sprite.flip_h else 1.0

	update_facing(direction)

	state = State.PATROL


# ============================================================
# MAIN LOOP
# ============================================================

func _physics_process(delta: float) -> void:
	if dead:
		return

	_update_timers(delta)
	_update_speech(delta)
	_find_player()

	_apply_gravity(delta)

	if hit_stun_timer > 0.0:
		velocity.x = move_toward(
			velocity.x,
			0.0,
			deceleration * delta
		)
		move_and_slide()
		return

	match state:
		State.PATROL:
			_update_patrol(delta)

		State.CHASE:
			_update_chase(delta)

		State.CHARGE:
			_update_charge(delta)

		State.ATTACK:
			_update_attack(delta)

		State.RETREAT:
			_update_retreat(delta)

		State.REENGAGE:
			_update_reengage(delta)

		State.SEARCH:
			_update_search(delta)

	move_and_slide()


# ============================================================
# TIMERS
# ============================================================

func _update_timers(delta: float) -> void:
	hit_stun_timer = maxf(
		hit_stun_timer - delta,
		0.0
	)

	damage_timer = maxf(
		damage_timer - delta,
		0.0
	)

	aggression_timer = maxf(
		aggression_timer - delta,
		0.0
	)


# ============================================================
# GRAVITY
# ============================================================

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		if velocity.y > 0.0:
			velocity.y = 0.0
		return

	velocity.y += gravity * delta

	velocity.y = minf(
		velocity.y,
		max_fall_speed
	)


# ============================================================
# PLAYER
# ============================================================

func _find_player() -> void:
	if player != null and is_instance_valid(player):
		return

	var found := get_tree().get_first_node_in_group(
		"player"
	)

	if found is Node2D:
		player = found as Node2D


func has_valid_player() -> bool:
	if player == null:
		return false

	if not is_instance_valid(player):
		player = null
		return false

	return true


func player_is_hidden() -> bool:
	if not has_valid_player():
		return false

	if player.has_method("is_hidden"):
		return bool(player.is_hidden())

	return false


func distance_to_player() -> float:
	if not has_valid_player():
		return INF

	return global_position.distance_to(
		player.global_position
	)


# ============================================================
# PLATFORM RAYS
# ============================================================

func _setup_rays() -> void:
	floor_ray = get_node_or_null(
		"FloorRay"
	) as RayCast2D

	if floor_ray == null:
		floor_ray = RayCast2D.new()
		floor_ray.name = "FloorRay"
		add_child(floor_ray)

	floor_ray.enabled = true
	floor_ray.collision_mask = 2
	floor_ray.collide_with_bodies = true
	floor_ray.collide_with_areas = false


	edge_ray = get_node_or_null(
		"EdgeRay"
	) as RayCast2D

	if edge_ray == null:
		edge_ray = RayCast2D.new()
		edge_ray.name = "EdgeRay"
		add_child(edge_ray)

	edge_ray.enabled = true
	edge_ray.collision_mask = 2
	edge_ray.collide_with_bodies = true
	edge_ray.collide_with_areas = false


# ============================================================
# EDGE DETECTION
# ============================================================

func is_platform_edge_ahead(check_direction: float) -> bool:
	if absf(check_direction) < 0.01:
		return false

	if floor_ray == null:
		return false

	# Probe from slightly above the feet.
	floor_ray.position = Vector2(
		check_direction * edge_check_distance,
		-edge_check_height
	)

	floor_ray.target_position = Vector2(
		0.0,
		edge_check_depth
	)

	floor_ray.force_raycast_update()

	# Something solid exists below the probe.
	if floor_ray.is_colliding():
		return false

	return true


func turn_at_platform_edge() -> void:
	velocity.x = 0.0

	direction *= -1.0

	update_facing(direction)


# ============================================================
# PATROL
# ============================================================

func start_patrol() -> void:
	if dead:
		return

	state = State.PATROL

	velocity.x = 0.0

	lost_sight_timer = 0.0
	aggression_timer = 0.0

	_disable_attack_hitbox()


func _update_patrol(delta: float) -> void:
	if _can_detect_player():
		start_chase()
		return

	if is_platform_edge_ahead(direction):
		turn_at_platform_edge()
		return

	velocity.x = move_toward(
		velocity.x,
		direction * patrol_speed,
		acceleration * delta
	)

	update_facing(direction)


# ============================================================
# DETECTION
# ============================================================

func _can_detect_player() -> bool:
	if not has_valid_player():
		return false

	if player_is_hidden():
		return false

	var offset := (
		player.global_position -
		global_position
	)

	var horizontal := absf(offset.x)
	var vertical := absf(offset.y)

	if horizontal <= close_detection_range and \
		vertical <= detection_vertical_range:
		return true

	if horizontal > detection_horizontal_range:
		return false

	if vertical > detection_vertical_range:
		return false

	if use_line_of_sight and not _has_line_of_sight():
		return false

	return true


func _can_track_player() -> bool:
	if not has_valid_player():
		return false

	if player_is_hidden():
		return false

	var offset := (
		player.global_position -
		global_position
	)

	if absf(offset.x) > detection_horizontal_range:
		return false

	if absf(offset.y) > detection_vertical_range:
		return false

	if use_line_of_sight and not _has_line_of_sight():
		return false

	return true


func _has_line_of_sight() -> bool:
	if not has_valid_player():
		return false

	var space := get_world_2d().direct_space_state

	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		player.global_position
	)

	query.collision_mask = vision_collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.exclude = [get_rid()]

	var result := space.intersect_ray(query)

	if result.is_empty():
		return true

	var collider: Object = result.get("collider")

	if collider == player:
		return true

	if collider is Node and player.is_ancestor_of(collider):
		return true

	return false


# ============================================================
# CHASE
# ============================================================

func start_chase() -> void:
	if not has_valid_player():
		start_patrol()
		return

	var was_chasing := state == State.CHASE

	state = State.CHASE

	lost_sight_timer = 0.0
	aggression_timer = 1.25

	last_seen_position = player.global_position

	_disable_attack_hitbox()

	_face_player()

	if not was_chasing:
		_emit_story_event("skull_detected")
		_emit_story_event("skull_chase_started")

		_call_player_enemy_event(
			"detected",
			"EliteSkull"
		)

		_call_player_enemy_event(
			"chase_started",
			"EliteSkull"
		)

		if enemy_speech_enabled:
			show_speech("GET BACK HERE!")


func _update_chase(delta: float) -> void:
	if not has_valid_player():
		start_patrol()
		return

	if player_is_hidden():
		last_seen_position = player.global_position
		start_search()
		return

	if _can_track_player():
		lost_sight_timer = 0.0
		aggression_timer = 1.25

		last_seen_position = player.global_position

		var horizontal := (
			player.global_position.x -
			global_position.x
		)

		if absf(horizontal) <= attack_distance:
			start_charge()
			return

		direction = -1.0 if horizontal < 0.0 else 1.0

		# NEVER cross a gap.
		if is_platform_edge_ahead(direction):
			turn_at_platform_edge()
			return

		velocity.x = move_toward(
			velocity.x,
			direction * chase_speed,
			acceleration * delta
		)

		update_facing(direction)
		return

	lost_sight_timer += delta

	if aggression_timer > 0.0:
		var horizontal := (
			last_seen_position.x -
			global_position.x
		)

		if absf(horizontal) > 5.0:
			direction = -1.0 if horizontal < 0.0 else 1.0

			if is_platform_edge_ahead(direction):
				turn_at_platform_edge()
			else:
				velocity.x = move_toward(
					velocity.x,
					direction * chase_speed,
					acceleration * delta
				)

		return

	_emit_story_event("skull_lost_player")

	start_search()


# ============================================================
# CHARGE
# ============================================================

func start_charge() -> void:
	if not has_valid_player():
		start_search()
		return

	state = State.CHARGE

	velocity.x = 0.0

	charge_timer = charge_duration
	attack_has_hit = false

	_face_player()
	_disable_attack_hitbox()

	if enemy_speech_enabled:
		show_speech("GOT YOU!")


func _update_charge(delta: float) -> void:
	if not has_valid_player():
		start_search()
		return

	velocity.x = move_toward(
		velocity.x,
		0.0,
		deceleration * delta
	)

	_face_player()

	charge_timer -= delta

	if charge_timer <= 0.0:
		start_attack()


# ============================================================
# ATTACK
# ============================================================

func start_attack() -> void:
	if not has_valid_player():
		start_search()
		return

	state = State.ATTACK

	velocity.x = 0.0

	attack_timer = attack_duration
	attack_has_hit = false

	_face_player()
	_enable_attack_hitbox()

	_call_player_enemy_event(
		"attack_started",
		"EliteSkull"
	)

	_perform_attack_hit()

	if enemy_speech_enabled:
		show_speech("HA!")


func _update_attack(delta: float) -> void:
	velocity.x = move_toward(
		velocity.x,
		0.0,
		deceleration * delta
	)

	_face_player()

	attack_timer -= delta

	if not attack_has_hit:
		_perform_attack_hit()

	if attack_timer > 0.0:
		return

	_disable_attack_hitbox()

	if attack_has_hit:
		start_retreat()
	else:
		start_chase()


func _perform_attack_hit() -> void:
	if attack_has_hit:
		return

	if not has_valid_player():
		return

	if player_is_hidden():
		return

	if distance_to_player() > attack_hit_distance:
		return

	attack_has_hit = true

	if player.has_method("take_damage"):
		player.take_damage(attack_damage)

	if player.has_method("apply_knockback"):
		player.apply_knockback(
			global_position
		)

	if player.has_method("damage_flash"):
		player.damage_flash()


# ============================================================
# RETREAT
# ============================================================

func start_retreat() -> void:
	if not attack_has_hit:
		start_chase()
		return

	state = State.RETREAT

	retreat_timer = retreat_duration

	velocity.x = 0.0

	_disable_attack_hitbox()

	if enemy_speech_enabled:
		show_speech("BACK OFF!")


func _update_retreat(delta: float) -> void:
	if not has_valid_player():
		start_patrol()
		return

	direction = signf(
		global_position.x -
		player.global_position.x
	)

	if absf(direction) < 0.01:
		direction = -direction

	if is_platform_edge_ahead(direction):
		turn_at_platform_edge()
	else:
		velocity.x = move_toward(
			velocity.x,
			direction * retreat_speed,
			acceleration * delta
		)

		update_facing(direction)

	retreat_timer -= delta

	if retreat_timer <= 0.0 or \
		distance_to_player() >= retreat_distance:
		start_reengage()


# ============================================================
# RE-ENGAGE
# ============================================================

func start_reengage() -> void:
	state = State.REENGAGE

	reengage_timer = reengage_delay

	velocity.x = 0.0

	_disable_attack_hitbox()


func _update_reengage(delta: float) -> void:
	if not has_valid_player():
		start_patrol()
		return

	velocity.x = move_toward(
		velocity.x,
		0.0,
		deceleration * delta
	)

	reengage_timer -= delta

	if reengage_timer > 0.0:
		return

	if _can_track_player():
		start_chase()
	else:
		start_search()


# ============================================================
# SEARCH
# ============================================================

func start_search() -> void:
	state = State.SEARCH

	search_timer = search_duration

	velocity.x = 0.0

	_disable_attack_hitbox()

	if enemy_speech_enabled:
		show_speech("COME OUT!")


func _update_search(delta: float) -> void:
	if not has_valid_player():
		start_patrol()
		return

	if _can_detect_player():
		start_chase()
		return

	search_timer -= delta

	if search_timer <= 0.0:
		start_patrol()
		return

	var horizontal := (
		last_seen_position.x -
		global_position.x
	)

	if absf(horizontal) <= 30.0:
		velocity.x = move_toward(
			velocity.x,
			0.0,
			deceleration * delta
		)
		return

	direction = -1.0 if horizontal < 0.0 else 1.0

	if is_platform_edge_ahead(direction):
		turn_at_platform_edge()
		return

	velocity.x = move_toward(
		velocity.x,
		direction * search_speed,
		acceleration * delta
	)

	update_facing(direction)


# ============================================================
# FACE PLAYER
# ============================================================

func _face_player() -> void:
	if not has_valid_player():
		return

	var horizontal := (
		player.global_position.x -
		global_position.x
	)

	if absf(horizontal) <= 0.01:
		return

	direction = -1.0 if horizontal < 0.0 else 1.0

	update_facing(direction)


func update_facing(horizontal_direction: float) -> void:
	if absf(horizontal_direction) < 0.01:
		return

	if sprite != null:
		sprite.flip_h = horizontal_direction < 0.0


# ============================================================
# DAMAGE / HEALTH
# ============================================================

func take_damage(amount: int = 1) -> void:
	if dead:
		return

	if damage_timer > 0.0:
		return

	damage_timer = damage_cooldown

	health -= amount

	hit_stun_timer = hit_stun_duration

	damage_flash()

	if health <= 0:
		die()


func apply_knockback(source_position: Vector2) -> void:
	if dead:
		return

	var away := (
		global_position -
		source_position
	)

	if absf(away.x) < 0.01:
		away.x = -direction

	away.x = signf(away.x)

	velocity.x = away.x * knockback_strength
	velocity.y = -knockback_vertical


func damage_flash() -> void:
	if sprite == null:
		return

	var tween := create_tween()

	tween.tween_property(
		sprite,
		"modulate",
		Color(1.0, 0.35, 0.35, 1.0),
		0.05
	)

	tween.tween_property(
		sprite,
		"modulate",
		Color.WHITE,
		0.10
	)


func die() -> void:
	if dead:
		return

	dead = true
	state = State.DEAD

	velocity = Vector2.ZERO

	_disable_attack_hitbox()

	_emit_story_event("elite_skull_defeated")

	# Give death effects/animation a chance if the scene provides them.
	if has_node("AnimationPlayer"):
		var animation_player := get_node(
			"AnimationPlayer"
		) as AnimationPlayer

		if animation_player.has_animation("death"):
			animation_player.play("death")

			await animation_player.animation_finished

	queue_free()


# ============================================================
# ATTACK HITBOX
# ============================================================

func _enable_attack_hitbox() -> void:
	if damage_hitbox == null:
		return

	damage_hitbox.set_deferred(
		"monitoring",
		true
	)

	damage_hitbox.set_deferred(
		"monitorable",
		true
	)


func _disable_attack_hitbox() -> void:
	if damage_hitbox == null:
		return

	damage_hitbox.set_deferred(
		"monitoring",
		false
	)

	damage_hitbox.set_deferred(
		"monitorable",
		false
	)


func is_attacking() -> bool:
	return state == State.ATTACK


# ============================================================
# SPEECH
# ============================================================

func _setup_speech() -> void:
	if speech_label == null:
		return

	speech_label.visible = false


func show_speech(text: String) -> void:
	if not enemy_speech_enabled:
		return

	if speech_label == null:
		return

	if text.is_empty():
		return

	speech_label.text = text
	speech_label.visible = true
	speech_timer = speech_duration


func hide_speech() -> void:
	if speech_label == null:
		return

	speech_label.visible = false
	speech_timer = 0.0


func _update_speech(delta: float) -> void:
	if speech_label == null:
		return

	if not speech_label.visible:
		return

	speech_timer -= delta

	if speech_timer <= 0.0:
		hide_speech()


# ============================================================
# PLAYER SPEECH BRIDGE
# ============================================================

func _call_player_enemy_event(
	event_name: String,
	enemy_type: String
) -> void:
	if not player_speech_enabled:
		return

	if player == null:
		return

	if not is_instance_valid(player):
		return

	if player.has_method("enemy_event"):
		player.enemy_event(
			event_name,
			enemy_type
		)


# ============================================================
# STORY EVENTS
# ============================================================

func _emit_story_event(event_name: String) -> void:
	if not story_events_enabled:
		return

	if story_controller == null:
		story_controller = get_tree().get_first_node_in_group(
			"story_controller"
		)

	if story_controller == null:
		return

	if story_controller.has_method(
		"emit_gameplay_event"
	):
		story_controller.emit_gameplay_event(
			event_name,
			1.0
		)


# ============================================================
# DEBUG
# ============================================================

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

		State.DEAD:
			return "DEAD"

	return "UNKNOWN"
