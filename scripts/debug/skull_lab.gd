extends Skull

## Supplies the required local patrol route before the established Skull _ready runs.
## The production Skull scene/script is not changed.
func _ready() -> void:
	patrol_path = get_node_or_null("LabPatrol") as Path2D
	if patrol_path != null:
		var route := Curve2D.new()
		route.add_point(Vector2(-220.0, 0.0))
		route.add_point(Vector2(220.0, 0.0))
		patrol_path.curve = route
	super._ready()
