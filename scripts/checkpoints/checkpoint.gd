extends Node2D

@export var checkpoint_number: int = 1
@export var player_scene: PackedScene

@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var goal: Area2D = $Goal
@onready var objective: Node = $Objective

var level_completed: bool = false


func _ready() -> void:
	print("========================================")
	print("CHECKPOINT READY")
	print("Checkpoint Number: ", checkpoint_number)
	print("Player Scene: ", player_scene)
	print("Goal: ", goal)
	print("Objective: ", objective)
	print("========================================")

	CheckpointManager.start_checkpoint(checkpoint_number)

	objective.start()

	_spawn_player()

	_connect_goal()
	_connect_objective()
	_connect_coins()

	_update_goal_state()


# ============================================================
# PLAYER
# ============================================================

func _spawn_player() -> void:
	if player_scene == null:
		push_error("Checkpoint: Player scene is not assigned.")
		return

	var player: Node = player_scene.instantiate()

	$World.add_child(player)

	if player is Node2D:
		var player_2d: Node2D = player as Node2D
		player_2d.global_position = player_spawn.global_position

		print("PLAYER SPAWNED")
		print("Player Position: ", player_2d.global_position)
		print("Player Collision Layer: ", player_2d.collision_layer)
		print("Player Collision Mask: ", player_2d.collision_mask)
		print("Player Group: ", player_2d.is_in_group("player"))


# ============================================================
# SIGNAL CONNECTIONS
# ============================================================

func _connect_goal() -> void:
	print("CONNECTING GOAL SIGNAL")

	if not goal.has_signal("player_reached_goal"):
		push_error("Goal does not have player_reached_goal signal.")
		return

	if not goal.player_reached_goal.is_connected(_on_goal_reached):
		goal.player_reached_goal.connect(_on_goal_reached)
		print("GOAL SIGNAL CONNECTED")
	else:
		print("GOAL SIGNAL ALREADY CONNECTED")


func _connect_objective() -> void:
	print("CONNECTING OBJECTIVE SIGNAL")

	if not objective.has_signal("objective_completed"):
		push_error("Objective does not have objective_completed signal.")
		return

	if not objective.objective_completed.is_connected(_on_objective_completed):
		objective.objective_completed.connect(
			_on_objective_completed
		)

		print("OBJECTIVE SIGNAL CONNECTED")
	else:
		print("OBJECTIVE SIGNAL ALREADY CONNECTED")


func _connect_coins() -> void:
	print("CONNECTING COINS")

	var coins: Array[Node] = get_tree().get_nodes_in_group("coins")

	print("Coins Found: ", coins.size())

	for coin: Node in coins:
		if not coin.has_signal("collected"):
			print("Coin has no collected signal: ", coin.name)
			continue

		if not coin.collected.is_connected(_on_coin_collected):
			coin.collected.connect(_on_coin_collected)

			print("CONNECTED COIN: ", coin.name)
		else:
			print("COIN ALREADY CONNECTED: ", coin.name)


# ============================================================
# COINS
# ============================================================

func _on_coin_collected(value: int) -> void:
	if level_completed:
		print("COIN IGNORED: Level already completed")
		return

	print("========================================")
	print("CHECKPOINT RECEIVED COIN")
	print("Value: ", value)
	print("========================================")

	CheckpointManager.add_coins(value)

	if objective.has_method("add_coins"):
		objective.add_coins(value)
	else:
		push_error("Objective does not have add_coins()")

	_update_goal_state()


func _update_goal_state() -> void:
	if level_completed:
		return

	if not objective.has_method("is_coin_objective_complete"):
		push_error(
			"Objective does not have is_coin_objective_complete()"
		)
		return

	var coins_complete: bool = (
		objective.is_coin_objective_complete()
	)

	print("GOAL STATE CHECK")
	print("Coins Complete: ", coins_complete)

	if coins_complete:
		if goal.has_method("activate"):
			goal.activate()
		else:
			push_error("Goal does not have activate()")
	else:
		if goal.has_method("deactivate"):
			goal.deactivate()


# ============================================================
# GOAL
# ============================================================

func _on_goal_reached() -> void:
	print("========================================")
	print("CHECKPOINT RECEIVED GOAL SIGNAL")
	print("========================================")

	if level_completed:
		print("GOAL SIGNAL IGNORED: Level already completed")
		return

	if not objective.has_method("reach_exit"):
		push_error("Objective does not have reach_exit()")
		return

	print("Goal reached - checking objective")

	objective.reach_exit()


# ============================================================
# OBJECTIVE COMPLETE
# ============================================================

func _on_objective_completed() -> void:
	print("========================================")
	print("CHECKPOINT RECEIVED OBJECTIVE COMPLETE")
	print("========================================")

	if level_completed:
		print("OBJECTIVE COMPLETE IGNORED: Already completed")
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
		print("CHECKPOINT COMPLETE BLOCKED: level_completed is false")
		return

	print("========================================")
	print("COMPLETING CHECKPOINT")
	print("Checkpoint: ", checkpoint_number)
	print("========================================")

	CheckpointManager.complete_checkpoint()

	print(
		"Checkpoint %02d COMPLETE"
		% checkpoint_number
	)
