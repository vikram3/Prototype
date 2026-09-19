@tool
extends EditorScript

func _run() -> void:
	var scene_root := get_scene()

	print("================================")
	print("SCENE: ", scene_root.name)
	print("================================")

	var sprites := scene_root.find_children("*", "Sprite2D", true, false)

	print("Total Sprite2D nodes found: ", sprites.size())

	for sprite in sprites:
		print(
			"Sprite: ",
			sprite.get_path(),
			" | owner: ",
			sprite.owner
		)

	print("================================")
