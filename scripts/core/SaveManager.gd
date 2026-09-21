extends Node

const SAVE_PATH: String = "user://savegame.json"

var highest_checkpoint: int = 1


func save_game() -> void:


	var data: Dictionary = {
		"highest_checkpoint": highest_checkpoint
	}

	var file: FileAccess = FileAccess.open(
		SAVE_PATH,
		FileAccess.WRITE
	)

	if file == null:
		return

	file.store_string(JSON.stringify(data))
	file.close()



func load_game() -> void:


	if not FileAccess.file_exists(SAVE_PATH):
		highest_checkpoint = 1
		return

	var file: FileAccess = FileAccess.open(
		SAVE_PATH,
		FileAccess.READ
	)

	if file == null:
		highest_checkpoint = 1
		return

	var text: String = file.get_as_text()
	file.close()


	var json: JSON = JSON.new()

	if json.parse(text) != OK:
		highest_checkpoint = 1
		return

	var data: Variant = json.data

	if typeof(data) != TYPE_DICTIONARY:
		highest_checkpoint = 1
		return

	var dictionary: Dictionary = data as Dictionary

	highest_checkpoint = max(
		1,
		int(dictionary.get("highest_checkpoint", 1))
	)
