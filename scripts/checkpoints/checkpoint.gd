extends Node2D

@export var checkpoint_number: int = 1
@export var player_scene: PackedScene

@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var goal: Area2D = $Goal
@onready var objective: Node = $Objective


func _ready() -> void:
	CheckpointManager.start_checkpoint(checkpoint_number)

	objective.start()

	_spawn_player()

	goal.player_reached_goal.connect(_on_goal_reached)
	objective.objective_completed.connect(_on_objective_completed)

	_connect_coins()


func _spawn_player() -> void:
	if player_scene == null:
		push_error("Checkpoint: Player scene is not assigned.")
		return

	var player := player_scene.instantiate()

	$World.add_child(player)

	player.global_position = player_spawn.global_position


func _connect_coins() -> void:
	for coin in get_tree().get_nodes_in_group("coins"):
		if coin.has_signal("collected"):
			if not coin.collected.is_connected(_on_coin_collected):
				coin.collected.connect(_on_coin_collected)


func _on_coin_collected(value: int) -> void:
	CheckpointManager.add_coins(value)
	objective.add_coins(value)

	if objective.coins_collected >= objective.required_coins:
		goal.activate()


func _on_goal_reached() -> void:
	objective.reach_exit()


func _on_objective_completed() -> void:
	complete_checkpoint()


func complete_checkpoint() -> void:
	CheckpointManager.complete_checkpoint()
