extends CanvasLayer
## GameUI autoload.
##
## Owns two pieces of UI, built entirely in code (same approach as
## GameDebug.gd) so no hand-authored scene file is needed:
##   - an always-on HUD showing coin progress + the current objective
##   - a level-complete overlay shown when the Objective finishes
##
## A checkpoint calls GameUI.bind_objective(objective, checkpoint_number)
## once from its own _ready(), after objective.start().

var hud_panel: Control
var progress_label: Label
var objective_label: Label

var complete_panel: Control
var complete_title_label: Label
var complete_subtitle_label: Label

var bound_objective: Node = null
var bound_checkpoint_number: int = 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 500

	_create_hud()
	_create_complete_screen()


func is_complete_screen_visible() -> bool:
	return complete_panel != null and complete_panel.visible


# ============================================================
# BINDING
# ============================================================

func bind_objective(objective: Node, checkpoint_number: int = 1) -> void:
	_unbind_current()

	bound_objective = objective
	bound_checkpoint_number = checkpoint_number

	get_tree().paused = false
	complete_panel.visible = false
	hud_panel.visible = true

	if objective == null:
		return

	if objective.has_signal("progress_changed"):
		if not objective.progress_changed.is_connected(_on_progress_changed):
			objective.progress_changed.connect(_on_progress_changed)

	if objective.has_signal("objective_completed"):
		if not objective.objective_completed.is_connected(_on_objective_completed):
			objective.objective_completed.connect(_on_objective_completed)

	objective_label.text = _objective_text(objective)
	_refresh_progress(objective)


func _unbind_current() -> void:
	if bound_objective == null:
		return

	if not is_instance_valid(bound_objective):
		bound_objective = null
		return

	if bound_objective.has_signal("progress_changed"):
		if bound_objective.progress_changed.is_connected(_on_progress_changed):
			bound_objective.progress_changed.disconnect(_on_progress_changed)

	if bound_objective.has_signal("objective_completed"):
		if bound_objective.objective_completed.is_connected(_on_objective_completed):
			bound_objective.objective_completed.disconnect(_on_objective_completed)

	bound_objective = null


# ============================================================
# OBJECTIVE TEXT
# ============================================================

func _objective_text(objective: Node) -> String:
	if not ("objective_type" in objective):
		return ""

	match int(objective.objective_type):
		0:
			return "Collect the coins."
		1:
			return "Reach the exit."
		2:
			return "Collect the coins, or reach the exit."
		3:
			return "Collect the coins, then reach the exit."
		4:
			return "Survive."
		5:
			return "Defeat the enemies."
		6:
			return "..."

	return ""


func _refresh_progress(objective: Node) -> void:
	if objective == null:
		return

	if not ("objective_type" in objective):
		return

	var current := 0
	var target := 0

	match int(objective.objective_type):
		0, 2, 3:
			current = int(objective.coins_collected)
			target = int(objective.required_coins)

		1:
			current = 1 if bool(objective.exit_reached) else 0
			target = 1

		4:
			current = int(objective.elapsed_time)
			target = int(objective.survive_time)

		5:
			current = int(objective.defeats)
			target = int(objective.required_defeats)

		6:
			current = 1 if bool(objective.event_triggered) else 0
			target = 1

	_set_progress_text(current, target)


func _on_progress_changed(current: int, target: int) -> void:
	_set_progress_text(current, target)


func _set_progress_text(current: int, target: int) -> void:
	if target <= 0:
		progress_label.text = ""
		return

	progress_label.text = "Coins: %d / %d" % [current, target]


# ============================================================
# LEVEL COMPLETE
# ============================================================

func _on_objective_completed() -> void:
	_show_complete_screen()


func _show_complete_screen() -> void:
	hud_panel.visible = false
	complete_panel.visible = true

	complete_title_label.text = "CHAPTER %d COMPLETE" % bound_checkpoint_number

	var coins_text := ""

	if bound_objective != null and is_instance_valid(bound_objective):
		if "coins_collected" in bound_objective:
			coins_text = "Coins collected: %d\n\n" % int(
				bound_objective.coins_collected
			)

	complete_subtitle_label.text = (
		coins_text + "Press ENTER to return to the title screen"
	)

	get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void:
	if not complete_panel.visible:
		return

	if event.is_action_pressed("ui_accept"):
		_return_to_title()


func _return_to_title() -> void:
	get_tree().paused = false
	complete_panel.visible = false
	hud_panel.visible = true

	_unbind_current()

	get_tree().change_scene_to_file(
		"res://scenes/ui/TitleScreen.tscn"
	)


# ============================================================
# UI CONSTRUCTION
# ============================================================

func _create_hud() -> void:
	hud_panel = Control.new()
	hud_panel.name = "HUDPanel"
	hud_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud_panel.offset_left = 0.0
	hud_panel.offset_right = 0.0
	hud_panel.offset_top = 0.0
	hud_panel.offset_bottom = 90.0
	hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud_panel)

	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.0, 0.0, 0.0, 0.35)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_panel.add_child(background)

	progress_label = Label.new()
	progress_label.name = "Progress"
	progress_label.position = Vector2(24, 12)
	progress_label.size = Vector2(400, 34)
	progress_label.add_theme_font_size_override("font_size", 26)
	progress_label.add_theme_color_override(
		"font_color", Color(1.0, 0.92, 0.5)
	)
	progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_panel.add_child(progress_label)

	objective_label = Label.new()
	objective_label.name = "ObjectiveText"
	objective_label.position = Vector2(24, 50)
	objective_label.size = Vector2(760, 32)
	objective_label.add_theme_font_size_override("font_size", 18)
	objective_label.add_theme_color_override(
		"font_color", Color(0.9, 0.9, 0.95)
	)
	objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_panel.add_child(objective_label)


func _create_complete_screen() -> void:
	complete_panel = Control.new()
	complete_panel.name = "CompletePanel"
	complete_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	complete_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	complete_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	complete_panel.visible = false
	add_child(complete_panel)

	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.0, 0.0, 0.0, 0.78)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	complete_panel.add_child(background)

	complete_title_label = Label.new()
	complete_title_label.name = "Title"
	complete_title_label.set_anchors_preset(Control.PRESET_CENTER)
	complete_title_label.position = Vector2(-400, -110)
	complete_title_label.size = Vector2(800, 60)
	complete_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	complete_title_label.add_theme_font_size_override("font_size", 48)
	complete_title_label.add_theme_color_override(
		"font_color", Color(1.0, 0.85, 0.3)
	)
	complete_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	complete_panel.add_child(complete_title_label)

	complete_subtitle_label = Label.new()
	complete_subtitle_label.name = "Subtitle"
	complete_subtitle_label.set_anchors_preset(Control.PRESET_CENTER)
	complete_subtitle_label.position = Vector2(-400, -20)
	complete_subtitle_label.size = Vector2(800, 140)
	complete_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	complete_subtitle_label.add_theme_font_size_override("font_size", 22)
	complete_subtitle_label.add_theme_color_override(
		"font_color", Color(0.9, 0.92, 0.95)
	)
	complete_subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	complete_panel.add_child(complete_subtitle_label)
