extends Node

signal objective_completed
signal progress_changed(coins_collected: int, required_coins: int)

@export var required_coins: int = 5
@export var require_exit: bool = true

var coins_collected: int = 0
var exit_reached: bool = false
var completed: bool = false


func start() -> void:
	coins_collected = 0
	exit_reached = false
	completed = false

	print("========================================")
	print("OBJECTIVE START")
	print("Required Coins: ", required_coins)
	print("Require Exit: ", require_exit)
	print("========================================")

	progress_changed.emit(
		coins_collected,
		required_coins
	)


func add_coins(amount: int) -> void:
	if completed:
		print("OBJECTIVE: Ignoring coins because objective is already complete")
		return

	if amount <= 0:
		print("OBJECTIVE: Ignoring invalid coin amount: ", amount)
		return

	coins_collected += amount

	if coins_collected > required_coins:
		coins_collected = required_coins

	print("========================================")
	print("OBJECTIVE COIN")
	print("Added: ", amount)
	print("Progress: %d / %d" % [coins_collected, required_coins])
	print("Exit Reached: ", exit_reached)
	print("Require Exit: ", require_exit)
	print("========================================")

	progress_changed.emit(
		coins_collected,
		required_coins
	)

	_check_completion()


func reach_exit() -> void:
	if completed:
		print("OBJECTIVE: Exit reached but objective is already complete")
		return

	exit_reached = true

	print("========================================")
	print("OBJECTIVE EXIT REACHED")
	print("Coins: %d / %d" % [coins_collected, required_coins])
	print("Exit Reached: ", exit_reached)
	print("========================================")

	_check_completion()


func is_coin_objective_complete() -> bool:
	return coins_collected >= required_coins


func is_exit_requirement_complete() -> bool:
	return not require_exit or exit_reached


func is_complete() -> bool:
	return (
		is_coin_objective_complete()
		and is_exit_requirement_complete()
	)


func _check_completion() -> void:
	if completed:
		return

	var coins_complete: bool = is_coin_objective_complete()
	var exit_complete: bool = is_exit_requirement_complete()

	print("OBJECTIVE CHECK")
	print("Coins Complete: ", coins_complete)
	print("Exit Complete: ", exit_complete)

	if not coins_complete:
		print("OBJECTIVE NOT COMPLETE: Not enough coins")
		return

	if not exit_complete:
		print("OBJECTIVE NOT COMPLETE: Exit not reached")
		return

	completed = true

	print("========================================")
	print("OBJECTIVE COMPLETED")
	print("Coins: %d / %d" % [coins_collected, required_coins])
	print("Exit Reached: ", exit_reached)
	print("========================================")

	objective_completed.emit()
