extends CanvasLayer

@onready var label: Label = $DebugLabel


func _ready() -> void:
	label.text = "DEBUG STARTING..."
