extends CanvasLayer
## Pause overlay. Autoload scene scenes/ui/PauseMenu.tscn.
## Escape toggles it, but only inside a real checkpoint (a scene with an
## "Objective" node). Layout lives in the scene; this script wires it.

@onready var panel: Control = $Panel
@onready var resume_button: Button = $Panel/Center/VBox/ResumeButton
@onready var restart_button: Button = $Panel/Center/VBox/RestartButton
@onready var checkpoints_button: Button = $Panel/Center/VBox/CheckpointsButton
@onready var quit_button: Button = $Panel/Center/VBox/QuitButton

var is_open: bool = false


func _ready() -> void:
	panel.visible = false
	resume_button.pressed.connect(_close)
	restart_button.pressed.connect(_on_restart_pressed)
	checkpoints_button.pressed.connect(_on_checkpoints_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	if GameUI.is_complete_screen_visible():
		return

	var scene := get_tree().current_scene
	if scene == null or not scene.has_node("Objective"):
		return

	if is_open:
		_close()
	else:
		_open()


func _open() -> void:
	is_open = true
	panel.visible = true
	get_tree().paused = true
	resume_button.grab_focus()


func _close() -> void:
	is_open = false
	panel.visible = false
	get_tree().paused = false


func _on_restart_pressed() -> void:
	_close()
	CheckpointManager.restart_checkpoint()


func _on_checkpoints_pressed() -> void:
	_close()
	Flow.show_menu("select")


func _on_quit_pressed() -> void:
	_close()
	Flow.show_menu("title")
