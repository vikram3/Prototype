extends Node2D

@export var sort_offset: float = 0.0

func _process(_delta: float) -> void:
	_sort_children(self)

func _sort_children(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			if child is Sprite2D:
				var sprite := child as Sprite2D

				var bottom_y := sprite.global_position.y

				if sprite.texture:
					bottom_y += sprite.texture.get_height() * 0.5 * sprite.global_scale.y

				sprite.z_as_relative = false
				sprite.z_index = int(bottom_y + sort_offset)

		_sort_children(child)
