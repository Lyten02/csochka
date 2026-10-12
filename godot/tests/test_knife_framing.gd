extends SceneTree

func _initialize() -> void:
	var root_node = Node3D.new()
	root.add_child(root_node)

	var env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.2, 0.2, 0.25)
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

	var out_dir = "C:/Users/zxcursed/.gemini/antigravity/brain/956c65b0-33f6-41d9-8b72-e82454f3f7a8/scratch"

	# Baseline was:
	# rot = Vector3(44.0, -14.0, 16.0)
	# off = Vector3(0.11, -0.02, -0.05)
	# scale = 0.95

	# Let's test moving offset.x to the left (0.05, 0.0, -0.04, -0.08)
	# And adjusting rotation so the knife is more upright:
	# If blade leans right, decrease rz or increase rx:
	var tests = [
		# 1. Baseline but shifted left
		{"rot": Vector3(44, -14, 16), "off": Vector3(0.02, -0.04, -0.06), "s": 0.95, "name": "shift_left_02"},
		{"rot": Vector3(44, -14, 16), "off": Vector3(-0.02, -0.04, -0.06), "s": 0.95, "name": "shift_left_m02"},
		{"rot": Vector3(44, -14, 16), "off": Vector3(-0.05, -0.05, -0.08), "s": 0.95, "name": "shift_left_m05"},
		
		# 2. More upright blade (adjust roll and pitch)
		{"rot": Vector3(50, -10, 5), "off": Vector3(0.0, -0.05, -0.08), "s": 0.95, "name": "upright_1"},
		{"rot": Vector3(52, -8, 0), "off": Vector3(-0.02, -0.06, -0.09), "s": 0.95, "name": "upright_2"},
		{"rot": Vector3(55, -5, -5), "off": Vector3(-0.03, -0.06, -0.09), "s": 0.95, "name": "upright_3"},
		{"rot": Vector3(55, -12, 5), "off": Vector3(-0.02, -0.05, -0.08), "s": 0.95, "name": "upright_4"},
		{"rot": Vector3(58, -8, 2), "off": Vector3(-0.02, -0.06, -0.09), "s": 0.95, "name": "upright_5"},
		
		# 3. Slightly smaller scale to fit both hands comfortably
		{"rot": Vector3(52, -10, 2), "off": Vector3(-0.01, -0.05, -0.08), "s": 0.88, "name": "scale88_1"},
		{"rot": Vector3(55, -8, -2), "off": Vector3(-0.02, -0.05, -0.08), "s": 0.88, "name": "scale88_2"},
		{"rot": Vector3(58, -6, -5), "off": Vector3(-0.02, -0.06, -0.09), "s": 0.85, "name": "scale85_1"},
		{"rot": Vector3(50, -12, 6), "off": Vector3(0.01, -0.04, -0.07), "s": 0.88, "name": "scale88_3"},
	]

	for i in range(tests.size()):
		var t = tests[i]
		knife.rotation_degrees = t["rot"]
		knife.position = t["off"]
		knife.scale = Vector3.ONE * t["s"]
		knife._base_transform = knife.transform

		await process_frame
		await process_frame

		var img = root.get_viewport().get_texture().get_image()
		var out_path = "%s/framing_%s.png" % [out_dir, t["name"]]
		img.save_png(out_path)
		print("Saved %s" % out_path)

	quit(0)
