extends Node

var current_checkpoint: int = 1
var highest_checkpoint: int = 1

var coins_collected: int = 0


func _ready() -> void:
	highest_checkpoint = SaveManager.highest_checkpoint


func start_checkpoint(checkpoint_number: int) -> void:
	current_checkpoint = checkpoint_number
	coins_collected = 0

	print(
		"Starting Checkpoint %02d" % current_checkpoint
	)


func add_coins(amount: int) -> void:
	coins_collected += amount

	print(
		"Coins: %d" % coins_collected
	)


func complete_checkpoint() -> void:
	if current_checkpoint >= highest_checkpoint:
		highest_checkpoint = current_checkpoint + 1

		SaveManager.highest_checkpoint = highest_checkpoint
		SaveManager.save_game()

	print(
		"Checkpoint %02d completed." % current_checkpoint
	)


func restart_checkpoint() -> void:
	print(
		"Restarting Checkpoint %02d" % current_checkpoint
	)
