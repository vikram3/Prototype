extends Control
## Settings screen. Layout lives in scenes/ui/Settings.tscn.

@onready var fullscreen_check: CheckButton = $Center/VBox/FullscreenCheck
@onready var volume_label: Label = $Center/VBox/VolumeLabel
@onready var volume_slider: HSlider = $Center/VBox/VolumeSlider
@onready var back_button: Button = $Center/VBox/BackButton


func _ready() -> void:
	get_tree().paused = false

	fullscreen_check.button_pressed = Flow.fullscreen
	volume_slider.value = Flow.master_volume
	_update_volume_label()

	fullscreen_check.toggled.connect(Flow.set_fullscreen)
	volume_slider.value_changed.connect(_on_volume_changed)
	back_button.pressed.connect(Flow.show_menu.bind(Flow.return_screen))

	fullscreen_check.grab_focus()


func _on_volume_changed(value: float) -> void:
	Flow.set_master_volume(value)
	_update_volume_label()


func _update_volume_label() -> void:
	volume_label.text = "Master Volume: %d%%" % roundi(Flow.master_volume * 100.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Flow.show_menu(Flow.return_screen)
