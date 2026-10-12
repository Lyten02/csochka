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
	cam.fov = 74.0 # Standard CS FOV in 16:9 widescreen
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

	# We want:
	# 1. Hands lower on screen so forearm stumps are hidden below screen edge (lower Y)
	# 2. Closer so hands fill screen nicely (z ~ -0.60 to -0.75)
	# 3. Knife positioned nicely centered / right-center
	# Let's test combinations of (dx, dy, dz, roll_deg):
	var variations = [
		# Baseline closer & lower:
		{"name": "v1_orig", "origin": Vector3(-0.124, -0.113, -0.876), "roll": 0.0},
		{"name": "v2_closer_low", "origin": Vector3(-0.10, -0.17, -0.72), "roll": 0.0},
		{"name": "v3_closer_lower", "origin": Vector3(-0.10, -0.20, -0.68), "roll": 0.0},
		{"name": "v4_closer_lower_xleft", "origin": Vector3(-0.14, -0.20, -0.68), "roll": 0.0},
		{"name": "v5_closer_lower_xleft2", "origin": Vector3(-0.17, -0.20, -0.68), "roll": 0.0},
		{"name": "v6_closer_lower_xright", "origin": Vector3(-0.07, -0.20, -0.68), "roll": 0.0},
		# With slight roll to make knife blade 100% vertical:
		{"name": "v7_roll_p3", "origin": Vector3(-0.10, -0.20, -0.68), "roll": 3.0},
		{"name": "v8_roll_m3", "origin": Vector3(-0.10, -0.20, -0.68), "roll": -3.0},
		{"name": "v9_roll_p5_xleft", "origin": Vector3(-0.14, -0.21, -0.68), "roll": 5.0},
		{"name": "v10_roll_p5_xcenter", "origin": Vector3(-0.18, -0.21, -0.68), "roll": 5.0},
		{"name": "v11_perfect_cs_framing", "origin": Vector3(-0.12, -0.21, -0.65), "roll": 4.0},
		{"name": "v12_cs_center", "origin": Vector3(-0.16, -0.21, -0.65), "roll": 4.0},
	]

	for v in variations:
		var r_z = Basis(Vector3.FORWARD, deg_to_rad(v["roll"]))
		var b = r_z * base_basis
		knife.transform = Transform3D(b, v["origin"])
		knife._base_transform = knife.transform

		await process_frame
		await process_frame

		var img = root.get_viewport().get_texture().get_image()
		var out_path = "%s/%s.png" % [out_dir, v["name"]]
		img.save_png(out_path)
		print("Saved %s" % out_path)

	quit(0)
