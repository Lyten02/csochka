extends SceneTree

func _initialize() -> void:
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

	var tests = [
		{"rot": Vector3(48, -14, 10), "off": Vector3(0.01, -0.05, -0.05), "s": 1.25, "name": "solve_s125_x01"},
		{"rot": Vector3(48, -14, 10), "off": Vector3(0.00, -0.05, -0.05), "s": 1.30, "name": "solve_s130_x00"},
		{"rot": Vector3(48, -14, 10), "off": Vector3(-0.01, -0.05, -0.05), "s": 1.35, "name": "solve_s135_xm01"},
		{"rot": Vector3(48, -14, 10), "off": Vector3(-0.02, -0.05, -0.05), "s": 1.40, "name": "solve_s140_xm02"},
		{"rot": Vector3(52, -14, 8),  "off": Vector3(-0.01, -0.06, -0.05), "s": 1.35, "name": "solve_s135_rot52"},
		{"rot": Vector3(52, -14, 8),  "off": Vector3(-0.02, -0.06, -0.05), "s": 1.40, "name": "solve_s140_rot52"},
	]

	for t in tests:
		knife.rotation_degrees = t["rot"]
		knife.position = t["off"]
		knife.scale = Vector3.ONE * t["s"]
		knife._base_transform = knife.transform

		await process_frame
		await process_frame

		var img = root.get_viewport().get_texture().get_image()
		var out_path = "%s/%s.png" % [out_dir, t["name"]]
		img.save_png(out_path)
		print("Saved %s" % out_path)

	quit(0)
