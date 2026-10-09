extends Node
## Title/start screen. Built entirely in code -- the scene file
## (scenes/ui/TitleScreen.tscn) is just a bare root node with this
## script attached, same philosophy as GameDebug.gd / GameUI.gd.

var start_button: Button


func _ready() -> void:
	get_tree().paused = false

	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)

	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.07, 0.08, 0.13, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(background)

	var title := Label.new()
	title.name = "Title"
	title.text = "COIN TROLL ADVENTURE"
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.position = Vector2(-420, -170)
	title.size = Vector2(840, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	layer.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "Chapter 1 -- The Bush Maze"
	subtitle.set_anchors_preset(Control.PRESET_CENTER)
	subtitle.position = Vector2(-420, -100)
	subtitle.size = Vector2(840, 40)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.85, 0.87, 0.92))
	layer.add_child(subtitle)

	start_button = Button.new()
	start_button.name = "StartButton"
	start_button.text = "Start"
	start_button.set_anchors_preset(Control.PRESET_CENTER)
	start_button.position = Vector2(-80, 10)
	start_button.size = Vector2(160, 50)
	start_button.add_theme_font_size_override("font_size", 22)
	start_button.pressed.connect(_on_start_pressed)
	layer.add_child(start_button)

	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "Press Enter or click Start"
	hint.set_anchors_preset(Control.PRESET_CENTER)
	hint.position = Vector2(-420, 90)
	hint.size = Vector2(840, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.6, 0.62, 0.68))
	layer.add_child(hint)

	start_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_start_pressed()


func _on_start_pressed() -> void:
	var resume_path := "res://scenes/checkpoints/checkpoint%02d.tscn" % CheckpointManager.highest_checkpoint
	var target := resume_path if ResourceLoader.exists(resume_path) else "res://scenes/checkpoints/checkpoint01.tscn"
	get_tree().change_scene_to_file(target)
