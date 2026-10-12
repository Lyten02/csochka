extends SceneTree

func _initialize() -> void:
	var root_node = Node3D.new()
	root.add_child(root_node)

	var cam = Camera3D.new()
	cam.fov = 74.0
	root_node.add_child(cam)

	var k = load("res://scenes/weapons/knife.tscn").instantiate()
	cam.add_child(k)

	await process_frame
	await process_frame

	var skel: Skeleton3D = k.find_child("Skeleton3D", true, false)
	var b_k = skel.find_bone("Bone25")
	var b_lh = skel.find_bone("Bone_Lefthand")
	var b_rh = skel.find_bone("Bone_Righthand")

	k.rotation_degrees = Vector3(44, -14, 16)
	k.position = Vector3(0.11, -0.02, -0.05)
	k.scale = Vector3.ONE * 0.95

	var p_handle = k.global_transform * skel.get_bone_global_pose(b_k).origin
	var p_tip = k.global_transform * Vector3(0.291276, -0.18674, -0.546812)
	var p_rh = k.global_transform * skel.get_bone_global_pose(b_rh).origin
	var p_lh = k.global_transform * skel.get_bone_global_pose(b_lh).origin

	var s_h = cam.unproject_position(p_handle)
	var s_t = cam.unproject_position(p_tip)
	var s_rh = cam.unproject_position(p_rh)
	var s_lh = cam.unproject_position(p_lh)

	var s_vec = s_t - s_h
	var angle_from_up = rad_to_deg(atan2(s_vec.x, -s_vec.y))

	print("Baseline (44, -14, 16):")
	print("  Handle screen: ", s_h)
	print("  Tip screen:    ", s_t)
	print("  RH screen:     ", s_rh)
	print("  LH screen:     ", s_lh)
	print("  Angle from up: ", angle_from_up)

	quit(0)
