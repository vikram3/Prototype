extends Node

const SAVE_PATH: String = "user://savegame.json"

var highest_checkpoint: int = 1


func save_game() -> void:
	print("========================================")
	print("SAVE GAME")
	print("Path: ", SAVE_PATH)
	print("Highest Checkpoint: ", highest_checkpoint)
	print("========================================")

	var data: Dictionary = {
		"highest_checkpoint": highest_checkpoint
	}

	var file: FileAccess = FileAccess.open(
		SAVE_PATH,
		FileAccess.WRITE
	)

	if file == null:
		push_error("Could not open save file for writing.")
		return

	file.store_string(JSON.stringify(data))
	file.close()

	print("SAVE SUCCESS")


func load_game() -> void:
	print("========================================")
	print("LOAD GAME")
	print("Path: ", SAVE_PATH)
	print("========================================")

	if not FileAccess.file_exists(SAVE_PATH):
		highest_checkpoint = 1
		print("No save file found.")
		print("Starting from Checkpoint 01")
		return

	var file: FileAccess = FileAccess.open(
		SAVE_PATH,
		FileAccess.READ
	)

	if file == null:
		highest_checkpoint = 1
		push_error("Could not open save file.")
		return

	var text: String = file.get_as_text()
	file.close()

	print("SAVE DATA: ", text)

	var json: JSON = JSON.new()

	if json.parse(text) != OK:
		highest_checkpoint = 1
		push_error("Save file is invalid.")
		return

	var data: Variant = json.data

	if typeof(data) != TYPE_DICTIONARY:
		highest_checkpoint = 1
		push_error("Save data is not a Dictionary.")
		return

	var dictionary: Dictionary = data as Dictionary

	highest_checkpoint = max(
		1,
		int(dictionary.get("highest_checkpoint", 1))
	)

	print(
		"Loaded save. Highest checkpoint: %02d"
		% highest_checkpoint
	)
