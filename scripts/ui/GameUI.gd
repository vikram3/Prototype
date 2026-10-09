extends CanvasLayer
## GameUI autoload.
##
## Owns the per-checkpoint HUD, built entirely in code (same approach
## as GameDebug.gd) so no hand-authored scene file is needed:
##   - coin / objective readout + a segmented health bar (top-left)
##   - a scaled-down minimap of the maze with live blips (top-right)
##   - a level-complete overlay, shown after any narrative-only
##     "epilogue" story beats finish playing
##
## A checkpoint calls GameUI.bind_checkpoint(self) once from its own
## _ready(), after objective.start().

const POLL_INTERVAL := 0.1
const MINIMAP_SIZE := Vector2(190, 190)
const MINIMAP_MARGIN := 16.0

# Beats played, in order, the moment the Objective completes, before
# the level-complete overlay appears. "chapter_01_complete" already
# exists as a gameplay beat (coins finished); the rest are
# narrative-only preview text for Segment 2 content that doesn't
# exist as playable level geometry yet (treasure chest, tower,
# rival, Big Boss) -- see scenes/checkpoints/checkpoint01.tscn.
const EPILOGUE_BEAT_IDS := [
	"chapter_01_complete",
	"chapter_01_epilogue_chest_spotted",
	"chapter_01_epilogue_tower_rival",
	"chapter_01_epilogue_chest_open",
	"chapter_01_epilogue_bigboss",
]

var hud_panel: Control
var progress_label: Label
var objective_label: Label
var health_row: HBoxContainer
var health_pips: Array[ColorRect] = []
var health_pip_count: int = -1

var minimap_panel: Control
var minimap_view: MinimapView
var minimap_bounds: Rect2 = Rect2()
var minimap_hedge_rects: Array[Rect2] = []
var minimap_skulls: Array[Node] = []
var minimap_goal: Node = null

var complete_panel: Control
var complete_title_label: Label
var complete_subtitle_label: Label

var bound_objective: Node = null
var bound_checkpoint_number: int = 1
var bound_story_controller: Node = null

var poll_timer: float = 0.0


# ============================================================
# MINIMAP DRAW SURFACE
#
# A tiny inner class so we get a real _draw() callback without a
# hand-authored scene file. It just calls back into GameUI, which
# owns all the minimap data.
# ============================================================

class MinimapView extends Control:
	var owner_ui: CanvasLayer = null

	func _draw() -> void:
		if owner_ui != null:
			owner_ui._draw_minimap(self)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 500

	_create_hud()
	_create_minimap()
	_create_complete_screen()


func _process(delta: float) -> void:
	poll_timer -= delta

	if poll_timer > 0.0:
		return

	poll_timer = POLL_INTERVAL

	_refresh_health()

	if minimap_view != null and minimap_panel.visible:
		minimap_view.queue_redraw()


func is_complete_screen_visible() -> bool:
	return complete_panel != null and complete_panel.visible


# ============================================================
# BINDING
# ============================================================

func bind_checkpoint(checkpoint: Node) -> void:
	var objective: Node = checkpoint.get_node_or_null("Objective")
	var checkpoint_number: int = 1

	if "checkpoint_number" in checkpoint:
		checkpoint_number = int(checkpoint.checkpoint_number)

	bind_objective(objective, checkpoint_number)

	bound_story_controller = checkpoint.get_node_or_null(
		"StoryController"
	)

	_recompute_minimap(checkpoint)

	health_pip_count = -1
	_refresh_health()


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
# HEALTH BAR
# ============================================================

func _refresh_health() -> void:
	var player := get_tree().get_first_node_in_group("player")

	if player == null or not is_instance_valid(player):
		return

	if not ("health" in player) or not ("max_health" in player):
		health_row.visible = false
		return

	health_row.visible = true

	_set_health_pips(
		int(player.health),
		int(player.max_health)
	)


func _set_health_pips(current: int, max_value: int) -> void:
	if max_value <= 0:
		return

	if max_value != health_pip_count:
		_rebuild_health_pips(max_value)

	for i in range(health_pips.size()):
		var filled: bool = i < current

		health_pips[i].color = (
			Color(0.95, 0.3, 0.35, 1.0) if filled
			else Color(0.25, 0.1, 0.1, 0.9)
		)


func _rebuild_health_pips(max_value: int) -> void:
	for pip in health_pips:
		pip.queue_free()

	health_pips.clear()

	for i in range(max_value):
		var pip := ColorRect.new()
		pip.name = "Pip%d" % i
		pip.custom_minimum_size = Vector2(22, 22)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		health_row.add_child(pip)
		health_pips.append(pip)

	health_pip_count = max_value


# ============================================================
# MINIMAP
# ============================================================

func _recompute_minimap(checkpoint: Node) -> void:
	minimap_hedge_rects.clear()
	minimap_skulls.clear()
	minimap_goal = null
	minimap_bounds = Rect2()

	var world: Node = checkpoint.get_node_or_null("World")

	if world == null:
		minimap_panel.visible = false
		return

	var min_pos := Vector2.ZERO
	var max_pos := Vector2.ZERO
	var have_bounds := false

	for child in world.get_children():
		if not (child is Sprite2D):
			continue

		var sprite := child as Sprite2D

		if sprite.name.find("Hedge") == -1:
			continue

		if sprite.texture == null:
			continue

		var size: Vector2 = sprite.texture.get_size() * sprite.scale
		var top_left: Vector2 = sprite.global_position - size * 0.5
		var rect := Rect2(top_left, size)

		minimap_hedge_rects.append(rect)

		if not have_bounds:
			min_pos = rect.position
			max_pos = rect.position + rect.size
			have_bounds = true
		else:
			min_pos.x = min(min_pos.x, rect.position.x)
			min_pos.y = min(min_pos.y, rect.position.y)
			max_pos.x = max(max_pos.x, rect.position.x + rect.size.x)
			max_pos.y = max(max_pos.y, rect.position.y + rect.size.y)

	if not have_bounds:
		minimap_panel.visible = false
		return

	var padding := Vector2(150.0, 150.0)

	minimap_bounds = Rect2(
		min_pos - padding,
		(max_pos - min_pos) + padding * 2.0
	)

	for node in world.find_children("*", "", true, false):
		if node.has_method("start_chase"):
			minimap_skulls.append(node)

	minimap_goal = checkpoint.get_node_or_null("Goal")

	minimap_panel.visible = true

	if minimap_view != null:
		minimap_view.queue_redraw()


func _draw_minimap(view: Control) -> void:
	var panel_size: Vector2 = view.size

	view.draw_rect(
		Rect2(Vector2.ZERO, panel_size),
		Color(0.04, 0.05, 0.08, 0.85)
	)

	if minimap_bounds.size.x <= 0.0 or minimap_bounds.size.y <= 0.0:
		return

	var scale_factor: float = min(
		panel_size.x / minimap_bounds.size.x,
		panel_size.y / minimap_bounds.size.y
	)

	var drawn_size: Vector2 = minimap_bounds.size * scale_factor
	var draw_offset: Vector2 = (panel_size - drawn_size) * 0.5

	for rect in minimap_hedge_rects:
		var local_pos: Vector2 = (
			(rect.position - minimap_bounds.position) * scale_factor
			+ draw_offset
		)
		var local_size: Vector2 = rect.size * scale_factor

		view.draw_rect(
			Rect2(local_pos, local_size),
			Color(0.3, 0.6, 0.32, 0.95)
		)

	if minimap_goal != null and is_instance_valid(minimap_goal):
		if minimap_goal is Node2D:
			_draw_minimap_dot(
				view,
				(minimap_goal as Node2D).global_position,
				scale_factor,
				draw_offset,
				Color(1.0, 0.85, 0.2),
				5.0
			)

	for coin in get_tree().get_nodes_in_group("coins"):
		if not is_instance_valid(coin):
			continue

		if not (coin is Node2D):
			continue

		_draw_minimap_dot(
			view,
			(coin as Node2D).global_position,
			scale_factor,
			draw_offset,
			Color(1.0, 0.95, 0.5),
			2.5
		)

	for skull in minimap_skulls:
		if not is_instance_valid(skull):
			continue

		if not (skull is Node2D):
			continue

		_draw_minimap_dot(
			view,
			(skull as Node2D).global_position,
			scale_factor,
			draw_offset,
			Color(0.9, 0.25, 0.25),
			3.5
		)

	var player := get_tree().get_first_node_in_group("player")

	if player != null and is_instance_valid(player):
		if player is Node2D:
			_draw_minimap_dot(
				view,
				(player as Node2D).global_position,
				scale_factor,
				draw_offset,
				Color(0.3, 0.75, 1.0),
				4.5
			)


func _draw_minimap_dot(
	view: Control,
	world_pos: Vector2,
	scale_factor: float,
	draw_offset: Vector2,
	color: Color,
	radius: float
) -> void:
	var local_pos: Vector2 = (
		(world_pos - minimap_bounds.position) * scale_factor
		+ draw_offset
	)

	view.draw_circle(local_pos, radius, color)


# ============================================================
# LEVEL COMPLETE
# ============================================================

func _on_objective_completed() -> void:
	_play_completion_sequence()


func _play_completion_sequence() -> void:
	await _play_epilogue_beats()
	_show_complete_screen()


func _play_epilogue_beats() -> void:
	if bound_story_controller == null:
		return

	if not is_instance_valid(bound_story_controller):
		return

	if not bound_story_controller.has_method("play_beat_by_id"):
		return

	for beat_id in EPILOGUE_BEAT_IDS:
		await bound_story_controller.play_beat_by_id(beat_id)


func _show_complete_screen() -> void:
	hud_panel.visible = false
	minimap_panel.visible = false
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

	var next_path := "res://scenes/checkpoints/checkpoint%02d.tscn" % (CheckpointManager.current_checkpoint + 1)
	var target := next_path if ResourceLoader.exists(next_path) else "res://scenes/ui/TitleScreen.tscn"
	get_tree().change_scene_to_file(target)


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
	hud_panel.offset_bottom = 120.0
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

	health_row = HBoxContainer.new()
	health_row.name = "HealthRow"
	health_row.position = Vector2(24, 84)
	health_row.size = Vector2(300, 28)
	health_row.add_theme_constant_override("separation", 6)
	health_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_panel.add_child(health_row)


func _create_minimap() -> void:
	minimap_panel = Control.new()
	minimap_panel.name = "MinimapPanel"
	minimap_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap_panel.position = Vector2(
		-MINIMAP_SIZE.x - MINIMAP_MARGIN, MINIMAP_MARGIN
	)
	minimap_panel.size = MINIMAP_SIZE
	minimap_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_panel.visible = false
	add_child(minimap_panel)

	var frame := ColorRect.new()
	frame.name = "Frame"
	frame.color = Color(1.0, 1.0, 1.0, 0.25)
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_panel.add_child(frame)

	minimap_view = MinimapView.new()
	minimap_view.name = "View"
	minimap_view.owner_ui = self
	minimap_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	minimap_view.offset_left = 2.0
	minimap_view.offset_top = 2.0
	minimap_view.offset_right = -2.0
	minimap_view.offset_bottom = -2.0
	minimap_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_panel.add_child(minimap_view)


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
