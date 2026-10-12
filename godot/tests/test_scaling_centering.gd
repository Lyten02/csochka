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

	var skel: Skeleton3D = knife.find_child("Skeleton3D", true, false)
	var b_k = skel.find_bone("Bone25")
	var b_lh = skel.find_bone("Bone_Lefthand")
	var b_rh = skel.find_bone("Bone_Righthand")

	var vp_size = root.get_viewport().get_visible_rect().size
	var out_dir = "C:/Users/zxcursed/.gemini/antigravity/brain/956c65b0-33f6-41d9-8b72-e82454f3f7a8/scratch"

	# Let's test combinations of:
	# scale: 0.60, 0.65, 0.70, 0.75, 0.80
	# rot: Vector3(44, -14, 16), Vector3(48, -12, 10), Vector3(50, -10, 6)
	# off: x around -0.02 to +0.03, y around -0.05 to -0.10, z around -0.08 to -0.16
	var test_set = [
		{"scale": 0.60, "rot": Vector3(44, -14, 16), "off": Vector3(0.01, -0.06, -0.10), "name": "s60_baseline_rot"},
		{"scale": 0.65, "rot": Vector3(44, -14, 16), "off": Vector3(0.01, -0.06, -0.10), "name": "s65_baseline_rot"},
		{"scale": 0.70, "rot": Vector3(44, -14, 16), "off": Vector3(0.01, -0.06, -0.10), "name": "s70_baseline_rot"},
		
		{"scale": 0.60, "rot": Vector3(48, -12, 10), "off": Vector3(0.01, -0.06, -0.10), "name": "s60_rot48"},
		{"scale": 0.65, "rot": Vector3(48, -12, 10), "off": Vector3(0.01, -0.06, -0.10), "name": "s65_rot48"},
		{"scale": 0.70, "rot": Vector3(48, -12, 10), "off": Vector3(0.01, -0.06, -0.10), "name": "s70_rot48"},

		{"scale": 0.65, "rot": Vector3(48, -12, 10), "off": Vector3(0.03, -0.06, -0.10), "name": "s65_rot48_x03"},
		{"scale": 0.65, "rot": Vector3(48, -12, 10), "off": Vector3(-0.01, -0.06, -0.10), "name": "s65_rot48_xm01"},
		
		{"scale": 0.65, "rot": Vector3(52, -10, 4), "off": Vector3(0.01, -0.07, -0.10), "name": "s65_rot52"},
		{"scale": 0.65, "rot": Vector3(52, -10, 4), "off": Vector3(0.03, -0.07, -0.10), "name": "s65_rot52_x03"},
		{"scale": 0.70, "rot": Vector3(52, -10, 4), "off": Vector3(0.02, -0.07, -0.10), "name": "s70_rot52"},
		{"scale": 0.70, "rot": Vector3(52, -10, 4), "off": Vector3(0.00, -0.07, -0.10), "name": "s70_rot52_x00"},
	]

	for i in range(test_set.size()):
		var t = test_set[i]
		knife.rotation_degrees = t["rot"]
		knife.position = t["off"]
		knife.scale = Vector3.ONE * t["scale"]
		knife._base_transform = knife.transform

		await process_frame
		await process_frame

		var p_handle = knife.global_transform * skel.get_bone_global_pose(b_k).origin
		var p_tip = knife.global_transform * Vector3(0.291276, -0.18674, -0.546812)
		var p_rh = knife.global_transform * skel.get_bone_global_pose(b_rh).origin
		var p_lh = knife.global_transform * skel.get_bone_global_pose(b_lh).origin

		var s_h = cam.unproject_position(p_handle)
		var s_t = cam.unproject_position(p_tip)
		var s_rh = cam.unproject_position(p_rh)
		var s_lh = cam.unproject_position(p_lh)

		var s_vec = s_t - s_h
		var angle_from_up = rad_to_deg(atan2(s_vec.x, -s_vec.y))

		print("[%2d] %s: angle=%.1f deg | Knife: (%.2f, %.2f) -> (%.2f, %.2f) | RH: (%.2f, %.2f) | LH: (%.2f, %.2f)" % [
			i, t["name"], angle_from_up,
			s_h.x / vp_size.x, s_h.y / vp_size.y,
			s_t.x / vp_size.x, s_t.y / vp_size.y,
			s_rh.x / vp_size.x, s_rh.y / vp_size.y,
			s_lh.x / vp_size.x, s_lh.y / vp_size.y
		])

		var img = root.get_viewport().get_texture().get_image()
		var out_path = "%s/test_%s.png" % [out_dir, t["name"]]
		img.save_png(out_path)

	quit(0)
