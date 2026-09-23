extends Node

signal dialogue_requested(speaker: String, text: String)
signal story_event(event_name: String)
signal beat_started(beat: Node)
signal beat_finished(beat: Node)


@export_category("Dialogue")
@export var dialogue_duration: float = 2.5
@export var dialogue_gap: float = 0.15


@export_category("Startup")
@export var play_startup_beats: bool = true


var beats: Array[Node] = []
var story_events: Dictionary = {}
var event_cooldowns: Dictionary = {}

var dialogue_busy: bool = false
var dialogue_token: int = 0
var processing_events: bool = false


func _ready() -> void:
	add_to_group("story_controller")

	_collect_beats()

	await get_tree().process_frame

	if play_startup_beats:
		await _play_startup_beats()


func _collect_beats() -> void:
	beats.clear()

	for child in get_children():
		if not child.has_method("play"):
			continue

		if not child.has_signal("dialogue_requested"):
			continue

		beats.append(child)

		if not child.dialogue_requested.is_connected(
			_on_dialogue_requested
		):
			child.dialogue_requested.connect(
				_on_dialogue_requested
			)

		if not child.event_requested.is_connected(
			_on_event_requested
		):
			child.event_requested.connect(
				_on_event_requested
			)

		if not child.beat_started.is_connected(
			_on_beat_started
		):
			child.beat_started.connect(
				_on_beat_started
			)

		if not child.beat_finished.is_connected(
			_on_beat_finished
		):
			child.beat_finished.connect(
				_on_beat_finished
			)


# ============================================================
# STARTUP
#
# Only automatic=true beats start here.
# ============================================================

func _play_startup_beats() -> void:
	for beat in beats:
		if not is_instance_valid(beat):
			continue

		if not _is_explicit_startup_beat(beat):
			continue

		if not beat.has_method("can_play"):
			continue

		if not beat.can_play(self):
			continue

		await beat.play(self)


func _is_explicit_startup_beat(beat: Node) -> bool:
	if not "automatic" in beat:
		return false

	return bool(beat.automatic)


# ============================================================
# GAMEPLAY EVENTS
#
# Event beats play ONLY when their event exactly matches.
# ============================================================

func emit_gameplay_event(
	event_name: String,
	cooldown: float = 0.0
) -> void:
	if event_name.is_empty():
		return

	if cooldown > 0.0:
		var now := Time.get_ticks_msec() / 1000.0

		var last_time: float = event_cooldowns.get(
			event_name,
			-99999.0
		)

		if now - last_time < cooldown:
			return

		event_cooldowns[event_name] = now

	story_events[event_name] = true
	story_event.emit(event_name)

	await _play_event_beats(event_name)


func trigger_event(event_name: String) -> void:
	if event_name.is_empty():
		return

	story_events[event_name] = true
	story_event.emit(event_name)

	await _play_event_beats(event_name)


func _play_event_beats(event_name: String) -> void:
	while processing_events:
		await get_tree().process_frame

	processing_events = true

	for beat in beats:
		if not is_instance_valid(beat):
			continue

		if not _beat_matches_event(
			beat,
			event_name
		):
			continue

		if not beat.has_method("can_play"):
			continue

		if not beat.can_play(self):
			continue

		await beat.play(self)

	processing_events = false


func _beat_matches_event(
	beat: Node,
	event_name: String
) -> bool:
	var condition := _get_beat_condition(beat)

	if condition == null:
		return false

	if not condition.has_method(
		"is_event_condition"
	):
		return false

	return condition.is_event_condition(
		event_name
	)


func _get_beat_condition(beat: Node) -> Node:
	if "condition" in beat:
		if beat.condition != null:
			return beat.condition

	var child := beat.get_node_or_null(
		"Condition"
	)

	if child != null:
		return child

	return null


# ============================================================
# MANUAL
# ============================================================

func play_beat(index: int) -> void:
	if index < 0:
		return

	if index >= beats.size():
		return

	var beat := beats[index]

	if not beat.can_play(self):
		return

	await beat.play(self)


func play_beat_by_id(id: String) -> void:
	if id.is_empty():
		return

	for beat in beats:
		if not "beat_id" in beat:
			continue

		if str(beat.beat_id) != id:
			continue

		if not beat.can_play(self):
			return

		await beat.play(self)
		return


# ============================================================
# EVENT MEMORY
# ============================================================

func has_story_event(event_name: String) -> bool:
	if event_name.is_empty():
		return false

	return bool(
		story_events.get(
			event_name,
			false
		)
	)


func reset_story() -> void:
	story_events.clear()
	event_cooldowns.clear()

	dialogue_token += 1
	dialogue_busy = false
	processing_events = false

	for beat in beats:
		if beat.has_method("reset"):
			beat.reset()


# ============================================================
# DIALOGUE
# ============================================================

func _on_dialogue_requested(
	speaker: String,
	text: String
) -> void:
	dialogue_requested.emit(
		speaker,
		text
	)

	_show_player_dialogue(
		speaker,
		text
	)


func _show_player_dialogue(
	speaker: String,
	text: String
) -> void:
	if text.is_empty():
		return

	var player := get_tree().get_first_node_in_group(
		"player"
	)

	if player == null:
		return

	if not player.has_method(
		"show_story_speech"
	):
		return

	dialogue_token += 1

	var current_token := dialogue_token

	dialogue_busy = true

	player.show_story_speech(
		speaker,
		text
	)

	await get_tree().create_timer(
		dialogue_duration
	).timeout

	if current_token != dialogue_token:
		return

	if is_instance_valid(player):
		if player.has_method(
			"hide_story_speech"
		):
			player.hide_story_speech()

	dialogue_busy = false

	if dialogue_gap > 0.0:
		await get_tree().create_timer(
			dialogue_gap
		).timeout


func _on_event_requested(
	event_name: String
) -> void:
	await trigger_event(event_name)


func _on_beat_started(
	beat: Node
) -> void:
	beat_started.emit(beat)


func _on_beat_finished(
	beat: Node
) -> void:
	beat_finished.emit(beat)
