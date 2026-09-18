extends Node2D

@export var checkpoint_number: int = 1

@onready var goal: Area2D = $Goal
@onready var objective: Node = $Objective


func _ready() -> void:
	CheckpointManager.start_checkpoint(checkpoint_number)

	objective.start()

	goal.player_reached_goal.connect(
		_on_goal_reached
	)

	objective.objective_completed.connect(
		_on_objective_completed
	)

	_connect_coins()

	print(
		"Checkpoint scene loaded: %02d"
		% checkpoint_number
	)


func _connect_coins() -> void:
	var coins := get_tree().get_nodes_in_group("coin")

	for coin in coins:
		coin.collected.connect(
			_on_coin_collected
		)


func _on_coin_collected(value: int) -> void:
	CheckpointManager.add_coins(value)
	objective.add_coins(value)


func _on_goal_reached() -> void:
	print("Player reached checkpoint goal.")

	objective.reach_exit()


func _on_objective_completed() -> void:
	complete_checkpoint()


func complete_checkpoint() -> void:
	print(
		"Checkpoint %02d complete!"
		% checkpoint_number
	)

	CheckpointManager.complete_checkpoint()
