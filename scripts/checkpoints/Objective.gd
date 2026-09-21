extends Node


signal objective_completed
signal progress_changed(coins_collected: int, required_coins: int)


@export var required_coins: int = 20
@export var require_exit: bool = true


var coins_collected: int = 0
var exit_reached: bool = false
var completed: bool = false


func start() -> void:
	coins_collected = 0
	exit_reached = false
	completed = false

	progress_changed.emit(
		coins_collected,
		required_coins
	)


func add_coins(amount: int) -> void:
	if completed:
		return

	if amount <= 0:
		return

	coins_collected += amount

	if coins_collected > required_coins:
		coins_collected = required_coins

	progress_changed.emit(
		coins_collected,
		required_coins
	)

	_check_completion()


func reach_exit() -> void:
	if completed:
		return

	exit_reached = true

	_check_completion()


func is_coin_objective_complete() -> bool:
	return coins_collected >= required_coins


func is_exit_requirement_complete() -> bool:
	return not require_exit or exit_reached


func is_complete() -> bool:
	return is_coin_objective_complete() and is_exit_requirement_complete()


func _check_completion() -> void:
	if completed:
		return

	if not is_coin_objective_complete():
		return

	if not is_exit_requirement_complete():
		return

	completed = true

	print(
		"Objective completed: %d/%d coins"
		% [
			coins_collected,
			required_coins
		]
	)

	objective_completed.emit()
