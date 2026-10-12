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

	var configs = [
		# (roll_deg, origin)
		# We want right hand at X ~ +0.12, knife at X ~ +0.10 to +0.18, left hand at X ~ -0.15 to -0.25
		[-15.0, Vector3(0.08, -0.05, -0.70)],
		[-15.0, Vector3(0.12, -0.05, -0.70)],
		[-15.0, Vector3(0.08, -0.08, -0.65)],
		[-15.0, Vector3(0.12, -0.08, -0.65)],
		[-20.0, Vector3(0.08, -0.05, -0.70)],
		[-20.0, Vector3(0.12, -0.05, -0.70)],
		[-20.0, Vector3(0.10, -0.08, -0.65)],
		[-25.0, Vector3(0.10, -0.05, -0.70)],
		[-25.0, Vector3(0.12, -0.08, -0.65)],
		[-10.0, Vector3(0.10, -0.05, -0.70)],
		[-10.0, Vector3(0.12, -0.08, -0.65)],
		[-15.0, Vector3(0.10, -0.02, -0.70)],
	]

	for i in range(configs.size()):
		var roll = configs[i][0]
		var orig = configs[i][1]
		var r_z = Basis(Vector3.FORWARD, deg_to_rad(roll))
		var b = r_z * base_basis
		knife.transform = Transform3D(b, orig)
		knife._base_transform = knife.transform

		await process_frame
		await process_frame

		var img = root.get_viewport().get_texture().get_image()
		var out_path = "%s/roll_test_%d.png" % [out_dir, i]
		img.save_png(out_path)
		print("Saved %s (roll=%s, orig=%s)" % [out_path, str(roll), str(orig)])

	quit(0)
