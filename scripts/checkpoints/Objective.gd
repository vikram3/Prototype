extends Node

signal objective_completed
signal progress_changed(current: int, target: int)


enum ObjectiveType {
	COINS,
	EXIT,
	COINS_OR_EXIT,
	COINS_AND_EXIT,
	SURVIVE_TIME,
	DEFEAT_COUNT,
	EVENT
}


@export_category("Objective")

@export_enum(
	"Coins",
	"Exit",
	"Coins OR Exit",
	"Coins AND Exit",
	"Survive Time",
	"Defeat Count",
	"Event"
)
var objective_type: int = ObjectiveType.COINS_OR_EXIT


@export_category("Target")

@export var required_coins: int = 20
@export var required_defeats: int = 0
@export var survive_time: float = 0.0


var coins_collected: int = 0
var defeats: int = 0
var exit_reached: bool = false
var elapsed_time: float = 0.0
var event_triggered: bool = false

var completed: bool = false
var started: bool = false


func _process(delta: float) -> void:
	if not started:
		return

	if completed:
		return

	if objective_type == ObjectiveType.SURVIVE_TIME:
		elapsed_time += delta

		if elapsed_time >= survive_time:
			elapsed_time = survive_time
			_complete()
			return

		progress_changed.emit(
			int(elapsed_time),
			int(survive_time)
		)


func start() -> void:
	coins_collected = 0
	defeats = 0
	exit_reached = false
	elapsed_time = 0.0
	event_triggered = false

	completed = false
	started = true

	_emit_progress()
	_check_completion()


func add_coins(amount: int) -> void:
	if completed:
		return

	if amount <= 0:
		return

	coins_collected += amount

	if required_coins > 0:
		coins_collected = min(
			coins_collected,
			required_coins
		)

	_emit_progress()
	_check_completion()


func reach_exit() -> void:
	if completed:
		return

	exit_reached = true

	_emit_progress()
	_check_completion()


func add_defeat(amount: int = 1) -> void:
	if completed:
		return

	if amount <= 0:
		return

	defeats += amount

	if required_defeats > 0:
		defeats = min(
			defeats,
			required_defeats
		)

	_emit_progress()
	_check_completion()


func trigger_event() -> void:
	if completed:
		return

	event_triggered = true

	_emit_progress()
	_check_completion()


func is_coin_objective_complete() -> bool:
	return (
		required_coins <= 0
		or coins_collected >= required_coins
	)


func is_exit_requirement_complete() -> bool:
	return exit_reached


func is_defeat_objective_complete() -> bool:
	return (
		required_defeats <= 0
		or defeats >= required_defeats
	)


func is_complete() -> bool:
	if completed:
		return true

	match objective_type:
		ObjectiveType.COINS:
			return is_coin_objective_complete()

		ObjectiveType.EXIT:
			return exit_reached

		ObjectiveType.COINS_OR_EXIT:
			return (
				is_coin_objective_complete()
				or exit_reached
			)

		ObjectiveType.COINS_AND_EXIT:
			return (
				is_coin_objective_complete()
				and exit_reached
			)

		ObjectiveType.SURVIVE_TIME:
			return (
				survive_time <= 0.0
				or elapsed_time >= survive_time
			)

		ObjectiveType.DEFEAT_COUNT:
			return is_defeat_objective_complete()

		ObjectiveType.EVENT:
			return event_triggered

	return false


func _check_completion() -> void:
	if completed:
		return

	if not is_complete():
		return

	_complete()


func _complete() -> void:
	if completed:
		return

	completed = true
	started = false

	objective_completed.emit()


func _emit_progress() -> void:
	match objective_type:
		ObjectiveType.COINS:
			progress_changed.emit(
				coins_collected,
				required_coins
			)

		ObjectiveType.EXIT:
			progress_changed.emit(
				1 if exit_reached else 0,
				1
			)

		ObjectiveType.COINS_OR_EXIT:
			progress_changed.emit(
				coins_collected,
				required_coins
			)

		ObjectiveType.COINS_AND_EXIT:
			progress_changed.emit(
				coins_collected,
				required_coins
			)

		ObjectiveType.SURVIVE_TIME:
			progress_changed.emit(
				int(elapsed_time),
				int(survive_time)
			)

		ObjectiveType.DEFEAT_COUNT:
			progress_changed.emit(
				defeats,
				required_defeats
			)

		ObjectiveType.EVENT:
			progress_changed.emit(
				1 if event_triggered else 0,
				1
			)
