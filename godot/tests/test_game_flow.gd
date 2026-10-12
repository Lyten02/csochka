extends SceneTree

func _initialize() -> void:
	print("--- Running Game Flow Test ---")
	var menu_scene = load("res://scenes/ui/main_menu.tscn")
	var menu = menu_scene.instantiate()
	root.add_child(menu)

	await process_frame
	await process_frame

	# Simulate clicking Play and selecting 35hp_3
	menu._on_map_selected_launch({"name": "35hp_3", "bsp": "res://maps/35hp_3.bsp"})
	
	await process_frame
	await process_frame
	await process_frame

	# Verify main scene loaded
	var main = root.get_node_or_null("Main")
	assert(main != null, "Main scene should be active in root")
	var player = main.get_node_or_null("Player")
	assert(player != null, "Player should exist")
	var hud = main.get_node_or_null("HUD")
	assert(hud != null, "HUD should exist")
	var pause_menu = main.get_node_or_null("PauseMenu")
	assert(pause_menu != null, "PauseMenu should exist")

	print("[PASS] Scene transition: Main Menu -> Main Game scene loaded successfully!")
	print("Game flow verified!")
	quit(0)
