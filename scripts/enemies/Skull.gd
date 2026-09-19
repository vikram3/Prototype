class_name Skull
extends Enemy

@export var patrol_path: Path2D
@export var patrol_speed: float = 60.0
@export var loop_path: bool = true

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


func _physics_process(delta: float) -> void:
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
