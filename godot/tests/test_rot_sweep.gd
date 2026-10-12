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

	var base_basis := Basis(
		Vector3(-0.260597, 0.690936, 0.674312),
		Vector3(-0.664523, 0.378297, -0.644438),
		Vector3(-0.700355, -0.616035, 0.360560)
	)

	var out_dir = "C:/Users/zxcursed/.gemini/antigravity/brain/956c65b0-33f6-41d9-8b72-e82454f3f7a8/scratch"

	# Test rotating base_basis around camera X (pitch down), Y (yaw), Z (roll)
	# to see which rotation moves the elbow towards the bottom-right corner!
	var tests = [
		{"rx":  15, "ry":   0, "rz":  0, "off": Vector3(-0.15, -0.16, -0.80), "name": "rot_pitch_p15"},
		{"rx": -15, "ry":   0, "rz":  0, "off": Vector3(-0.15, -0.16, -0.80), "name": "rot_pitch_m15"},
		{"rx":   0, "ry":  15, "rz":  0, "off": Vector3(-0.15, -0.16, -0.80), "name": "rot_yaw_p15"},
		{"rx":   0, "ry": -15, "rz":  0, "off": Vector3(-0.15, -0.16, -0.80), "name": "rot_yaw_m15"},
		{"rx":   0, "ry":   0, "rz": 15, "off": Vector3(-0.15, -0.16, -0.80), "name": "rot_roll_p15"},
		{"rx":   0, "ry":   0, "rz": -15,"off": Vector3(-0.15, -0.16, -0.80), "name": "rot_roll_m15"},
		{"rx":  25, "ry": -20, "rz":  0, "off": Vector3(-0.15, -0.16, -0.80), "name": "rot_combo_1"},
		{"rx": -25, "ry":  20, "rz":  0, "off": Vector3(-0.15, -0.16, -0.80), "name": "rot_combo_2"},
	]

	for t in tests:
		var R = Basis.from_euler(Vector3(deg_to_rad(t["rx"]), deg_to_rad(t["ry"]), deg_to_rad(t["rz"])))
		var b = R * base_basis * Basis.from_scale(Vector3.ONE * 1.15)
		knife.transform = Transform3D(b, t["off"])
		knife._base_transform = knife.transform

		await process_frame
		await process_frame

		var img = root.get_viewport().get_texture().get_image()
		var out_path = "%s/%s.png" % [out_dir, t["name"]]
		img.save_png(out_path)
		print("Saved %s" % out_path)

	quit(0)
