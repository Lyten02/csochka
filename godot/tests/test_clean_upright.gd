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

	var player = main.get_node("Player")
	var cam: Camera3D = player.get_node("Camera3D")
	var knife = cam.get_node("Knife")

	var anim: AnimationPlayer = knife.find_child("AnimationPlayer", true, false)
	if anim and anim.has_animation("idle"):
		anim.play("idle")
		anim.seek(0.0, true)

	var out_dir = "C:/Users/zxcursed/.gemini/antigravity/brain/956c65b0-33f6-41d9-8b72-e82454f3f7a8/scratch"

	var base_rot = Basis.from_euler(Vector3(deg_to_rad(47), deg_to_rad(-14), deg_to_rad(10)))

	var configs = [
		{"roll": -12.0, "s": 1.25, "off": Vector3(-0.01, -0.06, -0.05), "name": "clean_r12_s125"},
		{"roll": -15.0, "s": 1.25, "off": Vector3(-0.01, -0.06, -0.05), "name": "clean_r15_s125"},
		{"roll": -18.0, "s": 1.25, "off": Vector3(-0.01, -0.06, -0.05), "name": "clean_r18_s125"},
		{"roll": -15.0, "s": 1.30, "off": Vector3(-0.02, -0.07, -0.05), "name": "clean_r15_s130"},
		{"roll": -18.0, "s": 1.30, "off": Vector3(-0.02, -0.07, -0.05), "name": "clean_r18_s130"},
		{"roll": -20.0, "s": 1.35, "off": Vector3(-0.02, -0.08, -0.05), "name": "clean_r20_s135"},
		{"roll": -15.0, "s": 1.35, "off": Vector3(-0.03, -0.08, -0.05), "name": "clean_r15_s135_center"},
		{"roll": -18.0, "s": 1.35, "off": Vector3(-0.04, -0.08, -0.05), "name": "clean_r18_s135_center"},
	]

	for cfg in configs:
		var r_z = Basis(Vector3.FORWARD, deg_to_rad(cfg["roll"]))
		var b = r_z * base_rot * Basis.from_scale(Vector3.ONE * cfg["s"])
		knife.transform = Transform3D(b, cfg["off"])
		knife._base_transform = knife.transform

		await process_frame
		await process_frame

		var img = root.get_viewport().get_texture().get_image()
		var out_path = "%s/%s.png" % [out_dir, cfg["name"]]
		img.save_png(out_path)
		print("Saved %s" % out_path)

	quit(0)
