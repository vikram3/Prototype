extends Node


signal beat_started(beat: Node)
signal beat_finished(beat: Node)
signal dialogue_requested(speaker: String, text: String)
signal event_requested(event_name: String)


@export_category("Story Beat")

@export var beat_id: String = ""
@export var speaker: String = "CT"
@export_multiline var dialogue: String = ""

@export var delay_before: float = 0.0
@export var delay_after: float = 0.0

@export var one_shot: bool = true


@export_category("Condition")

@export var condition: Node = null


@export_category("Trigger")

@export var trigger_event: String = ""
@export var automatic: bool = false


@export_category("Event")

@export var event_name: String = ""


var has_played: bool = false
var is_playing: bool = false


func can_play(context: Node = null) -> bool:

	if is_playing:
		return false

	if one_shot and has_played:
		return false

	# If this beat has a condition, that condition must pass.
	var resolved_condition := get_condition()

	if resolved_condition != null:
		if resolved_condition.has_method("is_met"):
			if not resolved_condition.is_met(context):
				return false

	return true


func get_condition() -> Node:

	if condition != null:
		return condition

	var child := get_node_or_null("Condition")

	if child != null:
		return child

	return null


func play(context: Node = null) -> void:

	if not can_play(context):
		return

	is_playing = true
	has_played = true

	beat_started.emit(self)

	if delay_before > 0.0:
		await get_tree().create_timer(
			delay_before
		).timeout

	if not dialogue.is_empty():
		dialogue_requested.emit(
			speaker,
			dialogue
		)

	if not event_name.is_empty():
		event_requested.emit(
			event_name
		)

	if delay_after > 0.0:
		await get_tree().create_timer(
			delay_after
		).timeout

	is_playing = false

	beat_finished.emit(self)


func reset() -> void:

	has_played = false
	is_playing = false
