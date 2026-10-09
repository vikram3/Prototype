extends Node

var current_checkpoint: int = 1
var highest_checkpoint: int = 1
var coins_collected: int = 0
var checkpoint_completed: bool = false
var intro_seen: Dictionary = {}

const TITLES := {
	1: "Chapter 1 -- The Bush Maze",
	2: "Chapter 1 -- The Treasure Chase",
	3: "Chapter 2 -- Shadow Avatars",
	4: "Chapter 2 -- Big Boss Attacks",
	5: "Chapter 2 -- Pink Girl's Stand",
	6: "Chapter 3 -- Cliffside Ambush",
	7: "Chapter 3 -- The Forest Path",
	8: "Chapter 4 -- Horn's Pursuit",
	9: "Chapter 4 -- Barreldugo Taming",
	10: "Chapter 5 -- Charging Bulls",
	11: "Chapter 5 -- Warm-Up Battle",
	12: "Chapter 6 -- Big Bird Duel",
	13: "Chapter 6 -- Debris Scramble",
	14: "Chapter 7 -- Victory Coin Rush",
	15: "Chapter 7 -- The Sinking Deck",
	16: "Chapter 8 -- Sand Land Arrival",
	17: "Chapter 8 -- The Mayor's Contract",
	18: "Chapter 8 -- Wormfish Chase",
}


func title_for(number: int) -> String:
	return String(TITLES.get(number, ""))


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
