class_name Skull
extends Enemy


# ============================================================
# PATROL
# ============================================================

@export_category("Patrol")

@export var patrol_path: Path2D
@export var patrol_speed: float = 150.0
@export var loop_path: bool = true
@export var patrol_look_ahead: float = 35.0


# ============================================================
# STORY EVENTS
# ============================================================

@export_category("Story Events")

@export var story_events_enabled: bool = true
@export var player_speech_enabled: bool = true
@export var enemy_speech_enabled: bool = false

var story_controller: Node = null
var story_detection_sent: bool = false
var story_chase_sent: bool = false
var story_lost_sent: bool = false


# ============================================================
# VISION
# ============================================================

@export_category("Vision")

@export var vision_range: float = 850.0
@export_range(30.0, 360.0, 1.0) var vision_angle: float = 150.0
@export var close_detection_range: float = 220.0
@export_flags_2d_physics var vision_collision_mask: int = 3


# ============================================================
# CHASE
# ============================================================

@export_category("Chase")

@export var chase_speed: float = 620.0
@export var chase_range: float = 1300.0
@export var lose_sight_grace: float = 0.65


# ============================================================
# ATTACK
# ============================================================

@export_category("Attack")

@export var attack_distance: float = 115.0
@export var attack_hit_distance: float = 135.0
@export var charge_duration: float = 0.35
@export var attack_duration: float = 0.20
@export var attack_damage: int = 1
@export var retreat_duration: float = 0.45
@export var retreat_distance: float = 230.0
@export var retreat_speed: float = 420.0
@export var reengage_delay: float = 0.35
@export var minimum_reengage_distance: float = 150.0


# ============================================================
# SEARCH
# ============================================================

@export_category("Search")

@export var search_speed: float = 190.0
@export var search_duration: float = 5.0
@export var search_arrival_distance: float = 35.0
@export var search_turn_interval: float = 0.65


# ============================================================
# ENEMY SPEECH
#
# OFF by default.
#
# Skull no longer talks during ordinary patrol or arbitrary
# transitions. CT handles the comedy.
# ============================================================

@export_category("Enemy Speech")

@export var speech_duration: float = 1.15


# ============================================================
# REFERENCES
# ============================================================

@onready var sprite: Sprite2D = $Sprite2D
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
	SEARCH
}

var state: State = State.PATROL
var player: Node2D = null

var path_progress: float = 0.0
var patrol_direction: float = 1.0

var facing_direction: Vector2 = Vector2.RIGHT
var last_seen_position: Vector2 = Vector2.ZERO

var lost_sight_timer: float = 0.0

var search_timer: float = 0.0
var search_turn_timer: float = 0.0
var search_reached_position: bool = false
var search_direction_index: int = 0

var charge_timer: float = 0.0
var attack_timer: float = 0.0
var retreat_timer: float = 0.0
var reengage_timer: float = 0.0

var attack_has_hit: bool = false

var speech_timer: float = 0.0


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	story_controller = get_tree().get_first_node_in_group(
		"story_controller"
	)

	_setup_speech_label()
	_disable_attack_hitbox()
	find_player()

	if patrol_path == null:
		push_error(
			"%s has no patrol_path assigned."
			% name
		)
		return

	var curve: Curve2D = patrol_path.curve

	if curve == null:
		push_error(
			"%s patrol_path has no Curve2D."
			% name
		)
		return

	var path_length: float = curve.get_baked_length()

	if path_length <= 0.0:
		push_error(
			"%s patrol path has no usable length."
			% name
		)
		return

	path_progress = curve.get_closest_offset(
		patrol_path.to_local(global_position)
	)

	path_progress = clampf(
		path_progress,
		0.0,
		path_length
	)

	update_patrol_facing()
	start_patrol()


# ============================================================
# MAIN PHYSICS
# ============================================================

func _physics_process(delta: float) -> void:
	_update_speech(delta)
	find_player()

	if not has_valid_player():
		update_patrol(delta)
		return

	match state:
		State.PATROL:
			update_patrol(delta)

		State.CHASE:
			update_chase(delta)

		State.CHARGE:
			update_charge(delta)

		State.ATTACK:
			update_attack(delta)

		State.RETREAT:
			update_retreat(delta)

		State.REENGAGE:
			update_reengage(delta)

		State.SEARCH:
			update_search(delta)


# ============================================================
# PLAYER
# ============================================================

func find_player() -> void:
	if player != null and is_instance_valid(player):
		return

	var found_player: Node = get_tree().get_first_node_in_group(
		"player"
	)

	if found_player is Node2D:
		player = found_player as Node2D


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


func player_is_within_range(range_value: float) -> bool:
	if not has_valid_player():
		return false

	return global_position.distance_squared_to(
		player.global_position
	) <= range_value * range_value


# ============================================================
# FACING
# ============================================================

func update_facing(direction: Vector2) -> void:
	if direction.length_squared() <= 0.001:
		return

	facing_direction = direction.normalized()

	if sprite != null:
		sprite.flip_h = facing_direction.x < 0.0


func update_patrol_facing() -> void:
	if patrol_path == null:
		return

	var curve: Curve2D = patrol_path.curve

	if curve == null:
		return

	var path_length := curve.get_baked_length()

	if path_length <= 0.0:
		return

	var current_progress := clampf(
		path_progress,
		0.0,
		path_length
	)

	var next_progress := clampf(
		current_progress +
		(patrol_look_ahead * patrol_direction),
		0.0,
		path_length
	)

	var current_local := curve.sample_baked(
		current_progress
	)

	var next_local := curve.sample_baked(
		next_progress
	)

	var current_world := patrol_path.to_global(
		current_local
	)

	var next_world := patrol_path.to_global(
		next_local
	)

	var direction := next_world - current_world

	if direction.length_squared() > 0.001:
		update_facing(direction)


# ============================================================
# PATROL
# ============================================================

func start_patrol() -> void:
	state = State.PATROL
	velocity = Vector2.ZERO

	lost_sight_timer = 0.0
	search_timer = 0.0
	search_turn_timer = 0.0
	search_reached_position = false

	_disable_attack_hitbox()

	if not enemy_speech_enabled:
		hide_speech()

	if patrol_path == null:
		return

	var curve: Curve2D = patrol_path.curve

	if curve == null:
		return

	var path_length := curve.get_baked_length()

	if path_length <= 0.0:
		return

	path_progress = curve.get_closest_offset(
		patrol_path.to_local(global_position)
	)

	path_progress = clampf(
		path_progress,
		0.0,
		path_length
	)

	update_patrol_facing()


func update_patrol(delta: float) -> void:
	if can_detect_player():
		start_chase()
		return

	if patrol_path == null:
		velocity = Vector2.ZERO
		return

	var curve: Curve2D = patrol_path.curve

	if curve == null:
		velocity = Vector2.ZERO
		return

	var path_length := curve.get_baked_length()

	if path_length <= 0.0:
		velocity = Vector2.ZERO
		return

	path_progress += (
		patrol_speed *
		patrol_direction *
		delta
	)

	if loop_path:
		if path_progress >= path_length:
			path_progress = path_length
			patrol_direction = -1.0

		elif path_progress <= 0.0:
			path_progress = 0.0
			patrol_direction = 1.0
	else:
		if path_progress >= path_length:
			path_progress = path_length
			patrol_direction = -1.0

		elif path_progress <= 0.0:
			path_progress = 0.0
			patrol_direction = 1.0

	var target_local := curve.sample_baked(
		path_progress
	)

	var target_world := patrol_path.to_global(
		target_local
	)

	var direction := global_position.direction_to(
		target_world
	)

	if direction.length_squared() <= 0.0001:
		velocity = Vector2.ZERO
		return

	update_facing(direction)
	velocity = direction * patrol_speed
	move_and_slide()


# ============================================================
# VISION
# ============================================================

func can_detect_player_close() -> bool:
	if not has_valid_player():
		return false

	if player_is_hidden():
		return false

	return player_is_within_range(
		close_detection_range
	)


func player_inside_fov() -> bool:
	if not has_valid_player():
		return false

	var offset := (
		player.global_position -
		global_position
	)

	if offset.length_squared() <= 0.001:
		return true

	var direction := offset.normalized()

	var half_angle := deg_to_rad(
		vision_angle * 0.5
	)

	return abs(
		facing_direction.angle_to(direction)
	) <= half_angle


func has_line_of_sight() -> bool:
	if not has_valid_player():
		return false

	if player_is_hidden():
		return false

	var space_state := (
		get_world_2d().direct_space_state
	)

	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		player.global_position
	)

	query.collision_mask = vision_collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.exclude = [get_rid()]

	var result := space_state.intersect_ray(query)

	if result.is_empty():
		return true

	var collider: Object = result.get(
		"collider"
	)

	if collider == player:
		return true

	if collider is Node:
		var node := collider as Node

		if node.is_in_group("player"):
			return true

		if player.is_ancestor_of(node):
			return true

	return false


func can_detect_player() -> bool:
	if not has_valid_player():
		return false

	if player_is_hidden():
		return false

	if can_detect_player_close():
		return true

	if not player_is_within_range(
		vision_range
	):
		return false

	if not player_inside_fov():
		return false

	return has_line_of_sight()


func can_track_player() -> bool:
	if not has_valid_player():
		return false

	if player_is_hidden():
		return false

	if not player_is_within_range(
		chase_range
	):
		return false

	if can_detect_player_close():
		return true

	return has_line_of_sight()


# ============================================================
# CHASE
# ============================================================

func start_chase() -> void:
	if not has_valid_player():
		return

	var was_already_chasing := state == State.CHASE

	state = State.CHASE
	lost_sight_timer = 0.0
	last_seen_position = player.global_position
	velocity = Vector2.ZERO

	_disable_attack_hitbox()

	if not was_already_chasing:
		_story_player_detected()
		_story_chase_started()

		if player_speech_enabled:
			_call_player_enemy_event(
				"detected",
				"Skull"
			)

			# Small delay so the detection reaction can read first.
			_call_player_enemy_event(
				"chase_started",
				"Skull"
			)

	if not enemy_speech_enabled:
		hide_speech()


func update_chase(delta: float) -> void:
	if not has_valid_player():
		start_patrol()
		return

	if player_is_hidden():
		last_seen_position = player.global_position
		start_search()
		return

	if can_track_player():
		lost_sight_timer = 0.0
		last_seen_position = player.global_position

		var distance := distance_to_player()

		if distance <= attack_distance:
			start_charge()
			return

		var direction := global_position.direction_to(
			player.global_position
		)

		update_facing(direction)
		velocity = direction * chase_speed
		move_and_slide()
		return

	lost_sight_timer += delta

	if lost_sight_timer < lose_sight_grace:
		var direction := global_position.direction_to(
			last_seen_position
		)

		if direction.length_squared() > 0.001:
			update_facing(direction)
			velocity = direction * chase_speed
			move_and_slide()

		return

	start_search()


# ============================================================
# CHARGE
# ============================================================

func start_charge() -> void:
	if not has_valid_player():
		start_search()
		return

	state = State.CHARGE
	velocity = Vector2.ZERO

	charge_timer = charge_duration
	attack_has_hit = false

	_disable_attack_hitbox()
	_face_player()

	if enemy_speech_enabled:
		show_speech("...")


func update_charge(delta: float) -> void:
	if not has_valid_player():
		start_search()
		return

	velocity = Vector2.ZERO
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
	velocity = Vector2.ZERO

	attack_timer = attack_duration
	attack_has_hit = false

	_face_player()
	_enable_attack_hitbox()

	if player_speech_enabled:
		_call_player_enemy_event(
			"attack_started",
			"Skull"
		)

	_perform_attack_hit()


func update_attack(delta: float) -> void:
	velocity = Vector2.ZERO
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

	var distance := distance_to_player()

	if distance > attack_hit_distance:
		return

	attack_has_hit = true

	if player.has_method("take_damage"):
		player.take_damage(attack_damage)

	if player.has_method("apply_knockback"):
		player.apply_knockback(global_position)

	if player.has_method("damage_flash"):
		player.damage_flash()

	if not enemy_speech_enabled:
		hide_speech()


# ============================================================
# RETREAT
# ============================================================

func start_retreat() -> void:
	if not attack_has_hit:
		start_chase()
		return

	state = State.RETREAT
	retreat_timer = retreat_duration
	velocity = Vector2.ZERO

	_disable_attack_hitbox()

	if not enemy_speech_enabled:
		hide_speech()


func update_retreat(delta: float) -> void:
	if not has_valid_player():
		start_patrol()
		return

	var direction := player.global_position.direction_to(
		global_position
	)

	update_facing(direction)

	velocity = direction * retreat_speed
	move_and_slide()

	retreat_timer -= delta

	var distance := distance_to_player()

	if retreat_timer <= 0.0:
		start_reengage()
		return

	if distance >= retreat_distance:
		start_reengage()


# ============================================================
# RE-ENGAGE
# ============================================================

func start_reengage() -> void:
	state = State.REENGAGE
	reengage_timer = reengage_delay
	velocity = Vector2.ZERO

	_disable_attack_hitbox()

	if not enemy_speech_enabled:
		hide_speech()


func update_reengage(delta: float) -> void:
	if not has_valid_player():
		start_patrol()
		return

	velocity = Vector2.ZERO
	reengage_timer -= delta

	if reengage_timer > 0.0:
		return

	var distance := distance_to_player()

	if distance < minimum_reengage_distance:
		start_retreat()
		return

	if can_track_player():
		start_chase()
	else:
		start_search()


# ============================================================
# SEARCH
# ============================================================

func start_search() -> void:
	state = State.SEARCH

	search_timer = search_duration
	search_turn_timer = 0.0
	search_reached_position = false
	search_direction_index = 0

	lost_sight_timer = 0.0
	velocity = Vector2.ZERO

	_disable_attack_hitbox()

	if not enemy_speech_enabled:
		hide_speech()

	var direction := global_position.direction_to(
		last_seen_position
	)

	if direction.length_squared() > 0.001:
		update_facing(direction)


func update_search(delta: float) -> void:
	if not has_valid_player():
		start_patrol()
		return

	if can_detect_player():
		start_chase()
		return

	search_timer -= delta

	if search_timer <= 0.0:
		start_patrol()
		return

	if not search_reached_position:
		var distance := global_position.distance_to(
			last_seen_position
		)

		if distance > search_arrival_distance:
			var direction := global_position.direction_to(
				last_seen_position
			)

			update_facing(direction)
			velocity = direction * search_speed
			move_and_slide()
			return

		search_reached_position = true
		search_turn_timer = 0.0
		velocity = Vector2.ZERO
		return

	velocity = Vector2.ZERO
	search_turn_timer -= delta

	if search_turn_timer <= 0.0:
		search_turn_timer = search_turn_interval
		perform_search_turn()


func perform_search_turn() -> void:
	var directions: Array[Vector2] = [
		Vector2.RIGHT,
		Vector2(0.7071, 0.7071),
		Vector2.DOWN,
		Vector2(-0.7071, 0.7071),
		Vector2.LEFT,
		Vector2(-0.7071, -0.7071),
		Vector2.UP,
		Vector2(0.7071, -0.7071)
	]

	var direction := directions[
		search_direction_index %
		directions.size()
	]

	search_direction_index += 1

	update_facing(direction)

	if can_detect_player():
		start_chase()


# ============================================================
# FACE PLAYER
# ============================================================

func _face_player() -> void:
	if not has_valid_player():
		return

	var direction := global_position.direction_to(
		player.global_position
	)

	if direction.length_squared() <= 0.001:
		return

	update_facing(direction)


# ============================================================
# DAMAGE HITBOX
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

func _setup_speech_label() -> void:
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

	return "UNKNOWN"


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

	if not story_controller.has_method(
		"emit_gameplay_event"
	):
		return

	story_controller.emit_gameplay_event(
		event_name,
		1.0
	)


func _story_player_detected() -> void:
	if story_detection_sent:
		return

	story_detection_sent = true
	story_chase_sent = false
	story_lost_sent = false

	_emit_story_event("skull_detected")


func _story_chase_started() -> void:
	if story_chase_sent:
		return

	story_chase_sent = true

	_emit_story_event("skull_chase_started")


func _story_player_lost() -> void:
	if story_lost_sent:
		return

	story_lost_sent = true

	_emit_story_event("skull_lost_player")


func _reset_story_detection() -> void:
	story_detection_sent = false
	story_chase_sent = false
	story_lost_sent = false
