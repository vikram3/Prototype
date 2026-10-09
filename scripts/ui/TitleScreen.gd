extends Control
## Title screen. Layout and text live in scenes/ui/TitleScreen.tscn.
## This script only wires the buttons to Flow.

@onready var start_button: Button = $Center/VBox/StartButton
@onready var continue_button: Button = $Center/VBox/ContinueButton
@onready var settings_button: Button = $Center/VBox/SettingsButton
@onready var quit_button: Button = $Center/VBox/QuitButton


func _ready() -> void:
	get_tree().paused = false

	var last := Flow.highest_unlocked()
	continue_button.disabled = not Flow.checkpoint_exists(last)

	start_button.pressed.connect(Flow.show_menu.bind("select"))
	continue_button.pressed.connect(Flow.show_menu.bind("intro", last))
	settings_button.pressed.connect(Flow.go_settings.bind("title"))
	quit_button.pressed.connect(get_tree().quit)

	start_button.grab_focus()
