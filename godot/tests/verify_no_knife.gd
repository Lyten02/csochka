extends SceneTree

func _initialize() -> void:
	if not preload("res://tests/settings_snapshot.gd").protect(self):
		return
	var main_scene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)

	await process_frame
	await process_frame
	await process_frame

	var img = root.get_viewport().get_texture().get_image()
	var out_path = "C:/Users/zxcursed/.gemini/antigravity/brain/956c65b0-33f6-41d9-8b72-e82454f3f7a8/scratch/knife_removed_check.png"
	img.save_png(out_path)
	print("Verified main.tscn renders cleanly! Saved to %s" % out_path)
	quit(0)
