extends SceneTree

func _initialize() -> void:
	var main_scene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)

	await process_frame
	await process_frame
	await process_frame

	var player = main.get_node("Player")
	var cam: Camera3D = player.get_node("Camera3D")
	var knife = cam.get_node("Knife")

	var anim: AnimationPlayer = knife.find_child("AnimationPlayer", true, false)
	if anim and anim.has_animation("idle"):
		anim.play("idle")
		anim.seek(0.0, true)

	var base_basis := Basis(
		Vector3(-0.260597, 0.690936, 0.674312),
		Vector3(-0.664523, 0.378297, -0.644438),
		Vector3(-0.700355, -0.616035, 0.360560)
	)
	var r_z = Basis(Vector3.FORWARD, deg_to_rad(3.0))
	var b_1b = r_z * base_basis * Basis.from_scale(Vector3.ONE * 1.15)
	knife.transform = Transform3D(b_1b, Vector3(-0.18, -0.17, -0.78))
	knife._base_transform = knife.transform

	var skel: Skeleton3D = knife.find_child("Skeleton3D", true, false)
	var b_elbow = skel.find_bone("Bone04")
	print("Elbow bone index: ", b_elbow)
	var orig_pose = skel.get_bone_pose(b_elbow)
	print("Original elbow pose: pos=", orig_pose.origin, " rot=", orig_pose.basis.get_euler())

	quit(0)
