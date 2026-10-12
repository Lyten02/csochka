extends SceneTree

func _initialize() -> void:
	var model_scene = load("res://models/knife.glb")
	var model = model_scene.instantiate()
	var root_node = Node3D.new()
	root.add_child(root_node)
	root_node.add_child(model)

	var anim: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if anim and anim.has_animation("idle"):
		anim.play("idle")
		anim.seek(0.0, true)

	await process_frame
	await process_frame

	var skel: Skeleton3D = model.find_child("Skeleton3D", true, false)
	var b_lh = skel.find_bone("Bone_Lefthand")
	var b_rh = skel.find_bone("Bone_Righthand")
	var b_knife = skel.find_bone("Bone25")

	print("Skeleton3D global pos of bone 3 (Left hand): ", skel.get_bone_global_pose(b_lh).origin)
	print("Skeleton3D global pos of bone 21 (Right hand):", skel.get_bone_global_pose(b_rh).origin)
	print("Skeleton3D global pos of bone 38 (Knife):     ", skel.get_bone_global_pose(b_knife).origin)

	quit(0)
