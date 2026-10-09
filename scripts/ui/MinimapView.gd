extends Control
## Draw surface for the minimap. The minimap is painted by GameUI.gd
## (_draw_minimap); this node just asks GameUI to draw into it.


func _draw() -> void:
	GameUI._draw_minimap(self)
