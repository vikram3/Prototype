extends CanvasLayer
## PauseMenu autoload.
##
## Escape (ui_cancel) toggles a pause overlay with Resume / Restart
## Level / Quit to Title. Works from any scene that has an
## "Objective" node (i.e. an actual checkpoint, not the title screen).
## Built entirely in code, same approach as GameDebug.gd / GameUI.gd.

var panel: Control
var is_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 900

	_create_ui()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	if GameUI.is_complete_screen_visible():
		return

	var scene := get_tree().current_scene

	if scene == null or not scene.has_node("Objective"):
		return

	_toggle()


func _toggle() -> void:
	if is_open:
		_close()
	else:
		_open()


func _open() -> void:
	is_open = true
	panel.visible = true
	get_tree().paused = true


func _close() -> void:
	is_open = false
	panel.visible = false
	get_tree().paused = false


func _on_resume_pressed() -> void:
	_close()


func _on_restart_pressed() -> void:
	_close()
	CheckpointManager.restart_checkpoint()


func _on_checkpoints_pressed() -> void:
	is_open = false
	panel.visible = false
	Flow.show_menu("select")


func _on_quit_pressed() -> void:
	_close()
	Flow.show_menu("title")


# ============================================================
# UI CONSTRUCTION
# ============================================================

func _create_ui() -> void:
	panel = Control.new()
	panel.name = "PausePanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	add_child(panel)

	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.0, 0.0, 0.0, 0.75)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(background)

	var title := Label.new()
	title.name = "Title"
	title.text = "PAUSED"
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.position = Vector2(-200, -170)
	title.size = Vector2(400, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(title)

	var box := VBoxContainer.new()
	box.name = "Buttons"
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-110, -120)
	box.size = Vector2(220, 240)
	box.process_mode = Node.PROCESS_MODE_ALWAYS
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var resume_button := Button.new()
	resume_button.name = "ResumeButton"
	resume_button.text = "Resume"
	resume_button.process_mode = Node.PROCESS_MODE_ALWAYS
	resume_button.pressed.connect(_on_resume_pressed)
	box.add_child(resume_button)

	var restart_button := Button.new()
	restart_button.name = "RestartButton"
	restart_button.text = "Restart Level"
	restart_button.process_mode = Node.PROCESS_MODE_ALWAYS
	restart_button.pressed.connect(_on_restart_pressed)
	box.add_child(restart_button)

	var checkpoints_button := Button.new()
	checkpoints_button.name = "CheckpointsButton"
	checkpoints_button.text = "Checkpoints"
	checkpoints_button.process_mode = Node.PROCESS_MODE_ALWAYS
	checkpoints_button.pressed.connect(_on_checkpoints_pressed)
	box.add_child(checkpoints_button)

	var quit_button := Button.new()
	quit_button.name = "QuitButton"
	quit_button.text = "Quit to Title"
	quit_button.process_mode = Node.PROCESS_MODE_ALWAYS
	quit_button.pressed.connect(_on_quit_pressed)
	box.add_child(quit_button)
