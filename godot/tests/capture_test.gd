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
	cam.fov = 65.0
	cam.near = 0.02
	cam.far = 100.0
	cam.current = true
	root_node.add_child(cam)

	var knife_scene = load("res://scenes/weapons/knife.tscn")
	var knife = knife_scene.instantiate()
	cam.add_child(knife) # _ready() runs here!

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

	# Solved exact Kabsch transform with column 0 negated for knife.glb X flip:
	var basis := Basis(
		-Vector3(0.655724, 0.663357, 0.360600),
		Vector3(-0.689270, 0.331025, 0.644400),
		Vector3(-0.308160, 0.671038, -0.674300)
	)
	var origin := Vector3(-0.050302, -0.121783, -0.316948)

	knife.transform = Transform3D(basis, origin)
	knife._base_transform = knife.transform

	await process_frame
	await process_frame

	var skel: Skeleton3D = knife.find_child("Skeleton3D", true, false)
	for bi in [3, 21, 38]:
		var bname = skel.get_bone_name(bi)
		var p_local = skel.get_bone_global_pose(bi).origin
		var p_global = knife.global_transform * p_local
		var p_screen = cam.unproject_position(p_global)
		print("Bone %d (%s): local=%s, global=%s, screen=%s" % [bi, bname, str(p_local), str(p_global), str(p_screen)])

	var img = root.get_viewport().get_texture().get_image()
	var out_path = "C:/Users/zxcursed/.gemini/antigravity/brain/956c65b0-33f6-41d9-8b72-e82454f3f7a8/scratch/kabsch_exact_rendered.png"
	img.save_png(out_path)
	print("Saved kabsch_exact_rendered.png successfully!")
	quit(0)
