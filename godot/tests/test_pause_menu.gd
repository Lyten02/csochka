extends SceneTree

func _initialize() -> void:
	print("--- Running Pause Menu Test ---")
	var main_scene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)

	await process_frame
	await process_frame

	var pause_menu = main.get_node("PauseMenu")
	assert(pause_menu.visible == false, "Pause menu should start hidden")

	# Open pause menu
	pause_menu.open_menu()
	assert(pause_menu.visible == true, "Pause menu should be visible")
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Mouse should be visible in menu")
	print("[PASS] Pause menu opens and reveals mouse")

	# Close pause menu
	pause_menu.close_menu()
	assert(pause_menu.visible == false, "Pause menu should close")
	assert(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Mouse should be captured after closing")
	print("[PASS] Pause menu closes and captures mouse")

	print("Pause menu tests passed!")
	quit(0)
