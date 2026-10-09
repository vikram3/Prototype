extends Control
## Checkpoint intro screen, shown before every checkpoint.
## Layout lives in scenes/ui/CheckpointIntro.tscn.

@onready var number_label: Label = $Center/VBox/NumberLabel
@onready var name_label: Label = $Center/VBox/NameLabel
@onready var start_button: Button = $Center/VBox/StartButton
@onready var back_button: Button = $Center/VBox/BackButton


func _ready() -> void:
	get_tree().paused = false

	var number := Flow.checkpoint
	number_label.text = "CHECKPOINT %d" % number
	name_label.text = CheckpointManager.title_for(number)

	start_button.pressed.connect(Flow.start_checkpoint.bind(number))
	back_button.pressed.connect(Flow.show_menu.bind("select"))

	start_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Flow.show_menu("select")
