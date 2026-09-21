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
# VISION
# ============================================================

@export_category("Vision")
@export var vision_range: float = 850.0
@export_range(30.0, 360.0, 1.0) var vision_angle: float = 150.0

# If CT is this close, Skull detects CT regardless of FOV/LOS.
@export var close_detection_range: float = 220.0

# Only used for long-range line-of-sight checks.
@export_flags_2d_physics var vision_collision_mask: int = 3


# ============================================================
# CHASE
# ============================================================

@export_category("Chase")
@export var chase_speed: float = 620.0
@export var chase_range: float = 1300.0
@export var lose_sight_grace: float = 0.65
@export var chase_stop_distance: float = 35.0


# ============================================================
# SEARCH
# ============================================================

@export_category("Search")
@export var search_speed: float = 190.0
@export var search_duration: float = 5.0
@export var search_arrival_distance: float = 35.0
@export var search_turn_interval: float = 0.65


# ============================================================
# REFERENCES
# ============================================================

@onready var sprite: Sprite2D = $Sprite2D


# ============================================================
# STATE
# ============================================================

enum State
{
	PATROL,
	CHASE,
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


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	find_player()

	if patrol_path == null:
		push_error("%s has no patrol_path assigned." % name)
		return

	var curve: Curve2D = patrol_path.curve

	if curve == null:
		push_error("%s patrol_path has no Curve2D." % name)
		return

	var path_length: float = curve.get_baked_length()

	if path_length <= 0.0:
		push_error("%s patrol path has no usable length." % name)
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


# ============================================================
# FIND PLAYER
# ============================================================

func find_player() -> void:
	if player != null and is_instance_valid(player):
		return

	var found_player: Node = get_tree().get_first_node_in_group("player")

	if found_player is Node2D:
		player = found_player as Node2D


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

	var path_length: float = curve.get_baked_length()

	if path_length <= 0.0:
		return

	var current_progress: float = clampf(
		path_progress,
		0.0,
		path_length
	)

	var next_progress: float = clampf(
		current_progress + (
			patrol_look_ahead * patrol_direction
		),
		0.0,
		path_length
	)

	var current_local: Vector2 = curve.sample_baked(
		current_progress
	)

	var next_local: Vector2 = curve.sample_baked(
		next_progress
	)

	var current_world: Vector2 = patrol_path.to_global(
		current_local
	)

	var next_world: Vector2 = patrol_path.to_global(
		next_local
	)

	var direction: Vector2 = next_world - current_world

	if direction.length_squared() > 0.001:
		update_facing(direction)


# ============================================================
# PLAYER VALIDITY
# ============================================================

func has_valid_player() -> bool:
	if player == null:
		return false

	if not is_instance_valid(player):
		player = null
		return false

	return true


# ============================================================
# PLAYER HIDDEN
# ============================================================

func player_is_hidden() -> bool:
	if not has_valid_player():
		return false

	if player.has_method("is_hidden"):
		return bool(player.is_hidden())

	return false


# ============================================================
# DISTANCE
# ============================================================

func distance_to_player() -> float:
	if not has_valid_player():
		return INF

	return global_position.distance_to(
		player.global_position
	)


func player_is_within_range(range_value: float) -> bool:
	if not has_valid_player():
		return false

	var distance_squared: float = (
		global_position.distance_squared_to(
			player.global_position
		)
	)

	return distance_squared <= (
		range_value * range_value
	)


# ============================================================
# CLOSE DETECTION
#
# IMPORTANT:
# This does NOT use FOV.
# This does NOT use the physics ray.
#
# If CT is physically close enough, Skull sees CT.
# ============================================================

func can_detect_player_close() -> bool:
	if not has_valid_player():
		return false

	if player_is_hidden():
		return false

	return player_is_within_range(
		close_detection_range
	)


# ============================================================
# LINE OF SIGHT
# ============================================================

func has_line_of_sight() -> bool:
	if not has_valid_player():
		return false

	if player_is_hidden():
		return false

	var space_state: PhysicsDirectSpaceState2D = (
		get_world_2d().direct_space_state
	)

	var query: PhysicsRayQueryParameters2D = (
		PhysicsRayQueryParameters2D.create(
			global_position,
			player.global_position
		)
	)

	query.collision_mask = vision_collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = true

	var excluded_rids: Array[RID] = []
	excluded_rids.append(get_rid())

	query.exclude = excluded_rids

	var result: Dictionary = (
		space_state.intersect_ray(query)
	)

	# Nothing blocked the ray.
	#
	# This is intentionally treated as visible.
	# This is important if CT has no collision body
	# on the vision mask.
	if result.is_empty():
		return true

	var collider_variant: Variant = result.get(
		"collider",
		null
	)

	if collider_variant == null:
		return false

	if collider_variant is Node:
		var collider_node: Node = (
			collider_variant as Node
		)

		if collider_node == player:
			return true

		if collider_node.is_in_group("player"):
			return true

		var parent: Node = collider_node.get_parent()

		if parent != null:
			if parent == player:
				return true

			if parent.is_in_group("player"):
				return true

	return false


# ============================================================
# FIELD OF VIEW
# ============================================================

func player_inside_fov() -> bool:
	if not has_valid_player():
		return false

	var to_player: Vector2 = (
		player.global_position - global_position
	)

	if to_player.length_squared() <= 0.001:
		return true

	var direction_to_player: Vector2 = (
		to_player.normalized()
	)

	var half_angle: float = deg_to_rad(
		vision_angle * 0.5
	)

	var angle_difference: float = abs(
		facing_direction.angle_to(
			direction_to_player
		)
	)

	return angle_difference <= half_angle


# ============================================================
# MAIN DETECTION
# ============================================================

func can_detect_player() -> bool:
	if not has_valid_player():
		return false

	if player_is_hidden():
		return false

	# --------------------------------------------------------
	# PRIORITY 1:
	# Extremely close detection.
	#
	# No FOV.
	# No raycast.
	# --------------------------------------------------------

	if can_detect_player_close():
		return true

	# --------------------------------------------------------
	# PRIORITY 2:
	# Normal vision.
	# --------------------------------------------------------

	if not player_is_within_range(vision_range):
		return false

	if not player_inside_fov():
		return false

	if not has_line_of_sight():
		return false

	return true


# ============================================================
# CHASE DETECTION
# ============================================================

func can_track_player() -> bool:
	if not has_valid_player():
		return false

	if player_is_hidden():
		return false

	# During chase we do not care about FOV.
	# Skull can track CT anywhere around itself
	# as long as CT remains visible.
	if not player_is_within_range(chase_range):
		return false

	# Close range always works.
	if can_detect_player_close():
		return true

	return has_line_of_sight()


# ============================================================
# START CHASE
# ============================================================

func start_chase() -> void:
	if not has_valid_player():
		return

	state = State.CHASE

	lost_sight_timer = 0.0

	search_timer = 0.0
	search_turn_timer = 0.0
	search_reached_position = false

	last_seen_position = player.global_position

	velocity = Vector2.ZERO

	print(
		"%s -> CHASE CT | distance: %.1f"
		% [
			name,
			distance_to_player()
		]
	)


# ============================================================
# START SEARCH
# ============================================================

func start_search() -> void:
	state = State.SEARCH

	search_timer = search_duration
	search_turn_timer = 0.0

	search_reached_position = false
	search_direction_index = 0

	lost_sight_timer = 0.0

	velocity = Vector2.ZERO

	var direction_to_last_seen: Vector2 = (
		global_position.direction_to(
			last_seen_position
		)
	)

	if direction_to_last_seen.length_squared() > 0.001:
		update_facing(
			direction_to_last_seen
		)

	print("%s -> SEARCH" % name)


# ============================================================
# START PATROL
# ============================================================

func start_patrol() -> void:
	state = State.PATROL

	lost_sight_timer = 0.0

	search_timer = 0.0
	search_turn_timer = 0.0

	search_reached_position = false

	velocity = Vector2.ZERO

	if patrol_path == null:
		return

	var curve: Curve2D = patrol_path.curve

	if curve == null:
		return

	var path_length: float = curve.get_baked_length()

	if path_length <= 0.0:
		return

	path_progress = curve.get_closest_offset(
		patrol_path.to_local(
			global_position
		)
	)

	path_progress = clampf(
		path_progress,
		0.0,
		path_length
	)

	update_patrol_facing()

	print("%s -> PATROL" % name)


# ============================================================
# PHYSICS
# ============================================================

func _physics_process(delta: float) -> void:
	find_player()

	if not has_valid_player():
		update_patrol(delta)
		return

	match state:
		State.PATROL:
			update_patrol(delta)

		State.CHASE:
			update_chase(delta)

		State.SEARCH:
			update_search(delta)


# ============================================================
# PATROL
# ============================================================

func update_patrol(delta: float) -> void:
	# Detection happens BEFORE patrol movement.
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

	var path_length: float = curve.get_baked_length()

	if path_length <= 0.0:
		velocity = Vector2.ZERO
		return

	path_progress += (
		patrol_speed
		* patrol_direction
		* delta
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

	var target_local_position: Vector2 = (
		curve.sample_baked(path_progress)
	)

	var target_world_position: Vector2 = (
		patrol_path.to_global(
			target_local_position
		)
	)

	var direction: Vector2 = (
		global_position.direction_to(
			target_world_position
		)
	)

	if direction.length_squared() <= 0.0001:
		velocity = Vector2.ZERO
		return

	update_facing(direction)

	velocity = direction * patrol_speed

	move_and_slide()


# ============================================================
# CHASE
# ============================================================

func update_chase(delta: float) -> void:
	if not has_valid_player():
		start_patrol()
		return

	# --------------------------------------------------------
	# CT HIDES
	# --------------------------------------------------------

	if player_is_hidden():
		last_seen_position = player.global_position
		start_search()
		return

	# --------------------------------------------------------
	# CT STILL VISIBLE
	# --------------------------------------------------------

	if can_track_player():
		lost_sight_timer = 0.0

		last_seen_position = player.global_position

		var distance: float = distance_to_player()

		if distance <= chase_stop_distance:
			velocity = Vector2.ZERO
			return

		var direction: Vector2 = (
			global_position.direction_to(
				player.global_position
			)
		)

		update_facing(direction)

		velocity = direction * chase_speed

		move_and_slide()

		return

	# --------------------------------------------------------
	# LOST CT
	# --------------------------------------------------------

	lost_sight_timer += delta

	if lost_sight_timer < lose_sight_grace:
		var direction_to_last_seen: Vector2 = (
			global_position.direction_to(
				last_seen_position
			)
		)

		if direction_to_last_seen.length_squared() > 0.001:
			update_facing(
				direction_to_last_seen
			)

			velocity = (
				direction_to_last_seen
				* chase_speed
			)

			move_and_slide()

		else:
			velocity = Vector2.ZERO

		return

	start_search()


# ============================================================
# SEARCH
# ============================================================

func update_search(delta: float) -> void:
	if not has_valid_player():
		start_patrol()
		return

	# CT appears again.
	if can_detect_player():
		start_chase()
		return

	search_timer -= delta

	if search_timer <= 0.0:
		start_patrol()
		return

	# --------------------------------------------------------
	# GO TO LAST KNOWN POSITION
	# --------------------------------------------------------

	if not search_reached_position:
		var distance_to_last_seen: float = (
			global_position.distance_to(
				last_seen_position
			)
		)

		if distance_to_last_seen > search_arrival_distance:
			var direction: Vector2 = (
				global_position.direction_to(
					last_seen_position
				)
			)

			update_facing(direction)

			velocity = (
				direction * search_speed
			)

			move_and_slide()

			return

		search_reached_position = true
		search_turn_timer = 0.0
		search_direction_index = 0

		velocity = Vector2.ZERO

		print(
			"%s reached last known position"
			% name
		)

		return

	# --------------------------------------------------------
	# LOOK AROUND
	# --------------------------------------------------------

	velocity = Vector2.ZERO

	search_turn_timer -= delta

	if search_turn_timer <= 0.0:
		search_turn_timer = search_turn_interval
		perform_search_turn()


# ============================================================
# SEARCH ROTATION
# ============================================================

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

	var count: int = directions.size()

	if count <= 0:
		return

	var direction: Vector2 = directions[
		search_direction_index % count
	]

	search_direction_index += 1

	update_facing(direction)

	# Check immediately after turning.
	if can_detect_player():
		start_chase()


# ============================================================
# DEBUG
# ============================================================

func get_state_name() -> String:
	match state:
		State.PATROL:
			return "PATROL"

		State.CHASE:
			return "CHASE"

		State.SEARCH:
			return "SEARCH"

	return "UNKNOWN"
