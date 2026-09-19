@tool
extends EditorScript

func _run() -> void:
	var scene := EditorInterface.get_edited_scene_root()

	if scene == null:
		push_error("No edited scene found.")
		return

	var maze := scene.get_node_or_null("World/Maze")

	if maze == null:
		push_error("Could not find World/Maze.")
		return

	var count: int = 0

	for node in _get_all_children(maze):
		if node is Sprite2D:
			var sprite := node as Sprite2D

			if not sprite.get_meta("hedge_sort_fixed", false):
				continue

			if sprite.texture == null:
				continue

			var texture_size := sprite.texture.get_size()

			var bottom_offset: float = (
				float(texture_size.y) * 0.5 * abs(sprite.scale.y)
			)

			# Restore original sprite position.
			sprite.global_position -= Vector2(0, bottom_offset)

			# Restore original centered texture offset.
			sprite.offset.y = 0.0

			sprite.set_meta("hedge_sort_fixed", false)

			count += 1

	print("Restored %d hedge sprites." % count)


func _get_all_children(node: Node) -> Array[Node]:
	var result: Array[Node] = []

	for child in node.get_children():
		result.append(child)
		result.append_array(_get_all_children(child))

	return result
