extends Node2D

@export_category("Checkpoint")
@export var checkpoint_number: int = 1
@export var checkpoint_title: String = ""

@export_category("Player")
@export var player_scene: PackedScene

@export_category("Movement Mode")
## Chapter 1's maze levels are top-down (sneak/hide from Skulls, 4-directional
## movement). Later side-scrolling levels attach PlatformerOverride to the
## player scene; set this to false to strip it so the player's native
## top-down physics (player.gd / ct.gd) stays in control instead.
@export var use_platformer_override: bool = true

@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var goal: Area2D = $Goal
@onready var objective: Node = $Objective

var level_completed: bool = false


func _ready() -> void:
	CheckpointManager.start_checkpoint(
		checkpoint_number
	)

	_connect_goal()
	_connect_objective()
	_connect_coins()

	objective.start()

	GameUI.bind_checkpoint(self)

	_spawn_player()

	_update_goal_state()

	var display_title := checkpoint_title if checkpoint_title != "" else CheckpointManager.title_for(checkpoint_number)
	if not CheckpointManager.intro_seen.has(checkpoint_number):
		CheckpointManager.intro_seen[checkpoint_number] = true
		_show_intro_screen(display_title)


func _show_intro_screen(subtitle_text: String) -> void:
	var layer := CanvasLayer.new()
	layer.name = "CheckpointIntro"
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	var background := ColorRect.new()
	background.color = Color(0.07, 0.08, 0.13, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(background)

	var title := Label.new()
	title.text = "COIN TROLL ADVENTURE"
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.position = Vector2(-420, -170)
	title.size = Vector2(840, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	layer.add_child(title)

	var subtitle := Label.new()
	subtitle.text = subtitle_text
	subtitle.set_anchors_preset(Control.PRESET_CENTER)
	subtitle.position = Vector2(-420, -100)
	subtitle.size = Vector2(840, 40)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.85, 0.87, 0.92))
	layer.add_child(subtitle)

	var start_button := Button.new()
	start_button.name = "StartButton"
	start_button.text = "Start"
	start_button.set_anchors_preset(Control.PRESET_CENTER)
	start_button.position = Vector2(-80, 10)
	start_button.size = Vector2(160, 50)
	start_button.add_theme_font_size_override("font_size", 22)
	start_button.process_mode = Node.PROCESS_MODE_ALWAYS
	start_button.disabled = true
	start_button.pressed.connect(func() -> void:
		if not is_instance_valid(layer):
			return
		layer.queue_free()
		get_tree().paused = false)
	layer.add_child(start_button)
	get_tree().create_timer(0.5, true).timeout.connect(func() -> void:
		if is_instance_valid(start_button):
			start_button.disabled = false
			start_button.grab_focus())

	var hint := Label.new()
	hint.text = "Press Enter or click Start"
	hint.set_anchors_preset(Control.PRESET_CENTER)
	hint.position = Vector2(-420, 90)
	hint.size = Vector2(840, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.6, 0.62, 0.68))
	layer.add_child(hint)

	get_tree().paused = true


# ============================================================
# PLAYER
# ============================================================

func _spawn_player() -> void:
	if player_scene == null:
		push_warning(
			"Checkpoint has no player_scene assigned."
		)
		return

	var player: Node = player_scene.instantiate()

	if not use_platformer_override:
		var override_node: Node = player.get_node_or_null("PlatformerOverride")
		if override_node != null:
			player.remove_child(override_node)
			override_node.queue_free()

	$World.add_child(player)

	if player is Node2D:
		var player_2d := player as Node2D
		player_2d.global_position = (
			player_spawn.global_position
		)


# ============================================================
# SIGNAL CONNECTIONS
# ============================================================

func _connect_goal() -> void:
	if not goal.has_signal(
		"player_reached_goal"
	):
		return

	if not goal.player_reached_goal.is_connected(
		_on_goal_reached
	):
		goal.player_reached_goal.connect(
			_on_goal_reached
		)


func _connect_objective() -> void:
	if not objective.has_signal(
		"objective_completed"
	):
		return

	if not objective.objective_completed.is_connected(
		_on_objective_completed
	):
		objective.objective_completed.connect(
			_on_objective_completed
		)


func _connect_coins() -> void:
	var coins: Array[Node] = (
		get_tree().get_nodes_in_group("coins")
	)

	for coin: Node in coins:
		if not coin.has_signal("collected"):
			continue

		if not coin.collected.is_connected(
			_on_coin_collected
		):
			coin.collected.connect(
				_on_coin_collected
			)


# ============================================================
# COINS
# ============================================================

func _on_coin_collected(value: int) -> void:
	if level_completed:
		return

	CheckpointManager.add_coins(value)

	if objective.has_method("add_coins"):
		objective.add_coins(value)

	var player := get_tree().get_first_node_in_group("player")

	if player != null:
		if player.has_method("coin_collected"):
			player.coin_collected()

	_update_goal_state()


# ============================================================
# GOAL STATE
# ============================================================

func _update_goal_state() -> void:
	if level_completed:
		return

	if not objective.has_method(
		"is_complete"
	):
		return

	var objective_type: int = (
		objective.objective_type
	)

	match objective_type:

		# Goal itself is the objective.
		0:
			if goal.has_method("deactivate"):
				goal.deactivate()

		# Exit is the objective.
		1:
			if goal.has_method("activate"):
				goal.activate()

		# Coins OR Exit.
		2:
			if goal.has_method("activate"):
				goal.activate()

		# Coins AND Exit.
		3:
			if objective.has_method(
				"is_coin_objective_complete"
			):
				if objective.is_coin_objective_complete():
					if goal.has_method("activate"):
						goal.activate()
				else:
					if goal.has_method("deactivate"):
						goal.deactivate()

		# Survive Time.
		4:
			if goal.has_method("deactivate"):
				goal.deactivate()

		# Defeat Count.
		5:
			if goal.has_method("deactivate"):
				goal.deactivate()

		# Story/event objective.
		6:
			if goal.has_method("deactivate"):
				goal.deactivate()


# ============================================================
# GOAL
# ============================================================

func _on_goal_reached() -> void:
	if level_completed:
		return

	if not objective.has_method(
		"reach_exit"
	):
		return

	objective.reach_exit()


# ============================================================
# OBJECTIVE COMPLETE
# ============================================================

func _on_objective_completed() -> void:
	if level_completed:
		return

	level_completed = true

	print(
		"Checkpoint %02d objective completed!"
		% checkpoint_number
	)

	if goal.has_method("deactivate"):
		goal.deactivate()

	complete_checkpoint()


# ============================================================
# CHECKPOINT COMPLETE
# ============================================================

func complete_checkpoint() -> void:
	if not level_completed:
		return

	CheckpointManager.complete_checkpoint()
