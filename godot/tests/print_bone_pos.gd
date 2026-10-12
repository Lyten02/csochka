extends SceneTree

func _initialize() -> void:
	var basis := Basis(
		Vector3(0.700355, 0.616035, -0.360560),
		Vector3(-0.664523, 0.378297, -0.644438),
		Vector3(-0.260597, 0.690936, 0.674312)
	)
	var origin := Vector3(-0.124014, -0.113033, -0.876840)

	var knife_scene = load("res://scenes/weapons/knife.tscn")
	var knife = knife_scene.instantiate()
	var root_node = Node3D.new()
	root.add_child(root_node)
	root_node.add_child(knife)

	knife.transform = Transform3D(basis, origin)

	var anim: AnimationPlayer = knife.find_child("AnimationPlayer", true, false)
	if anim and anim.has_animation("idle"):
		anim.play("idle")
		anim.seek(0.0, true)

	await process_frame
	await process_frame

	var skel: Skeleton3D = knife.find_child("Skeleton3D", true, false)
	var b_lh = skel.find_bone("Bone_Lefthand")
	var b_rh = skel.find_bone("Bone_Righthand")
	var b_knife = skel.find_bone("Bone25")

	var p_lh = knife.global_transform * skel.get_bone_global_pose(b_lh).origin
	var p_rh = knife.global_transform * skel.get_bone_global_pose(b_rh).origin
	var p_knife = knife.global_transform * skel.get_bone_global_pose(b_knife).origin

	print("Left hand pos:  ", p_lh)
	print("Right hand pos: ", p_rh)
	print("Knife pos:      ", p_knife)

	quit(0)
