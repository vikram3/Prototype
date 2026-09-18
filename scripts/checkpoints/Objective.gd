extends Node

signal objective_completed
signal progress_changed(current: int, required: int)

enum CompletionMode {
	AND,
	OR
}

@export var required_coins: int = 0
@export var require_exit: bool = false
@export var completion_mode: CompletionMode = CompletionMode.AND

var coins_collected: int = 0
var exit_reached: bool = false
var completed: bool = false


func start() -> void:
	coins_collected = 0
	exit_reached = false
	completed = false


func add_coins(amount: int) -> void:
	if completed:
		return

	coins_collected += amount

	progress_changed.emit(
		coins_collected,
		required_coins
	)

	check_completion()


func reach_exit() -> void:
	if completed:
		return

	exit_reached = true

	check_completion()


func check_completion() -> void:
	if completed:
		return

	var coin_requirement_met := (
		required_coins <= 0
		or coins_collected >= required_coins
	)

	var exit_requirement_met := (
		not require_exit
		or exit_reached
	)

	var should_complete := false

	if completion_mode == CompletionMode.AND:
		should_complete = (
			coin_requirement_met
			and exit_requirement_met
		)

	elif completion_mode == CompletionMode.OR:
		should_complete = (
			coin_requirement_met
			or exit_requirement_met
		)

	if should_complete:
		completed = true
		objective_completed.emit()
