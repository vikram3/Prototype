extends CanvasLayer


const TOGGLE_KEY := KEY_F3

var debug_visible: bool = true

var panel: ColorRect
var title_label: Label
var debug_label: Label


func _ready() -> void:
	layer = 1000

	_create_debug_ui()
	_refresh_visibility()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey

		if key_event.pressed \
		and not key_event.echo \
		and key_event.keycode == TOGGLE_KEY:
			debug_visible = not debug_visible
			_refresh_visibility()


func _process(_delta: float) -> void:
	if not debug_visible:
		return

	_update_debug_display()


# ============================================================
# UI
# ============================================================

func _create_debug_ui() -> void:
	panel = ColorRect.new()
	panel.name = "DebugPanel"

	panel.position = Vector2(16, 16)
	panel.size = Vector2(560, 0)

	panel.color = Color(
		0.015,
		0.015,
		0.02,
		0.94
	)

	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	add_child(panel)


	title_label = Label.new()
	title_label.name = "Title"

	title_label.position = Vector2(16, 10)
	title_label.size = Vector2(520, 30)

	title_label.text = "CTA  •  DEBUG  •  F3 TOGGLE"

	title_label.add_theme_font_size_override(
		"font_size",
		20
	)

	title_label.add_theme_color_override(
		"font_color",
		Color(
			0.85,
			0.9,
			1.0
		)
	)

	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	panel.add_child(title_label)


	debug_label = Label.new()
	debug_label.name = "DebugText"

	debug_label.position = Vector2(16, 44)
	debug_label.size = Vector2(520, 0)

	debug_label.add_theme_font_size_override(
		"font_size",
		14
	)

	debug_label.add_theme_color_override(
		"font_color",
		Color(
			0.9,
			0.9,
			0.92
		)
	)

	debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	panel.add_child(debug_label)


func _refresh_visibility() -> void:
	if panel == null:
		return

	panel.visible = debug_visible


# ============================================================
# MAIN DEBUG
# ============================================================

func _update_debug_display() -> void:
	if debug_label == null:
		return

	var checkpoint := _find_checkpoint()
	var player := _find_player()
	var objective := _find_objective(checkpoint)
	var goal := _find_goal(checkpoint)

	var text := ""


	text += _section("LEVEL")

	text += "  Scene          %s\n" % _get_scene_name()

	text += "  Checkpoint     %s\n" % _get_checkpoint_name(
		checkpoint
	)

	text += "\n"


	# ========================================================
	# PLAYER
	# ========================================================

	text += _section("PLAYER")

	if player != null and is_instance_valid(player):

		var player_2d := player as Node2D

		if player_2d != null:
			text += "  Position       %s\n" % (
				_vector_text(
					player_2d.global_position
				)
			)

		if player is CollisionObject2D:
			var collision := player as CollisionObject2D

			text += "  Layer          %d\n" % (
				collision.collision_layer
			)

		text += "  Group          %s\n" % (
			_bool_text(
				player.is_in_group("player")
			)
		)

		if player.has_method("is_hidden"):
			text += "  Hidden         %s\n" % (
				_bool_text(
					player.is_hidden()
				)
			)

		if "health" in player:
			text += "  Health         %d" % (
				int(player.health)
			)

			if "max_health" in player:
				text += " / %d" % (
					int(player.max_health)
				)

			text += "\n"

		if "is_dead" in player:
			text += "  Dead           %s\n" % (
				_bool_text(
					player.is_dead
				)
			)

	else:
		text += "  NOT FOUND\n"

	text += "\n"


	# ========================================================
	# COINS
	# ========================================================

	text += _section("COINS")

	var coins := get_tree().get_nodes_in_group("coins")

	var collected := 0
	var required := 0

	if objective != null:

		if "coins_collected" in objective:
			collected = int(
				objective.coins_collected
			)

		if "required_coins" in objective:
			required = int(
				objective.required_coins
			)

	text += "  Active         %d\n" % coins.size()

	text += "  Progress       %d / %d\n" % [
		collected,
		required
	]

	text += "\n"


	# ========================================================
	# OBJECTIVE
	# ========================================================

	text += _section("OBJECTIVE")

	if objective != null:

		text += "  Required       %d\n" % (
			int(objective.required_coins)
		)

		text += "  Current        %d\n" % (
			int(objective.coins_collected)
		)

		text += "  Type           %s\n" % (
			_get_objective_type_text(objective)
		)

		text += "  Exit Reached   %s\n" % (
			_bool_text(
				objective.exit_reached
			)
		)

		text += "  Complete       %s\n" % (
			_bool_text(
				objective.is_complete()
			)
		)

	else:
		text += "  NOT FOUND\n"

	text += "\n"


	# ========================================================
	# GOAL
	# ========================================================

	text += _section("GOAL")

	if goal != null:

		text += "  Activated      %s\n" % (
			_bool_text(
				goal.activated
			)
		)

		text += "  Monitoring     %s\n" % (
			_bool_text(
				goal.monitoring
			)
		)

		text += "  Triggered      %s\n" % (
			_bool_text(
				goal.triggered
			)
		)

		text += "  Collision Mask %d\n" % (
			goal.collision_mask
		)

	else:
		text += "  NOT FOUND\n"

	text += "\n"


	# ========================================================
	# ENEMIES
	# ========================================================

	text += _section("ENEMIES")

	var enemies := _find_skulls()

	text += "  Skulls         %d\n" % enemies.size()

	var enemy_index := 1

	for enemy in enemies:

		if not is_instance_valid(enemy):
			continue

		var enemy_name := enemy.name

		var state_text := _get_enemy_state(
			enemy
		)

		var enemy_position := ""

		if enemy is Node2D:
			enemy_position = _vector_text(
				(enemy as Node2D).global_position
			)

		text += "  [%02d] %-16s %-8s %s\n" % [
			enemy_index,
			enemy_name,
			state_text,
			enemy_position
		]

		enemy_index += 1


	text += "\n"


	# ========================================================
	# CHECKPOINT
	# ========================================================

	text += _section("CHECKPOINT")

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


	# ========================================================
	# SAVE
	# ========================================================

	text += _section("SAVE")

	text += "  Highest CP     %d\n" % (
		SaveManager.highest_checkpoint
	)

	text += "\n"


	# ========================================================
	# SYSTEM
	# ========================================================

	text += _section("SYSTEM")

	text += "  FPS            %d\n" % (
		Engine.get_frames_per_second()
	)

	text += "  Time Scale     %.2f\n" % (
		Engine.time_scale
	)

	text += "  Debug          %s\n" % (
		_bool_text(debug_visible)
	)


	debug_label.text = text


	_resize_panel()


# ============================================================
# FIND CURRENT LEVEL SYSTEMS
# ============================================================

func _find_checkpoint() -> Node:
	var current_scene := get_tree().current_scene

	if current_scene == null:
		return null

	if current_scene.has_node("Objective"):
		return current_scene

	var checkpoints := get_tree().get_nodes_in_group(
		"checkpoint"
	)

	if checkpoints.size() > 0:
		return checkpoints[0]

	return null


func _find_player() -> Node:
	return get_tree().get_first_node_in_group(
		"player"
	)


func _find_objective(
	checkpoint: Node
) -> Node:

	if checkpoint == null:
		return null

	if checkpoint.has_node("Objective"):
		return checkpoint.get_node(
			"Objective"
		)

	return null


func _find_goal(
	checkpoint: Node
) -> Node:

	if checkpoint == null:
		return null

	if checkpoint.has_node("Goal"):
		return checkpoint.get_node(
			"Goal"
		)

	return null


func _find_skulls() -> Array[Node]:
	var result: Array[Node] = []

	var nodes := get_tree().get_nodes_in_group(
		"enemies"
	)

	for node in nodes:

		if not is_instance_valid(node):
			continue

		if node.has_method("start_chase") \
		or node.has_method("update_chase"):
			result.append(node)

	return result


# ============================================================
# ENEMY STATE
# ============================================================

func _get_enemy_state(enemy: Node) -> String:

	if "current_state" in enemy:
		var state = enemy.current_state

		if typeof(state) == TYPE_STRING:
			return str(state)

		return str(state)

	if "state" in enemy:
		var enemy_state = enemy.state

		if typeof(enemy_state) == TYPE_STRING:
			return str(enemy_state)

		return str(enemy_state)

	return "UNKNOWN"


# ============================================================
# LEVEL INFORMATION
# ============================================================

func _get_scene_name() -> String:

	var scene := get_tree().current_scene

	if scene == null:
		return "NONE"

	return scene.name


func _get_checkpoint_name(
	checkpoint: Node
) -> String:

	if checkpoint == null:
		return "NONE"

	if "checkpoint_number" in checkpoint:
		return "CP%02d" % (
			int(checkpoint.checkpoint_number)
		)

	return checkpoint.name


# ============================================================
# UI HELPERS
# ============================================================

func _section(title: String) -> String:

	return (
		"==================================================\n"
		+ title
		+ "\n"
	)


func _resize_panel() -> void:

	if debug_label == null:
		return

	var text_height := (
		debug_label.get_minimum_size().y
	)

	debug_label.size.y = text_height

	panel.size.y = (
		text_height + 62.0
	)

	var viewport_size := (
		get_viewport()
		.get_visible_rect()
		.size
	)

	var maximum_height := (
		viewport_size.y - 32.0
	)

	if panel.size.y > maximum_height:

		panel.size.y = maximum_height

		debug_label.size.y = (
			maximum_height - 62.0
		)


func _bool_text(value: bool) -> String:

	if value:
		return "YES"

	return "NO"


func _vector_text(
	value: Vector2
) -> String:

	return "(%.0f, %.0f)" % [
		value.x,
		value.y
	]

func _get_objective_type_text(objective: Node) -> String:
	if objective == null:
		return "NONE"

	if not "objective_type" in objective:
		return "UNKNOWN"

	match int(objective.objective_type):
		0:
			return "COINS"

		1:
			return "EXIT"

		2:
			return "COINS OR EXIT"

		3:
			return "COINS AND EXIT"

		4:
			return "SURVIVE TIME"

		5:
			return "DEFEAT COUNT"

		6:
			return "EVENT"

	return "UNKNOWN"
