extends SceneTree

func _initialize() -> void:
	var knife_scene = load("res://scenes/weapons/knife.tscn")
	var knife = knife_scene.instantiate()
	var root_node = Node3D.new()
	root.add_child(root_node)
	root_node.add_child(knife)

	var anim: AnimationPlayer = knife.find_child("AnimationPlayer", true, false)
	if anim and anim.has_animation("idle"):
		anim.play("idle")
		anim.seek(0.0, true)

	await process_frame
	await process_frame

	var skel: Skeleton3D = knife.find_child("Skeleton3D", true, false)
	print("Skeleton bone count: ", skel.get_bone_count())
	for i in range(skel.get_bone_count()):
		var bname = skel.get_bone_name(i)
		var t = skel.get_bone_global_pose(i)
		print("Bone %2d (%15s): origin=%s" % [i, bname, str(t.origin)])

	quit(0)
