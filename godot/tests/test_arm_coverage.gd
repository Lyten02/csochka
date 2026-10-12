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
		# 1. Scale 0.95, offset.x = 0.03
		{"rot": Vector3(45, -14, 14), "off": Vector3(0.03, -0.03, -0.05), "s": 0.95, "name": "scale95_x03"},
		# 2. Scale 0.95, offset.x = 0.00
		{"rot": Vector3(45, -14, 14), "off": Vector3(0.00, -0.03, -0.05), "s": 0.95, "name": "scale95_x00"},
		# 3. Scale 0.95, offset.x = -0.02
		{"rot": Vector3(45, -14, 14), "off": Vector3(-0.02, -0.03, -0.05), "s": 0.95, "name": "scale95_xm02"},
		# 4. Scale 1.05 (longer arm reaching to edge), offset.x = -0.01, y = -0.04
		{"rot": Vector3(46, -14, 12), "off": Vector3(-0.01, -0.04, -0.05), "s": 1.05, "name": "scale105_xm01"},
		# 5. Scale 1.10, offset.x = -0.02, y = -0.05
		{"rot": Vector3(47, -14, 10), "off": Vector3(-0.02, -0.05, -0.05), "s": 1.10, "name": "scale110_xm02"},
		# 6. Scale 1.15, offset.x = -0.03, y = -0.05
		{"rot": Vector3(48, -13, 8), "off": Vector3(-0.03, -0.05, -0.05), "s": 1.15, "name": "scale115_xm03"},
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
