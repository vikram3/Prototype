extends Node


enum ConditionType {
	ALWAYS,
	COINS,
	OBJECTIVE_COMPLETE,
	PLAYER_HIDDEN,
	PLAYER_DEAD,
	EVENT
}


@export_category("Condition")

@export_enum(
	"Always",
	"Coins",
	"Objective Complete",
	"Player Hidden",
	"Player Dead",
	"Event"
)
var condition_type: int = ConditionType.ALWAYS


@export_category("Target")

@export var required_coins: int = 0
@export var event_name: String = ""


func is_met(context: Node = null) -> bool:

	match condition_type:

		ConditionType.ALWAYS:
			return true

		ConditionType.COINS:
			return _check_coins(context)

		ConditionType.OBJECTIVE_COMPLETE:
			return _check_objective_complete(context)

		ConditionType.PLAYER_HIDDEN:
			return _check_player_hidden(context)

		ConditionType.PLAYER_DEAD:
			return _check_player_dead(context)

		ConditionType.EVENT:
			return _check_event(context)

	return false


# ============================================================
# EVENT MATCHING
# ============================================================

func is_event_condition(
	target_event: String
) -> bool:

	if condition_type != ConditionType.EVENT:
		return false

	if event_name.is_empty():
		return false

	return event_name == target_event


# ============================================================
# CONDITIONS
# ============================================================

func _check_coins(context: Node) -> bool:

	var objective := _find_objective(context)

	if objective == null:
		return false

	if not "coins_collected" in objective:
		return false

	return int(
		objective.coins_collected
	) >= required_coins


func _check_objective_complete(context: Node) -> bool:

	var objective := _find_objective(context)

	if objective == null:
		return false

	if not objective.has_method(
		"is_complete"
	):
		return false

	return objective.is_complete()


func _check_player_hidden(context: Node) -> bool:

	var player := _find_player(context)

	if player == null:
		return false

	if not player.has_method(
		"is_hidden"
	):
		return false

	return player.is_hidden()


func _check_player_dead(context: Node) -> bool:

	var player := _find_player(context)

	if player == null:
		return false

	if not "is_dead" in player:
		return false

	return player.is_dead


func _check_event(context: Node) -> bool:

	if context == null:
		return false

	if not context.has_method(
		"has_story_event"
	):
		return false

	return context.has_story_event(
		event_name
	)


func _find_objective(context: Node) -> Node:

	if context != null:

		var objective := context.get_node_or_null(
			"Objective"
		)

		if objective != null:
			return objective

	var scene := get_tree().current_scene

	if scene != null:

		var objective := scene.get_node_or_null(
			"Objective"
		)

		if objective != null:
			return objective

	return null


func _find_player(context: Node) -> Node:

	if context != null:

		if context.has_method(
			"_find_player"
		):
			return context._find_player()

	return get_tree().get_first_node_in_group(
		"player"
	)
