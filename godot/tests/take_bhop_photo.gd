extends SceneTree

func _initialize():
	print("--- Taking bhop_training_final photos ---")
	var sm = root.get_node_or_null("SettingsManager")
	if sm == null:
		var sm_script = load("res://scripts/utils/settings_manager.gd")
		sm = sm_script.new()
		sm.name = "SettingsManager"
		root.add_child(sm)

	sm.current_map_name = "bhop_training_final"
	sm.current_map_bsp = "res://maps/bhop_training_final.bsp"
	sm.current_map_glb = "res://maps/bhop_training_final.glb"
	sm.save_settings()

	var main_scene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)

	var player = main.get_node("Player")
	player.set_physics_process(false) # we manually position player
	var cam: Camera3D = player.get_node("Camera3D")
	cam.current = true

	# Wait for map loading and frame rendering
	for i in 10:
		await process_frame

	print("Current map node name: ", main.get_node("Map").name)

	# 1. Spawn looking at start button
	# Start button is at (4, -1680, -464)
	player.pm.origin = Vector3(80.0, -1680.0, -460.0)
	player.view_angles = Vector3(0.0, 180.0, 0.0)

	for i in 5:
		await process_frame

	var img1 = root.get_viewport().get_texture().get_image()
	if img1 and not img1.is_empty():
		img1.save_png(ProjectSettings.globalize_path("res://tests/photo_start_button.png"))
		print("Saved photo_start_button.png")

	# 2. Looking down the bhop course from stage 1
	player.pm.origin = Vector3(384.0, -1728.0, -400.0)
	player.view_angles = Vector3(-15.0, 90.0, 0.0)

	for i in 5:
		await process_frame

	var img2 = root.get_viewport().get_texture().get_image()
	if img2 and not img2.is_empty():
		img2.save_png(ProjectSettings.globalize_path("res://tests/photo_bhop_course.png"))
		print("Saved photo_bhop_course.png")

	# 3. Looking at finish button
	# Finish button is at (-3136, 1528, -464)
	player.pm.origin = Vector3(-3136.0, 1450.0, -460.0)
	player.view_angles = Vector3(0.0, 90.0, 0.0)

	for i in 5:
		await process_frame

	var img3 = root.get_viewport().get_texture().get_image()
	if img3 and not img3.is_empty():
		img3.save_png(ProjectSettings.globalize_path("res://tests/photo_finish_button.png"))
		print("Saved photo_finish_button.png")

	print("--- Done photos ---")
	quit(0)
