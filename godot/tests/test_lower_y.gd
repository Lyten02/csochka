extends SceneTree

func _initialize() -> void:
	var root_node = Node3D.new()
	root.add_child(root_node)

	var env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.18, 0.18, 0.22)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	env.environment = e
	root_node.add_child(env)

	var cam = Camera3D.new()
	cam.fov = 74.0
	cam.near = 0.02
	cam.far = 100.0
	cam.current = true
	root_node.add_child(cam)

	var knife_scene = load("res://scenes/weapons/knife.tscn")
	var knife = knife_scene.instantiate()
	cam.add_child(knife)

	await process_frame
	await process_frame

	var anim: AnimationPlayer = knife.find_child("AnimationPlayer", true, false)
	if anim and anim.has_animation("idle"):
		anim.play("idle")
		anim.seek(0.0, true)

	await process_frame
	await process_frame

	var meshes: Array[Node] = knife.find_children("", "MeshInstance3D", true, false)
	for m in meshes:
		var mi := m as MeshInstance3D
		for s in range(mi.mesh.get_surface_count()):
			var mat = mi.get_surface_override_material(s)
			if mat is BaseMaterial3D:
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var base_basis := Basis(
		Vector3(-0.260597, 0.690936, 0.674312),
		Vector3(-0.664523, 0.378297, -0.644438),
		Vector3(-0.700355, -0.616035, 0.360560)
	)

	var out_dir = "C:/Users/zxcursed/.gemini/antigravity/brain/956c65b0-33f6-41d9-8b72-e82454f3f7a8/scratch"

	var configs = [
		{"s": 1.25, "orig": Vector3(-0.13, -0.26, -0.68), "roll": 4.0, "name": "low_s125_y26"},
		{"s": 1.25, "orig": Vector3(-0.16, -0.26, -0.68), "roll": 4.0, "name": "low_s125_y26_center"},
		{"s": 1.30, "orig": Vector3(-0.14, -0.28, -0.65), "roll": 4.0, "name": "low_s130_y28"},
		{"s": 1.30, "orig": Vector3(-0.17, -0.28, -0.65), "roll": 4.0, "name": "low_s130_y28_center"},
		{"s": 1.35, "orig": Vector3(-0.15, -0.30, -0.62), "roll": 4.0, "name": "low_s135_y30"},
		{"s": 1.35, "orig": Vector3(-0.18, -0.30, -0.62), "roll": 4.0, "name": "low_s135_y30_center"},
		{"s": 1.40, "orig": Vector3(-0.16, -0.32, -0.60), "roll": 4.0, "name": "low_s140_y32"},
		{"s": 1.40, "orig": Vector3(-0.20, -0.32, -0.60), "roll": 4.0, "name": "low_s140_y32_center"},
	]

	for cfg in configs:
		var r_z = Basis(Vector3.FORWARD, deg_to_rad(cfg["roll"]))
		var b = r_z * base_basis * Basis.from_scale(Vector3.ONE * cfg["s"])
		knife.transform = Transform3D(b, cfg["orig"])
		knife._base_transform = knife.transform

		await process_frame
		await process_frame

		var img = root.get_viewport().get_texture().get_image()
		var out_path = "%s/%s.png" % [out_dir, cfg["name"]]
		img.save_png(out_path)
		print("Saved %s" % out_path)

	quit(0)
