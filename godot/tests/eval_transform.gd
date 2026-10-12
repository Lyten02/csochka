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
	cam.fov = 73.74
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

	var skel: Skeleton3D = knife.find_child("Skeleton3D", true, false)
	var b_left = skel.find_bone("Bone_Lefthand")
	var b_right = skel.find_bone("Bone_Righthand")
	var b_knife = skel.find_bone("Bone25")

	var vp_size = root.get_viewport().get_visible_rect().size
	print("Viewport size: ", vp_size)

	# Target normalized positions in CS 1.6 16:9 view:
	# Left hand around X: 0.18-0.25, Y: 0.75-0.90
	# Right hand around X: 0.75-0.85, Y: 0.80-0.95
	# Knife tip around X: 0.75-0.85, Y: 0.10-0.25
	# Knife blade upright: |X_tip - X_right| < 0.08
	
	# We want to find (rot_x, rot_y, rot_z, off_x, off_y, off_z, scale)
	# First, let's test a search over rotation angles
	var best_candidates = []
	
	# In local space of the knife model:
	var l_orig = skel.get_bone_global_pose(b_left).origin
	var r_orig = skel.get_bone_global_pose(b_right).origin
	var k_orig = skel.get_bone_global_pose(b_knife).origin
	# Knife tip is ~11.3 units along +Z in bone 38 local space
	var k_bone_m = skel.get_bone_global_pose(b_knife)
	# Bone 38 local +Z tip
	var tip_orig = k_bone_m * Vector3(0, 0, 11.3 * 0.0254)
	
	print("Base model points:")
	print("  Left hand:  ", l_orig)
	print("  Right hand: ", r_orig)
	print("  Knife hand: ", k_orig)
	print("  Knife tip:  ", tip_orig)

	# Let's search rotations (pitch, yaw, roll)
	for rx in range(-180, 180, 10):
		for ry in range(-180, 180, 10):
			for rz in range(-180, 180, 10):
				var rot_b = Basis.from_euler(Vector3(deg_to_rad(rx), deg_to_rad(ry), deg_to_rad(rz)))
				var l_r = rot_b * l_orig
				var r_r = rot_b * r_orig
				var tip_r = rot_b * tip_orig
				
				# Check if in this orientation:
				# 1. Left hand is to the left of Right hand (l_r.x < r_r.x - 0.2)
				if l_r.x >= r_r.x - 0.15:
					continue
				# 2. Knife tip is HIGHER than Right hand (tip_r.y > r_r.y + 0.15)
				if tip_r.y <= r_r.y + 0.15:
					continue
				# 3. Knife tip is roughly above Right hand (|tip_r.x - r_r.x| < 0.12)
				if abs(tip_r.x - r_r.x) > 0.12:
					continue
				# 4. Both hands are at roughly similar depth (|l_r.z - r_r.z| < 0.25)
				if abs(l_r.z - r_r.z) > 0.25:
					continue
				
				# We have a candidate orientation!
				# Now calculate translation so that:
				# Center between hands (l_r + r_r)*0.5 is at X=0, Y=-0.22, Z=-0.38
				var hand_center = (l_r + r_r) * 0.5
				var target_center = Vector3(0.0, -0.20, -0.38)
				var off = target_center - hand_center
				
				var l_cam = l_r + off
				var r_cam = r_r + off
				var tip_cam = tip_r + off
				
				# Check projectable
				if l_cam.z >= -0.05 or r_cam.z >= -0.05 or tip_cam.z >= -0.05:
					continue
				
				var p_l = cam.unproject_position(cam.global_transform * l_cam)
				var p_r = cam.unproject_position(cam.global_transform * r_cam)
				var p_tip = cam.unproject_position(cam.global_transform * tip_cam)
				
				var n_l = Vector2(p_l.x / vp_size.x, p_l.y / vp_size.y)
				var n_r = Vector2(p_r.x / vp_size.x, p_r.y / vp_size.y)
				var n_tip = Vector2(p_tip.x / vp_size.x, p_tip.y / vp_size.y)
				
				# Score closeness to target:
				# Target: n_l ~ (0.20, 0.85), n_r ~ (0.80, 0.85), n_tip ~ (0.80, 0.15)
				var score = (
					abs(n_l.x - 0.20) * 1.5 + abs(n_l.y - 0.85) * 1.0 +
					abs(n_r.x - 0.80) * 1.5 + abs(n_r.y - 0.85) * 1.0 +
					abs(n_tip.x - 0.80) * 2.0 + abs(n_tip.y - 0.15) * 2.0
				)
				
				best_candidates.append({
					"score": score,
					"rot": Vector3(rx, ry, rz),
					"off": off,
					"n_l": n_l,
					"n_r": n_r,
					"n_tip": n_tip
				})

	best_candidates.sort_custom(func(a, b): return a["score"] < b["score"])
	print("Found %d matching candidate orientations!" % best_candidates.size())
	for i in range(min(10, best_candidates.size())):
		var c = best_candidates[i]
		print("[%d] score=%.3f rot=%s off=(%.3f, %.3f, %.3f)" % [
			i, c["score"], c["rot"], c["off"].x, c["off"].y, c["off"].z
		])
		print("    n_left=(%.2f, %.2f) n_right=(%.2f, %.2f) n_tip=(%.2f, %.2f)" % [
			c["n_l"].x, c["n_l"].y, c["n_r"].x, c["n_r"].y, c["n_tip"].x, c["n_tip"].y
		])

	# Render screenshot of top 3 candidates!
	for i in range(min(3, best_candidates.size())):
		var c = best_candidates[i]
		knife.position = c["off"]
		knife.rotation_degrees = c["rot"]
		knife.scale = Vector3.ONE
		knife._base_transform = knife.transform
		
		await process_frame
		await process_frame
		
		var img = root.get_viewport().get_texture().get_image()
		var out_path = "C:/Users/zxcursed/.gemini/antigravity/brain/956c65b0-33f6-41d9-8b72-e82454f3f7a8/scratch/candidate_%d.png" % i
		img.save_png(out_path)
		print("Saved candidate %d to %s" % [i, out_path])

	quit(0)
