extends Node

const SAVE_PATH := "user://savegame.json"

var highest_checkpoint: int = 1


func save_game() -> void:
	var data := {
		"highest_checkpoint": highest_checkpoint
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if file == null:
		push_error("Could not open save file for writing.")
		return

	file.store_string(JSON.stringify(data))
	file.close()

	print("Game saved. Highest checkpoint: %02d" % highest_checkpoint)


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		highest_checkpoint = 1
		print("No save file found. Starting from Checkpoint 01.")
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)

	if file == null:
		highest_checkpoint = 1
		return

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()

	if json.parse(text) != OK:
		highest_checkpoint = 1
		push_error("Save file is invalid.")
		return

	var data: Variant = json.data

	if typeof(data) != TYPE_DICTIONARY:
		highest_checkpoint = 1
		return

	highest_checkpoint = max(
		1,
		int(data.get("highest_checkpoint", 1))
	)

	print(
		"Loaded save. Highest checkpoint: %02d"
		% highest_checkpoint
	)
