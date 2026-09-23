extends AnimatableBody2D
## CP02 falling hedge trap.
## Starts static, drops when the player enters the trigger.

@export var drop_distance: float = 220.0
@export var drop_duration: float = 0.35
@export var reset_after: float = 2.0
@export var one_shot: bool = true

@onready var start_position := global_position
var triggered := false


func trigger() -> void:
	if triggered and one_shot:
		return

	triggered = true

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(
		self,
		"global_position",
		start_position + Vector2(0.0, drop_distance),
		drop_duration
	)

	if not one_shot:
		await tween.finished
		await get_tree().create_timer(reset_after).timeout
		global_position = start_position
		triggered = false
