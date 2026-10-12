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
		Vector3(-0.782944, 0.234564, 0.576176),
		Vector3(-0.356328, 0.590105, -0.724435),
		Vector3(-0.509931, -0.772500, -0.378438)
	)

	var out_dir = "C:/Users/zxcursed/.gemini/antigravity/brain/956c65b0-33f6-41d9-8b72-e82454f3f7a8/scratch"

	# Test variations around origin.z = -0.95 to -1.15, origin.y = -0.08 to -0.15, origin.x = 0.04 to 0.12
	# Also with subtle roll to balance hands
	var tests = [
		{"roll": 0.0, "orig": Vector3(0.08, -0.10, -0.95), "name": "r0_y-10_z-95"},
		{"roll": 0.0, "orig": Vector3(0.08, -0.12, -1.00), "name": "r0_y-12_z-100"},
		{"roll": 0.0, "orig": Vector3(0.06, -0.12, -1.05), "name": "r0_y-12_z-105"},
		{"roll": -8.0, "orig": Vector3(0.08, -0.10, -0.95), "name": "rm8_y-10_z-95"},
		{"roll": -8.0, "orig": Vector3(0.08, -0.12, -1.00), "name": "rm8_y-12_z-100"},
		{"roll": -12.0, "orig": Vector3(0.08, -0.10, -0.95), "name": "rm12_y-10_z-95"},
		{"roll": -12.0, "orig": Vector3(0.08, -0.12, -1.00), "name": "rm12_y-12_z-100"},
		{"roll": -15.0, "orig": Vector3(0.08, -0.10, -0.95), "name": "rm15_y-10_z-95"},
	]

	for i in range(tests.size()):
		var t = tests[i]
		var r_z = Basis(Vector3.FORWARD, deg_to_rad(t["roll"]))
		var b = r_z * base_basis
		knife.transform = Transform3D(b, t["orig"])
		knife._base_transform = knife.transform

		await process_frame
		await process_frame

		var img = root.get_viewport().get_texture().get_image()
		var out_path = "%s/perfect_%s.png" % [out_dir, t["name"]]
		img.save_png(out_path)
		print("Saved %s" % out_path)

	quit(0)
