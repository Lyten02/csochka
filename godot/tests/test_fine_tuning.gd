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
		# Variations around exact baseline:
		{"name": "fine_1_base", "s": 1.0, "orig": Vector3(-0.124, -0.113, -0.877), "roll": 0.0},
		{"name": "fine_2_low",  "s": 1.05, "orig": Vector3(-0.124, -0.140, -0.850), "roll": 0.0},
		{"name": "fine_3_low_xleft1", "s": 1.05, "orig": Vector3(-0.150, -0.140, -0.850), "roll": 0.0},
		{"name": "fine_4_low_xleft2", "s": 1.05, "orig": Vector3(-0.175, -0.140, -0.850), "roll": 0.0},
		{"name": "fine_5_scale110", "s": 1.10, "orig": Vector3(-0.130, -0.150, -0.830), "roll": 0.0},
		{"name": "fine_6_scale110_center", "s": 1.10, "orig": Vector3(-0.160, -0.150, -0.830), "roll": 0.0},
		{"name": "fine_7_scale115", "s": 1.15, "orig": Vector3(-0.140, -0.160, -0.800), "roll": 0.0},
		{"name": "fine_8_scale115_center", "s": 1.15, "orig": Vector3(-0.170, -0.160, -0.800), "roll": 0.0},
		# With roll +3 deg to ensure 100% vertical blade
		{"name": "fine_9_roll3_s110_center", "s": 1.10, "orig": Vector3(-0.160, -0.150, -0.830), "roll": 3.0},
		{"name": "fine_10_roll3_s115_center", "s": 1.15, "orig": Vector3(-0.170, -0.160, -0.800), "roll": 3.0},
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
