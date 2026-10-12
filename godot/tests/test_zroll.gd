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

	# Baseline rotation: (47, -14, 10)
	var base_rot = Basis.from_euler(Vector3(deg_to_rad(47), deg_to_rad(-14), deg_to_rad(10)))

	# Let's rotate around camera Z (in-plane roll):
	for roll in [-35, -25, -15, 0, 15, 25, 35]:
		var r_z = Basis(Vector3.FORWARD, deg_to_rad(roll))
		var b = r_z * base_rot * Basis.from_scale(Vector3.ONE * 1.15)
		knife.transform = Transform3D(b, Vector3(-0.02, -0.05, -0.05))
		knife._base_transform = knife.transform

		await process_frame
		await process_frame

		var img = root.get_viewport().get_texture().get_image()
		var out_path = "%s/zroll_%d.png" % [out_dir, roll]
		img.save_png(out_path)
		print("Saved %s" % out_path)

	quit(0)
