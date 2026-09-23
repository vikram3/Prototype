extends Node
## CP02 60-second chase controller.
## Child of CP02 checkpoint root.

signal chase_started
signal time_changed(seconds_left: float)
signal checkpoint_won(reason: String)
signal checkpoint_failed

@export_category("CP02 Timer")
@export var duration: float = 60.0
@export var start_on_ready: bool = true

@export_category("References")
@export var timer_label: Label
@export var chest_goal: Area2D

@export_category("Display")
@export var show_decimal: bool = false

var time_left: float = 0.0
var running: bool = false
var finished: bool = false


func _ready() -> void:
	if chest_goal != null:
		if not chest_goal.body_entered.is_connected(_on_chest_body_entered):
			chest_goal.body_entered.connect(_on_chest_body_entered)

	if start_on_ready:
		start()


func _process(delta: float) -> void:
	if not running or finished:
		return

	time_left = maxf(time_left - delta, 0.0)
	time_changed.emit(time_left)
	_update_label()

	if time_left <= 0.0:
		_win("timer_survived")


func start() -> void:
	if finished:
		return

	time_left = duration
	running = true
	_update_label()
	chase_started.emit()


func stop() -> void:
	running = false


func _on_chest_body_entered(body: Node2D) -> void:
	if finished:
		return

	if not body.is_in_group("player"):
		return

	_win("treasure_reached")


func _win(reason: String) -> void:
	if finished:
		return

	finished = true
	running = false

	_update_label()
	checkpoint_won.emit(reason)

	var manager: Node = get_node_or_null(
		"/root/CheckpointManager"
	) as Node

	if manager != null:
		if manager.has_method("complete_checkpoint"):
			manager.complete_checkpoint()
		elif manager.has_method("checkpoint_completed"):
			manager.checkpoint_completed()


func _update_label() -> void:
	if timer_label == null:
		return

	var seconds: float = ceil(time_left)

	if show_decimal:
		timer_label.text = "TIME  %.1f" % time_left
	else:
		timer_label.text = "TIME  %02d" % int(seconds)

	if time_left <= 10.0:
		timer_label.modulate = Color(
			1.0,
			0.35,
			0.35,
			1.0
		)
	else:
		timer_label.modulate = Color.WHITE
