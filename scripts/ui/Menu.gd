extends Node
## One menu scene for every non-gameplay screen. Flow.screen picks the
## layout: title, select (checkpoint select), intro (per checkpoint),
## settings. Built in code, same approach as GameUI.gd / PauseMenu.gd.

const GOLD := Color(1.0, 0.85, 0.3)
const SOFT := Color(0.85, 0.87, 0.92)
const DIM := Color(0.6, 0.62, 0.68)

var layer: CanvasLayer
var first_button: Button


func _ready() -> void:
	get_tree().paused = false

	layer = CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)

	var background := ColorRect.new()
	background.color = Color(0.07, 0.08, 0.13, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(background)

	match Flow.screen:
		"select":
			_build_select()
		"intro":
			_build_intro()
		"settings":
			_build_settings()
		_:
			_build_title()

	if first_button != null:
		first_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and Flow.screen != "title":
		_go_back()


func _go_back() -> void:
	match Flow.screen:
		"select":
			Flow.show_menu("title")
		"intro":
			Flow.show_menu("select")
		"settings":
			Flow.show_menu(Flow.return_screen)
		_:
			pass


# ============================================================
# SCREENS
# ============================================================

func _build_title() -> void:
	_label("COIN TROLL ADCENTURE", 46, Vector2(-420, -190), GOLD)

	_button("Start", Vector2(-110, -30), Vector2(220, 50), Flow.show_menu.bind("select"))

	var continue_target := Flow.highest_unlocked()
	_button("Continue", Vector2(-110, 30), Vector2(220, 50),
		Flow.show_menu.bind("intro", continue_target),
		not Flow.checkpoint_exists(continue_target))

	_button("Settings", Vector2(-110, 90), Vector2(220, 50), Flow.go_settings.bind("title"))
	_button("Quit", Vector2(-110, 150), Vector2(220, 50), get_tree().quit)

	_label("Press Enter or click a button", 14, Vector2(-420, 230), DIM)


func _build_select() -> void:
	_label("SELECT CHECKPOINT", 36, Vector2(-420, -330), GOLD)

	for n in range(1, 19):
		var column := 0 if n <= 9 else 1
		var row := (n - 1) % 9
		var pos := Vector2(-330 + column * 360, -250 + row * 52)
		var unlocked := Flow.is_unlocked(n)
		var text := "Checkpoint %d -- %s" % [n, CheckpointManager.title_for(n)]
		var button := _button(text, pos, Vector2(330, 44), Flow.show_menu.bind("intro", n), not unlocked)
		button.add_theme_font_size_override("font_size", 15)

	_button("Back", Vector2(-110, 240), Vector2(220, 44), Flow.show_menu.bind("title"))


func _build_intro() -> void:
	var n := Flow.checkpoint
	_label("CHECKPOINT %d" % n, 22, Vector2(-420, -190), DIM)
	_label(CheckpointManager.title_for(n), 34, Vector2(-420, -130), GOLD)

	_button("Start", Vector2(-110, -10), Vector2(220, 50), Flow.start_checkpoint.bind(n))
	_button("Back", Vector2(-110, 60), Vector2(220, 50), Flow.show_menu.bind("select"))

	_label("Press Enter or click Start", 14, Vector2(-420, 130), DIM)


func _build_settings() -> void:
	_label("SETTINGS", 40, Vector2(-420, -230), GOLD)

	var fullscreen_box := CheckButton.new()
	fullscreen_box.text = "Fullscreen"
	fullscreen_box.set_anchors_preset(Control.PRESET_CENTER)
	fullscreen_box.position = Vector2(-150, -120)
	fullscreen_box.size = Vector2(300, 44)
	fullscreen_box.add_theme_font_size_override("font_size", 22)
	fullscreen_box.button_pressed = Flow.fullscreen
	fullscreen_box.toggled.connect(Flow.set_fullscreen)
	layer.add_child(fullscreen_box)
	first_button = fullscreen_box

	_label("Master Volume", 22, Vector2(-420, -40), SOFT)

	var slider := HSlider.new()
	slider.set_anchors_preset(Control.PRESET_CENTER)
	slider.position = Vector2(-200, 10)
	slider.size = Vector2(400, 30)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = Flow.master_volume
	slider.value_changed.connect(Flow.set_master_volume)
	layer.add_child(slider)

	_button("Back", Vector2(-110, 90), Vector2(220, 50), _go_back)


# ============================================================
# HELPERS
# ============================================================

func _label(text: String, size: int, pos: Vector2, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.position = pos
	label.size = Vector2(840, size + 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(label)
	return label


func _button(text: String, pos: Vector2, size: Vector2, on_press: Callable, disabled: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.set_anchors_preset(Control.PRESET_CENTER)
	button.position = pos
	button.size = size
	button.add_theme_font_size_override("font_size", 22)
	button.disabled = disabled
	button.pressed.connect(on_press)
	layer.add_child(button)
	if first_button == null and not disabled:
		first_button = button
	return button
