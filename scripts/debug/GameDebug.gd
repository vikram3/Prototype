extends CanvasLayer


var panel: ColorRect
var title_label: Label
var debug_label: Label


func _ready() -> void:
	layer = 100

	_create_debug_ui()


func _process(_delta: float) -> void:
	_update_debug_display()


func _create_debug_ui() -> void:
	# =========================================================
	# MAIN PANEL
	# =========================================================

	panel = ColorRect.new()

	panel.name = "DebugPanel"

	panel.position = Vector2(20, 20)
	panel.size = Vector2(440, 510)

	panel.color = Color(0.025, 0.025, 0.035, 0.92)

	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	add_child(panel)


	# =========================================================
	# TITLE
	# =========================================================

	title_label = Label.new()

	title_label.name = "Title"

	title_label.position = Vector2(18, 14)
	title_label.size = Vector2(400, 35)

	title_label.text = "CTA  •  DEBUG"

	title_label.add_theme_font_size_override(
		"font_size",
		22
	)

	title_label.add_theme_color_override(
		"font_color",
		Color(0.85, 0.9, 1.0)
	)

	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	panel.add_child(title_label)


	# =========================================================
	# SEPARATOR
	# =========================================================

	var separator := ColorRect.new()

	separator.name = "Separator"

	separator.position = Vector2(18, 52)
	separator.size = Vector2(404, 1)

	separator.color = Color(0.35, 0.4, 0.5, 0.7)

	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE

	panel.add_child(separator)


	# =========================================================
	# DEBUG TEXT
	# =========================================================

	debug_label = Label.new()

	debug_label.name = "DebugText"

	debug_label.position = Vector2(18, 68)
	debug_label.size = Vector2(404, 420)

	debug_label.add_theme_font_size_override(
		"font_size",
		16
	)

	debug_label.add_theme_color_override(
		"font_color",
		Color(0.9, 0.9, 0.92)
	)

	debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	panel.add_child(debug_label)


func _update_debug_display() -> void:
	if debug_label == null:
		return

	var player := get_tree().get_first_node_in_group("player")

	var checkpoint := get_parent()

	var objective: Node = null
	var goal: Node = null

	if checkpoint != null:

		if checkpoint.has_node("Objective"):
			objective = checkpoint.get_node("Objective")

		if checkpoint.has_node("Goal"):
			goal = checkpoint.get_node("Goal")


	var text := ""


	# =========================================================
	# PLAYER
	# =========================================================

	text += "PLAYER\n"

	if player != null and is_instance_valid(player):

		var player_2d := player as Node2D

		if player_2d != null:

			text += "  Position       %s\n" % (
				_vector_text(player_2d.global_position)
			)

		if player is CollisionObject2D:

			var collision := player as CollisionObject2D

			text += "  Layer          %d\n" % (
				collision.collision_layer
			)

		text += "  Group          %s\n" % (
			_bool_text(player.is_in_group("player"))
		)

		if player.has_method("is_hidden"):

			text += "  Hidden         %s\n" % (
				_bool_text(player.is_hidden())
			)

		if "health" in player:

			text += "  Health         %s" % (
				str(player.health)
			)

			if "max_health" in player:

				text += " / %s" % (
					str(player.max_health)
				)

			text += "\n"

	else:

		text += "  NOT FOUND\n"


	text += "\n"


	# =========================================================
	# COINS
	# =========================================================

	text += "COINS\n"

	var coins := get_tree().get_nodes_in_group("coins")

	var collected := 0
	var required := 0

	if objective != null:

		if "coins_collected" in objective:
			collected = int(objective.coins_collected)

		if "required_coins" in objective:
			required = int(objective.required_coins)

	text += "  Found          %d\n" % coins.size()
	text += "  Collected      %d / %d\n" % [
		collected,
		required
	]

	text += "\n"


	# =========================================================
	# OBJECTIVE
	# =========================================================

	text += "OBJECTIVE\n"

	if objective != null:

		text += "  Required       %d\n" % (
			int(objective.required_coins)
		)

		text += "  Current        %d\n" % (
			int(objective.coins_collected)
		)

		text += "  Exit Required  %s\n" % (
			_bool_text(objective.require_exit)
		)

		text += "  Exit Reached   %s\n" % (
			_bool_text(objective.exit_reached)
		)

		text += "  Complete       %s\n" % (
			_bool_text(objective.is_complete())
		)

	else:

		text += "  NOT FOUND\n"


	text += "\n"


	# =========================================================
	# GOAL
	# =========================================================

	text += "GOAL\n"

	if goal != null:

		text += "  Activated      %s\n" % (
			_bool_text(goal.activated)
		)

		text += "  Monitoring     %s\n" % (
			_bool_text(goal.monitoring)
		)

		text += "  Mask           %d\n" % (
			goal.collision_mask
		)

		text += "  Triggered      %s\n" % (
			_bool_text(goal.triggered)
		)

	else:

		text += "  NOT FOUND\n"


	text += "\n"


	# =========================================================
	# CHECKPOINT
	# =========================================================

	text += "CHECKPOINT\n"

	text += "  Current        %d\n" % (
		CheckpointManager.current_checkpoint
	)

	text += "  Highest        %d\n" % (
		CheckpointManager.highest_checkpoint
	)

	text += "  Completed      %s\n" % (
		_bool_text(
			CheckpointManager.checkpoint_completed
		)
	)


	text += "\n"


	# =========================================================
	# SAVE
	# =========================================================

	text += "SAVE\n"

	text += "  Highest CP     %d\n" % (
		SaveManager.highest_checkpoint
	)


	text += "\n"


	# =========================================================
	# SYSTEM
	# =========================================================

	text += "SYSTEM\n"

	text += "  FPS            %d" % (
		Engine.get_frames_per_second()
	)


	debug_label.text = text


func _bool_text(value: bool) -> String:
	if value:
		return "YES"

	return "NO"


func _vector_text(value: Vector2) -> String:
	return "(%.0f, %.0f)" % [
		value.x,
		value.y
	]
