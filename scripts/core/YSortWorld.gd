extends Node2D

@export var sort_offset: float = 0.0


func _process(_delta: float) -> void:
	var scene := get_tree().current_scene

	if scene == null:
		return

	_sort_children(scene)


func _sort_children(node: Node) -> void:
	# Never sort UI layers.
	if node is CanvasLayer:
		return

	for child in node.get_children():
		if child is CanvasLayer:
			continue

		if child is Sprite2D:
			_sort_sprite(child)

		_sort_children(child)


func _sort_sprite(sprite: Sprite2D) -> void:
	var bottom_y := sprite.global_position.y

	if sprite.texture:
		bottom_y += (
			sprite.texture.get_height()
			* 0.5
			* abs(sprite.global_scale.y)
		)

	sprite.z_as_relative = false
	sprite.z_index = int(bottom_y + sort_offset)
