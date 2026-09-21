extends CanvasLayer

@onready var label: Label = $DebugLabel

var messages: Array[String] = []


func _ready() -> void:
	layer = 100

	add_message("DEBUG SYSTEM STARTED")


func add_message(message: String) -> void:
	messages.push_front(message)

	if messages.size() > 12:
		messages.resize(12)

	_refresh()


func set_status(text: String) -> void:
	label.text = text


func _refresh() -> void:
	label.text = "\n".join(messages)
