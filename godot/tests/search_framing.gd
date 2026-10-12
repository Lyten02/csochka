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
	cam.fov = 75.0
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
	var b_l_elbow = skel.find_bone("Bone01")
	var b_l_hand = skel.find_bone("Bone_Lefthand")
	var b_l_tip = skel.find_bone("Bone15")
	var b_r_elbow = skel.find_bone("Bone04")
	var b_r_hand = skel.find_bone("Bone_Righthand")
	var b_knife = skel.find_bone("Bone25")

	# Get bone global poses relative to Skeleton3D (untransformed):
	var p_l_elbow = skel.get_bone_global_pose(b_l_elbow).origin
	var p_l_hand = skel.get_bone_global_pose(b_l_hand).origin
	var p_l_tip = skel.get_bone_global_pose(b_l_tip).origin
	var p_r_elbow = skel.get_bone_global_pose(b_r_elbow).origin
	var p_r_hand = skel.get_bone_global_pose(b_r_hand).origin
	var m_knife = skel.get_bone_global_pose(b_knife)
	var p_knife = m_knife.origin
	# Knife tip is ~11.3 inches along +Z in bone 38 local space:
	var p_k_tip = m_knife * Vector3(0, 0, 11.3 * 0.0254)

	var vp_size = root.get_viewport().get_visible_rect().size
	print("Viewport size: ", vp_size)

	# We search:
	# Rotation: (rx, ry, rz)
	# Target screen positions (normalized):
	# Left hand ~ (0.22, 0.85)
	# Left tip ~ (0.30, 0.78)
	# Right hand ~ (0.75, 0.85)
	# Knife tip ~ (0.75, 0.15)
	
	# In camera space:
	# X_right = 0.75 -> cam_x > 0
	# X_left = 0.22 -> cam_x < 0
	# Y_hand = 0.85 -> cam_y < 0 (lower half)
	# Y_tip = 0.15 -> cam_y > 0 (upper half)
	# Z < 0 (forward)

	var best_candidates = []

	# Search over full sphere rotations:
	# Step 5 degrees around likely candidate regions or step 10 degrees full 360
	for rx in range(-180, 180, 5):
		for ry in range(-180, 180, 5):
			for rz in range(-180, 180, 5):
				var rot_b = Basis.from_euler(Vector3(deg_to_rad(rx), deg_to_rad(ry), deg_to_rad(rz)))
				
				var r_lh = rot_b * p_l_hand
				var r_rh = rot_b * p_r_hand
				var r_ktip = rot_b * p_k_tip
				var r_kbase = rot_b * p_knife
				var r_lelbow = rot_b * p_l_elbow
				var r_relbow = rot_b * p_r_elbow

				# Check 1: Left hand must be to the left of Right hand
				if r_lh.x >= r_rh.x - 0.20:
					continue
				
				# Check 2: Knife tip must be HIGHER than Knife base / Right hand
				if r_ktip.y <= r_kbase.y + 0.15:
					continue

				# Check 3: Knife blade is nearly vertical (|dx| < 0.15)
				if abs(r_ktip.x - r_kbase.x) > 0.12:
					continue

				# Check 4: Elbows must be closer to body / lower or further back than hands
				# In camera space, forearms should enter from bottom/sides
				# (r_lelbow.x < r_lh.x or r_lelbow.y < r_lh.y)
				if r_lelbow.x > r_lh.x + 0.10:
					continue
				if r_relbow.x < r_rh.x - 0.10:
					continue

				# Check 5: Hands at similar depth
				if abs(r_lh.z - r_rh.z) > 0.25:
					continue

				# Compute offset so hands are centered at X=0, Y=-0.22, Z=-0.42
				var center_hands = (r_lh + r_rh) * 0.5
				# We want right hand at X ~ +0.12, left hand at X ~ -0.12
				# Knife blade at X ~ +0.12, Y from -0.15 to +0.10, Z ~ -0.40
				var target_center = Vector3(0.0, -0.22, -0.42)
				var off = target_center - center_hands

				var cam_lh = r_lh + off
				var cam_rh = r_rh + off
				var cam_ktip = r_ktip + off
				var cam_kbase = r_kbase + off
				var cam_lelbow = r_lelbow + off
				var cam_relbow = r_relbow + off

				if cam_lh.z >= -0.05 or cam_rh.z >= -0.05 or cam_ktip.z >= -0.05:
					continue

				var s_lh = cam.unproject_position(cam_lh)
				var s_rh = cam.unproject_position(cam_rh)
				var s_ktip = cam.unproject_position(cam_ktip)

				var n_lh = Vector2(s_lh.x / vp_size.x, s_lh.y / vp_size.y)
				var n_rh = Vector2(s_rh.x / vp_size.x, s_rh.y / vp_size.y)
				var n_ktip = Vector2(s_ktip.x / vp_size.x, s_ktip.y / vp_size.y)

				# Target:
				# Left hand: x ~ 0.22, y ~ 0.85
				# Right hand: x ~ 0.75, y ~ 0.85
				# Knife tip: x ~ 0.75, y ~ 0.15
				var err_lh = (n_lh - Vector2(0.22, 0.85)).length()
				var err_rh = (n_rh - Vector2(0.75, 0.85)).length()
				var err_tip = (n_ktip - Vector2(0.75, 0.15)).length()
				var vert_penalty = abs(n_ktip.x - n_rh.x) * 3.0

				var total_score = err_lh * 1.5 + err_rh * 1.5 + err_tip * 2.0 + vert_penalty

				best_candidates.append({
					"score": total_score,
					"rot": Vector3(rx, ry, rz),
					"off": off,
					"n_lh": n_lh,
					"n_rh": n_rh,
					"n_ktip": n_ktip
				})

	best_candidates.sort_custom(func(a, b): return a["score"] < b["score"])
	print("Search completed. Found %d valid candidates." % best_candidates.size())

	var out_dir = "C:/Users/zxcursed/.gemini/antigravity/brain/956c65b0-33f6-41d9-8b72-e82454f3f7a8/scratch"
	for i in range(min(5, best_candidates.size())):
		var c = best_candidates[i]
		print("[%d] score=%.3f rot=%s off=(%.4f, %.4f, %.4f)" % [
			i, c["score"], c["rot"], c["off"].x, c["off"].y, c["off"].z
		])
		print("    n_lh=(%.2f, %.2f) n_rh=(%.2f, %.2f) n_ktip=(%.2f, %.2f)" % [
			c["n_lh"].x, c["n_lh"].y, c["n_rh"].x, c["n_rh"].y, c["n_ktip"].x, c["n_ktip"].y
		])

		knife.rotation_degrees = c["rot"]
		knife.position = c["off"]
		knife.scale = Vector3.ONE
		knife._base_transform = knife.transform

		await process_frame
		await process_frame

		var img = root.get_viewport().get_texture().get_image()
		var out_path = "%s/search_cand_%d.png" % [out_dir, i]
		img.save_png(out_path)
		print("Saved %s" % out_path)

	quit(0)
