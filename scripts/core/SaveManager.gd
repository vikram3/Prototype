extends Node

const SAVE_PATH := "user://savegame.json"

var highest_checkpoint: int = 1


func save_game() -> void:
	var data := {
		"highest_checkpoint": highest_checkpoint
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if file:
		file.store_string(JSON.stringify(data))
		file.close()

	print("Game saved.")


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("No save file found.")
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)

	if file == null:
		return

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()

	if json.parse(text) != OK:
		print("Save file is invalid.")
		return

	var data = json.data

	if typeof(data) != TYPE_DICTIONARY:
		return

	highest_checkpoint = int(
		data.get("highest_checkpoint", 1)
	)

	print("Loaded checkpoint: %02d" % highest_checkpoint)
