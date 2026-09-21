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


func add_coins(amount: int) -> void:
	if checkpoint_completed:
		return

	coins_collected += amount


func complete_checkpoint() -> void:
	if checkpoint_completed:
		return

	checkpoint_completed = true

	var next_checkpoint := current_checkpoint + 1

	if next_checkpoint > highest_checkpoint:
		highest_checkpoint = next_checkpoint

		SaveManager.highest_checkpoint = highest_checkpoint
		SaveManager.save_game()



func restart_checkpoint() -> void:
	Engine.time_scale = 1.0

	get_tree().reload_current_scene()
