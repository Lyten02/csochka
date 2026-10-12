extends SceneTree

func _initialize() -> void:
	var root_node = Node3D.new()
	root.add_child(root_node)

	var env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.15, 0.15, 0.18)
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

	# Ensure materials are unshaded and cull disabled
	var meshes: Array[Node] = knife.find_children("", "MeshInstance3D", true, false)
	for m in meshes:
		var mi := m as MeshInstance3D
		for s in range(mi.mesh.get_surface_count()):
			var mat = mi.get_surface_override_material(s)
			if mat is BaseMaterial3D:
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Test various pitch, yaw, roll and offsets
	# We want to find the view where left hand is bottom-left, right hand bottom-right, knife vertical
	var test_configs = [
		# Try combinations of rotation_degrees
		Vector3(0, 0, 0),
		Vector3(0, 90, 0),
		Vector3(0, 180, 0),
		Vector3(0, 270, 0),
		Vector3(30, 0, 0),
		Vector3(-30, 0, 0),
		Vector3(0, 0, 30),
		Vector3(0, 0, -30),
		Vector3(45, 45, 0),
		Vector3(-45, -45, 0),
		Vector3(30, -30, 15),
		Vector3(60, -20, 20),
	]

	var out_dir = "C:/Users/zxcursed/.gemini/antigravity/brain/956c65b0-33f6-41d9-8b72-e82454f3f7a8/scratch"

	for i in range(test_configs.size()):
		var rot = test_configs[i]
		knife.rotation_degrees = rot
		knife.position = Vector3(0.0, -0.15, -0.45)
		knife.scale = Vector3.ONE
		knife._base_transform = knife.transform

		await process_frame
		await process_frame

		var img = root.get_viewport().get_texture().get_image()
		img.save_png("%s/angle_test_%d.png" % [out_dir, i])
		print("Saved angle_test_%d.png (rot=%s)" % [i, str(rot)])

	quit(0)
