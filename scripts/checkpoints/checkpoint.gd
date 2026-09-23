extends Node2D

@export_category("Checkpoint")
@export var checkpoint_number: int = 1

@export_category("Player")
@export var player_scene: PackedScene

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

	_spawn_player()

	_update_goal_state()


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
