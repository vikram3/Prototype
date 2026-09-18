class_name Skull
extends Enemy

@export var patrol_path: Path2D
@export var patrol_speed: float = 60.0
@export var loop_path: bool = true

var path_progress: float = 0.0


func _ready() -> void:
	if patrol_path == null:
		push_error("%s has no patrol path assigned." % name)
		return

	path_progress = patrol_path.curve.get_closest_offset(
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

	path_progress += patrol_speed * delta

	if loop_path:
		path_progress = fmod(
			path_progress,
			path_length
		)
	else:
		path_progress = min(
			path_progress,
			path_length
		)

	var local_position := curve.sample_baked(
		path_progress
	)

	global_position = patrol_path.to_global(
		local_position
	)
