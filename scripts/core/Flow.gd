extends Node
## Screen flow and settings. Autoload "Flow".
##
## Screen flow and settings. Each menu screen is its own editable scene in
## scenes/ui/ (TitleScreen, CheckpointSelect, CheckpointIntro, Settings).
## Gameplay checkpoints load from scenes/checkpoints/checkpointNN.tscn.

const SCREEN_SCENES := {
	"title": "res://scenes/ui/TitleScreen.tscn",
	"select": "res://scenes/ui/CheckpointSelect.tscn",
	"intro": "res://scenes/ui/CheckpointIntro.tscn",
	"settings": "res://scenes/ui/Settings.tscn",
}
const SETTINGS_PATH := "user://settings.cfg"

var checkpoint: int = 1               # used by the intro screen
var return_screen: String = "title"   # where Back goes from settings
var master_volume: float = 1.0
var fullscreen: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_apply_volume()
	_apply_fullscreen()


func checkpoint_scene_path(number: int) -> String:
	return "res://scenes/checkpoints/checkpoint%02d.tscn" % number


func checkpoint_exists(number: int) -> bool:
	return ResourceLoader.exists(checkpoint_scene_path(number))


func is_unlocked(number: int) -> bool:
	return number <= CheckpointManager.highest_checkpoint and checkpoint_exists(number)


func highest_unlocked() -> int:
	return CheckpointManager.highest_checkpoint


func show_menu(target: String, number: int = 1) -> void:
	get_tree().paused = false
	checkpoint = number
	get_tree().change_scene_to_file(SCREEN_SCENES.get(target, SCREEN_SCENES["title"]))


func go_settings(back_to: String) -> void:
	return_screen = back_to
	show_menu("settings")


func start_checkpoint(number: int) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(checkpoint_scene_path(number))


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_volume()
	_save_settings()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_fullscreen()
	_save_settings()


func _apply_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))


func _apply_fullscreen() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	master_volume = float(cfg.get_value("audio", "master", 1.0))
	fullscreen = bool(cfg.get_value("video", "fullscreen", false))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.save(SETTINGS_PATH)
