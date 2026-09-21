extends Node

var current_checkpoint: int = 1
var highest_checkpoint: int = 1
var coins_collected: int = 0
var checkpoint_completed: bool = false


func _ready() -> void:
	SaveManager.load_game()
	highest_checkpoint = SaveManager.highest_checkpoint


func start_checkpoint(checkpoint_number: int) -> void:
	current_checkpoint = checkpoint_number
	coins_collected = 0
	checkpoint_completed = false

	print(
		"Starting Checkpoint %02d" % current_checkpoint
	)


func add_coins(amount: int) -> void:
	if checkpoint_completed:
		return

	coins_collected += amount

	print(
		"Coins: %d" % coins_collected
	)


func complete_checkpoint() -> void:
	if checkpoint_completed:
		return

	checkpoint_completed = true

	var unlocked_checkpoint := current_checkpoint + 1

	if unlocked_checkpoint > highest_checkpoint:
		highest_checkpoint = unlocked_checkpoint
		SaveManager.highest_checkpoint = highest_checkpoint
		SaveManager.save_game()

	print(
		"Checkpoint %02d completed." % current_checkpoint
	)

	print(
		"Highest checkpoint: %02d" % highest_checkpoint
	)


func restart_checkpoint() -> void:
	print(
		"Restarting Checkpoint %02d" % current_checkpoint
	)

	Engine.time_scale = 1.0

	get_tree().reload_current_scene()
