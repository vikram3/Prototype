class_name Skull
extends Enemy


# ============================================================
# PATROL
# ============================================================

@export_category("Patrol")

@export var patrol_path: Path2D

@export var patrol_speed: float = 60.0
@export var loop_path: bool = true


# ============================================================
# VISION
# ============================================================

@export_category("Vision")

# Distance at which Skull can initially detect CT.
@export var vision_range: float = 550.0

# Total field of view.
@export var vision_angle: float = 120.0


# ============================================================
# CHASE
# ============================================================

@export_category("Chase")

# Skull should be faster than CT.
@export var chase_speed: float = 300.0

# Maximum distance Skull will continue tracking CT.
@export var chase_range: float = 700.0

# Small grace period before Skull decides it actually lost CT.
@export var lose_sight_grace: float = 0.35


# ============================================================
# SEARCH
# ============================================================

@export_category("Search")

@export var search_speed: float = 100.0

@export var search_duration: float = 3.0

# Distance considered close enough to the last known position.
@export var search_arrival_distance: float = 12.0


# ============================================================
# NODES
# ============================================================

@onready var vision_ray: RayCast2D = $VisionRay
@onready var sprite: Sprite2D = $Sprite2D


# ============================================================
# STATE
# ============================================================

enum State {
	PATROL,
	CHASE,
	SEARCH
}


var state: State = State.PATROL


# ============================================================
# PLAYER
# ============================================================

var player: Node2D = null


# ============================================================
# PATROL
# ============================================================

var path_progress: float = 0.0

var patrol_direction: float = 1.0


# ============================================================
# VISION
# ============================================================

var was_seeing_player: bool = false

var facing_direction: Vector2 = Vector2.RIGHT


# ============================================================
# CHASE
# ============================================================

var last_seen_position: Vector2 = Vector2.ZERO

var lost_sight_timer: float = 0.0


# ============================================================
# SEARCH
# ============================================================

var search_timer: float = 0.0

var search_reached_position: bool = false


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	find_player()


	if patrol_path == null:

		push_error(
			"%s has no patrol path assigned."
			% name
		)

		return


	var curve: Curve2D = patrol_path.curve


	if curve == null:

		push_error(
			"%s patrol path has no Curve2D."
			% name
		)

		return


	path_progress = curve.get_closest_offset(
		patrol_path.to_local(
			global_position
		)
	)


	# --------------------------------------------------------
	# Calculate initial facing direction from patrol path.
	# --------------------------------------------------------

	var path_length: float = curve.get_baked_length()


	if path_length > 0.0:

		var next_progress: float = min(
			path_progress + 5.0,
			path_length
		)

		var current_local_position: Vector2 = (
			curve.sample_baked(path_progress)
		)

		var next_local_position: Vector2 = (
			curve.sample_baked(next_progress)
		)

		var current_position: Vector2 = (
			patrol_path.to_global(
				current_local_position
			)
		)

		var next_position: Vector2 = (
			patrol_path.to_global(
				next_local_position
			)
		)

		var initial_direction: Vector2 = (
			next_position - current_position
		)


		if initial_direction.length_squared() > 0.001:

			update_facing(
				initial_direction.normalized()
			)


# ============================================================
# FIND PLAYER
# ============================================================

func find_player() -> void:

	if player != null:
		return


	var found_player: Node = (
		get_tree().get_first_node_in_group("player")
	)


	if found_player is Node2D:

		player = found_player as Node2D


# ============================================================
# FACING
# ============================================================

func update_facing(direction: Vector2) -> void:

	if direction.length_squared() <= 0.001:
		return


	facing_direction = direction.normalized()


	# Keep the existing horizontal sprite flipping.
	sprite.flip_h = facing_direction.x < 0.0


# ============================================================
# PLAYER HIDDEN CHECK
# ============================================================

func player_is_hidden() -> bool:

	if player == null:
		return false


	if player.has_method("is_hidden"):

		return player.is_hidden()


	return false


# ============================================================
# DISTANCE CHECK
# ============================================================

func player_is_within_range(range_value: float) -> bool:

	if player == null:
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
# LINE OF SIGHT
# ============================================================

func has_line_of_sight() -> bool:

	if player == null:
		return false


	if player_is_hidden():
		return false


	# Convert player's global position into
	# VisionRay's local coordinate system.
	var target_position: Vector2 = (
		vision_ray.to_local(
			player.global_position
		)
	)


	vision_ray.target_position = target_position

	vision_ray.force_raycast_update()


	if not vision_ray.is_colliding():

		return false


	var collider: Object = (
		vision_ray.get_collider()
	)


	# Direct hit on player.
	if collider == player:

		return true


	# Some setups may have the player represented
	# through a child collision object.
	if collider is Node:

		var collider_node: Node = collider as Node


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
# FOV CHECK
# ============================================================

func player_inside_fov() -> bool:

	if player == null:
		return false


	var to_player: Vector2 = (
		player.global_position
		- global_position
	)


	if to_player.length_squared() <= 0.001:

		return true


	var direction_to_player: Vector2 = (
		to_player.normalized()
	)


	var half_angle: float = deg_to_rad(
		vision_angle * 0.5
	)


	var vision_angle_difference: float = abs(
		facing_direction.angle_to(
			direction_to_player
		)
	)


	return vision_angle_difference <= half_angle


# ============================================================
# INITIAL DETECTION
#
# Used ONLY while patrolling/searching.
#
# Requires:
# Range
# FOV
# LOS
# ============================================================

func can_detect_player() -> bool:

	if player == null:
		return false


	if player_is_hidden():
		return false


	if not player_is_within_range(
		vision_range
	):

		return false


	if not player_inside_fov():

		return false


	if not has_line_of_sight():

		return false


	return true


# ============================================================
# CHASE TRACKING
#
# IMPORTANT:
# During chase we DON'T require FOV.
#
# This prevents the Skull from stopping simply because
# CT moves slightly to the side.
# ============================================================

func can_track_player() -> bool:

	if player == null:
		return false


	if player_is_hidden():
		return false


	if not player_is_within_range(
		chase_range
	):

		return false


	if not has_line_of_sight():

		return false


	return true


# ============================================================
# START CHASE
# ============================================================

func start_chase() -> void:

	state = State.CHASE

	lost_sight_timer = 0.0

	search_reached_position = false

	velocity = Vector2.ZERO

	if player != null:

		last_seen_position = (
			player.global_position
		)

	print("%s CHASE CT" % name)


# ============================================================
# START SEARCH
# ============================================================

func start_search() -> void:

	state = State.SEARCH

	search_timer = search_duration
	search_reached_position = false
	lost_sight_timer = 0.0

	# IMPORTANT:
	# Stop immediately when CT disappears.
	velocity = Vector2.ZERO

	# Face the position where CT was last seen.
	if player != null:
		last_seen_position = player.global_position

	var direction_to_last_seen: Vector2 = (
		global_position.direction_to(
			last_seen_position
		)
	)

	if direction_to_last_seen.length_squared() > 0.001:

		update_facing(
			direction_to_last_seen.normalized()
		)

	print(
		"%s lost CT - searching last known position"
		% name
	)


# ============================================================
# START PATROL
# ============================================================

func start_patrol() -> void:

	state = State.PATROL

	search_reached_position = false
	lost_sight_timer = 0.0

	velocity = Vector2.ZERO


	# --------------------------------------------------------
	# Re-sync patrol progress with the Skull's ACTUAL position.
	# This prevents snapping back to an old patrol position.
	# --------------------------------------------------------

	if patrol_path == null:
		return

	var curve: Curve2D = patrol_path.curve

	if curve == null:
		return

	path_progress = curve.get_closest_offset(
		patrol_path.to_local(
			global_position
		)
	)


	# Make sure the Skull continues facing its movement direction.
	var path_length: float = curve.get_baked_length()

	if path_length <= 0.0:
		return


	var look_ahead: float = 10.0

	var current_progress: float = clamp(
		path_progress,
		0.0,
		path_length
	)

	var next_progress: float = clamp(
		current_progress
		+ look_ahead * patrol_direction,
		0.0,
		path_length
	)


	var current_local: Vector2 = (
		curve.sample_baked(
			current_progress
		)
	)

	var next_local: Vector2 = (
		curve.sample_baked(
			next_progress
		)
	)


	var current_world: Vector2 = (
		patrol_path.to_global(
			current_local
		)
	)

	var next_world: Vector2 = (
		patrol_path.to_global(
			next_local
		)
	)


	var direction: Vector2 = (
		next_world - current_world
	)


	if direction.length_squared() > 0.001:

		update_facing(
			direction.normalized()
		)


# ============================================================
# PHYSICS
# ============================================================

func _physics_process(delta: float) -> void:

	find_player()


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

	# ========================================================
	# CHECK PLAYER
	# ========================================================

	if player != null:

		var detected: bool = can_detect_player()

		if detected:

			was_seeing_player = true

			start_chase()

			return

		was_seeing_player = false


	# ========================================================
	# PATROL PATH
	# ========================================================

	if patrol_path == null:
		velocity = Vector2.ZERO
		return


	var curve: Curve2D = patrol_path.curve

	if curve == null:
		velocity = Vector2.ZERO
		return


	var path_length: float = (
		curve.get_baked_length()
	)

	if path_length <= 0.0:
		velocity = Vector2.ZERO
		return


	# ========================================================
	# ADVANCE PATH PROGRESS
	# ========================================================

	path_progress += (
		patrol_speed
		* patrol_direction
		* delta
	)


	# ========================================================
	# PATH END
	# ========================================================

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

			velocity = Vector2.ZERO

			return


		if path_progress <= 0.0:

			path_progress = 0.0

			velocity = Vector2.ZERO

			return


	# ========================================================
	# GET TARGET POINT ON PATH
	# ========================================================

	var target_local_position: Vector2 = (
		curve.sample_baked(
			path_progress
		)
	)


	var target_world_position: Vector2 = (
		patrol_path.to_global(
			target_local_position
		)
	)


	# ========================================================
	# MOVE PHYSICALLY TOWARD PATH POINT
	# ========================================================

	var direction: Vector2 = (
		global_position.direction_to(
			target_world_position
		)
	)


	if direction.length_squared() <= 0.0001:

		velocity = Vector2.ZERO

	else:

		update_facing(direction)

		velocity = direction * patrol_speed

		move_and_slide()


# ============================================================
# CHASE
# ============================================================

func update_chase(delta: float) -> void:

	if player == null:

		start_patrol()

		return


	# ========================================================
	# PLAYER HIDES
	# ========================================================

	if player_is_hidden():

		last_seen_position = player.global_position

		start_search()

		return


	# ========================================================
	# STILL TRACKING PLAYER
	# ========================================================

	var tracking_player: bool = can_track_player()

	if tracking_player:

		lost_sight_timer = 0.0

		last_seen_position = player.global_position


		var direction: Vector2 = (
			global_position.direction_to(
				player.global_position
			)
		)


		update_facing(direction)

		velocity = direction * chase_speed

		move_and_slide()

		return


	# ========================================================
	# LOST SIGHT
	# ========================================================

	lost_sight_timer += delta


	# Small grace period.
	#
	# Skull continues toward the last known position,
	# but does NOT keep its previous velocity.
	#
	# This prevents the "floating" feeling.
	if lost_sight_timer < lose_sight_grace:

		var direction_to_last_seen: Vector2 = (
			global_position.direction_to(
				last_seen_position
			)
		)


		if direction_to_last_seen.length_squared() > 0.001:

			update_facing(
				direction_to_last_seen.normalized()
			)

			velocity = (
				direction_to_last_seen
				* chase_speed
			)

			move_and_slide()

		else:

			velocity = Vector2.ZERO

		return


	# ========================================================
	# COMPLETELY LOST PLAYER
	# ========================================================

	start_search()


# ============================================================
# SEARCH
# ============================================================

func update_search(delta: float) -> void:

	if player == null:

		start_patrol()

		return


	# ========================================================
	# CT REAPPEARED
	# ========================================================

	if can_detect_player():

		start_chase()

		return


	# ========================================================
	# SEARCH TIMER
	# ========================================================

	search_timer -= delta


	# ========================================================
	# MOVE TO LAST KNOWN POSITION
	# ========================================================

	if not search_reached_position:

		var direction: Vector2 = (
			global_position.direction_to(
				last_seen_position
			)
		)


		var distance_to_last_seen: float = (
			global_position.distance_to(
				last_seen_position
			)
		)


		if distance_to_last_seen > search_arrival_distance:

			update_facing(direction)

			velocity = (
				direction
				* search_speed
			)

			move_and_slide()

			return


		# Reached last known position.
		velocity = Vector2.ZERO

		search_reached_position = true

		print(
			"%s reached last known position"
			% name
		)

		return


	# ========================================================
	# LOOK AROUND
	# ========================================================

	velocity = Vector2.ZERO

	look_around(delta)


	# ========================================================
	# SEARCH FINISHED
	# ========================================================

	if search_timer <= 0.0:

		print(
			"%s gave up searching"
			% name
		)

		start_patrol()
		
		
func look_around(delta: float) -> void:

	# How quickly the Skull turns.
	var look_speed: float = 2.5

	# Rotate the vision direction.
	facing_direction = facing_direction.rotated(
		look_speed * delta
	).normalized()

	# Keep sprite facing approximately toward movement/
	# horizontal direction.
	sprite.flip_h = facing_direction.x < 0.0
