class_name Skull
extends Enemy

@export var patrol_path: Path2D
@export var patrol_speed: float = 60.0
@export var loop_path: bool = true
@export var vision_range: float = 500.0

@onready var vision_ray: RayCast2D = $VisionRay

@export var vision_angle: float = 100.0

var was_seeing_player: bool = false

var search_reached_position: bool = false

enum State {
	PATROL,
	CHASE,
	SEARCH
}

var state: State = State.PATROL

var last_seen_position: Vector2 = Vector2.ZERO
@export var search_duration: float = 2.5
var search_timer: float = 0.0

var player: Node2D = null

var path_progress: float = 0.0
var patrol_direction: float = 1.0


func _ready() -> void:
	if patrol_path == null:
		push_error("%s has no patrol path assigned." % name)
		return

	var curve := patrol_path.curve

	if curve == null:
		push_error("%s patrol path has no Curve2D." % name)
		return

	path_progress = curve.get_closest_offset(
		patrol_path.to_local(global_position)
	)


func find_player() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")


func can_see_player() -> bool:
	if player == null:
		return false

	if global_position.distance_to(player.global_position) > vision_range:
		return false

	vision_ray.target_position = vision_ray.to_local(
		player.global_position
	)

	vision_ray.force_raycast_update()

	if not vision_ray.is_colliding():
		return false

	var collider := vision_ray.get_collider()
	
	return collider == player


func _physics_process(delta: float) -> void:
	find_player()

	var seeing_player := can_see_player()

	if seeing_player and not was_seeing_player:
		print("%s sees CT!" % name)
		state = State.CHASE

	elif not seeing_player and was_seeing_player:
		print("%s lost sight of CT." % name)

		if player != null:
			last_seen_position = player.global_position

		search_timer = search_duration
		search_reached_position = false
		state = State.SEARCH

	was_seeing_player = seeing_player

	# -------------------------
	# CHASE
	# -------------------------
	if state == State.CHASE:
		if player == null:
			state = State.PATROL
			return

		if can_see_player():
			var direction := global_position.direction_to(
				player.global_position
			)

			velocity = direction * patrol_speed
			$Sprite2D.flip_h = direction.x < 0
			move_and_slide()
			return
		else:
			if player != null:
				last_seen_position = player.global_position

			search_timer = search_duration
			state = State.SEARCH

	# -------------------------
	# SEARCH
	# -------------------------
	if state == State.SEARCH:
		search_timer -= delta

		if not search_reached_position:
			var direction := global_position.direction_to(
				last_seen_position
			)

			if global_position.distance_to(last_seen_position) > 10.0:
				velocity = direction * patrol_speed
				move_and_slide()
			else:
				velocity = Vector2.ZERO
				search_reached_position = true

		else:
			velocity = Vector2.ZERO

		if can_see_player():
			state = State.CHASE
			search_reached_position = false
			return

		if search_timer <= 0.0:
			state = State.PATROL
			search_reached_position = false
			velocity = Vector2.ZERO

	# -------------------------
	# PATROL
	# -------------------------
	if state != State.PATROL:
		return

	if patrol_path == null:
		return

	var curve := patrol_path.curve

	if curve == null:
		return

	var path_length := curve.get_baked_length()

	if path_length <= 0.0:
		return

	path_progress += patrol_speed * patrol_direction * delta

	if loop_path:
		if path_progress >= path_length:
			path_progress = path_length
			patrol_direction = -1.0

		elif path_progress <= 0.0:
			path_progress = 0.0
			patrol_direction = 1.0

	else:
		path_progress = clamp(
			path_progress,
			0.0,
			path_length
		)

	var local_position := curve.sample_baked(path_progress)

	global_position = patrol_path.to_global(local_position)
