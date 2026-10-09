extends Control
## Checkpoint select. Buttons Checkpoint01..Checkpoint18 are placed in
## scenes/ui/CheckpointSelect.tscn under Center/VBox/Grid. This script
## fills in the names and locks anything not yet reached.

@onready var grid: GridContainer = $Center/VBox/Grid
@onready var back_button: Button = $Center/VBox/BackButton


func _ready() -> void:
	get_tree().paused = false

	for i in range(grid.get_child_count()):
		var button := grid.get_child(i) as Button
		var number := i + 1
		button.text = "Checkpoint %d -- %s" % [number, CheckpointManager.title_for(number)]
		button.disabled = not Flow.is_unlocked(number)
		button.pressed.connect(Flow.show_menu.bind("intro", number))

	back_button.pressed.connect(Flow.show_menu.bind("title"))
	_focus_first_available()


func _focus_first_available() -> void:
	for child in grid.get_children():
		var button := child as Button
		if button != null and not button.disabled:
			button.grab_focus()
			return
	back_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Flow.show_menu("title")
