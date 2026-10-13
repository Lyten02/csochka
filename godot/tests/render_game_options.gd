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

	var out_dir = "C:/Users/zxcursed/.gemini/antigravity/brain/956c65b0-33f6-41d9-8b72-e82454f3f7a8/scratch"

	# Option 1: True Dual-Hand Framing (both hands visible, knife upright, centered/right-center)
	var base_basis := Basis(
		Vector3(-0.260597, 0.690936, 0.674312),
		Vector3(-0.664523, 0.378297, -0.644438),
		Vector3(-0.700355, -0.616035, 0.360560)
	)
	var r_z = Basis(Vector3.FORWARD, deg_to_rad(3.0))

	# Test 1A: Dual hand, standard center-right
	var b_1a = r_z * base_basis * Basis.from_scale(Vector3.ONE * 1.12)
	knife.transform = Transform3D(b_1a, Vector3(-0.15, -0.16, -0.80))
	knife._base_transform = knife.transform
	await process_frame
	await process_frame
	var img1a = root.get_viewport().get_texture().get_image()
	img1a.save_png("%s/in_game_option1A_dual_hand.png" % out_dir)

	# Test 1B: Dual hand, more centered
	var b_1b = r_z * base_basis * Basis.from_scale(Vector3.ONE * 1.15)
	knife.transform = Transform3D(b_1b, Vector3(-0.18, -0.17, -0.78))
	knife._base_transform = knife.transform
	await process_frame
	await process_frame
	var img1b = root.get_viewport().get_texture().get_image()
	img1b.save_png("%s/in_game_option1B_dual_hand_centered.png" % out_dir)

	# Option 2: Single-Arm Centered (knife centered near crosshair, arm enters from bottom-right)
	knife.transform = Transform3D.IDENTITY
	knife.scale = Vector3.ONE * 1.15
	knife.rotation_degrees = Vector3(56, -14, 6)
	knife.position = Vector3(-0.03, -0.06, -0.05)
	knife._base_transform = knife.transform
	await process_frame
	await process_frame
	var img2a = root.get_viewport().get_texture().get_image()
	img2a.save_png("%s/in_game_option2A_single_arm.png" % out_dir)

	# Option 2B: Single-Arm even more upright & centered
	knife.rotation_degrees = Vector3(60, -12, 4)
	knife.position = Vector3(-0.04, -0.07, -0.05)
	knife.scale = Vector3.ONE * 1.18
	knife._base_transform = knife.transform
	await process_frame
	await process_frame
	var img2b = root.get_viewport().get_texture().get_image()
	img2b.save_png("%s/in_game_option2B_single_arm_upright.png" % out_dir)

	print("Rendered all in-game options!")
	quit(0)
