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

	# Test 6 variations of centering and uprightness:
	var variations = [
		# Option A: Center-Right (CS 1.6 classic style, knife blade at ~65% screen width, upright)
		{"rot": Vector3(46, -14, 12), "off": Vector3(-0.01, -0.06, -0.10), "s": 0.75, "name": "opt_A_center_right"},
		
		# Option B: More centered (knife blade at ~58% screen width, upright)
		{"rot": Vector3(46, -14, 12), "off": Vector3(-0.04, -0.06, -0.10), "s": 0.75, "name": "opt_B_mid_center"},
		
		# Option C: Even more centered (knife blade at ~52% screen width, near crosshair)
		{"rot": Vector3(46, -14, 12), "off": Vector3(-0.07, -0.06, -0.10), "s": 0.75, "name": "opt_C_dead_center"},

		# Option D: More vertical blade (~85-90 degrees), center-right
		{"rot": Vector3(50, -12, 4), "off": Vector3(-0.02, -0.07, -0.10), "s": 0.75, "name": "opt_D_upright_center_right"},

		# Option E: More vertical blade (~85-90 degrees), mid-center
		{"rot": Vector3(50, -12, 4), "off": Vector3(-0.05, -0.07, -0.10), "s": 0.75, "name": "opt_E_upright_mid"},

		# Option F: Slanted forearm coming from bottom right, vertical blade, mid-center
		{"rot": Vector3(52, -10, 0), "off": Vector3(-0.04, -0.07, -0.09), "s": 0.72, "name": "opt_F_balanced"},
	]

	for i in range(variations.size()):
		var v = variations[i]
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
