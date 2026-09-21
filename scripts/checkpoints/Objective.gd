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

	progress_changed.emit(coins_collected, required_coins)


func add_coins(amount: int) -> void:
	if completed:
		return

	coins_collected += amount

	progress_changed.emit(coins_collected, required_coins)

	_check_completion()


func reach_exit() -> void:
	if completed:
		return

	exit_reached = true

	_check_completion()


func _check_completion() -> void:
	if completed:
		return

	var coins_complete := coins_collected >= required_coins
	var exit_complete := not require_exit or exit_reached

	if not coins_complete:
		return

	if not exit_complete:
		return

	completed = true

	objective_completed.emit()
