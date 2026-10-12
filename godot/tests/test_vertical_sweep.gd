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

	var variations = [
		# 1. Baseline from scale110:
		{"rot": Vector3(47, -14, 10), "off": Vector3(-0.02, -0.05, -0.05), "s": 1.10, "name": "vert_base_47"},
		# 2. More upright pitch:
		{"rot": Vector3(52, -14, 8),  "off": Vector3(-0.02, -0.05, -0.05), "s": 1.10, "name": "vert_p52"},
		{"rot": Vector3(56, -14, 6),  "off": Vector3(-0.02, -0.06, -0.05), "s": 1.10, "name": "vert_p56"},
		{"rot": Vector3(60, -14, 4),  "off": Vector3(-0.02, -0.06, -0.05), "s": 1.10, "name": "vert_p60"},
		{"rot": Vector3(64, -14, 2),  "off": Vector3(-0.02, -0.07, -0.05), "s": 1.10, "name": "vert_p64"},
		# Adjust yaw and roll:
		{"rot": Vector3(56, -10, 2),  "off": Vector3(-0.02, -0.06, -0.05), "s": 1.10, "name": "vert_p56_y10"},
		{"rot": Vector3(56, -18, 10), "off": Vector3(-0.02, -0.06, -0.05), "s": 1.10, "name": "vert_p56_y18"},
		{"rot": Vector3(60, -10, 0),  "off": Vector3(-0.02, -0.07, -0.05), "s": 1.10, "name": "vert_p60_y10"},
		# Centering variations (shift X to center the knife):
		{"rot": Vector3(56, -14, 6),  "off": Vector3(-0.04, -0.06, -0.05), "s": 1.15, "name": "vert_p56_center"},
		{"rot": Vector3(60, -12, 2),  "off": Vector3(-0.04, -0.07, -0.05), "s": 1.15, "name": "vert_p60_center"},
		{"rot": Vector3(64, -10, 0),  "off": Vector3(-0.04, -0.07, -0.05), "s": 1.15, "name": "vert_p64_center"},
	]

	for v in variations:
		knife.rotation_degrees = v["rot"]
		knife.position = v["off"]
		knife.scale = Vector3.ONE * v["s"]
		knife._base_transform = knife.transform

		await process_frame
		await process_frame

		var img = root.get_viewport().get_texture().get_image()
		var out_path = "%s/%s.png" % [out_dir, v["name"]]
		img.save_png(out_path)
		print("Saved %s" % out_path)

	quit(0)
