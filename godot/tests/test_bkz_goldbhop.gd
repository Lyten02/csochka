extends SceneTree

func _initialize() -> void:
	if not preload("res://tests/settings_snapshot.gd").protect(self):
		return
	print("=== Running bkz_goldbhop Full Integration Test ===")

	# 1. Setup SettingsManager
	var sm = root.get_node_or_null("SettingsManager")
	if sm == null:
		var sm_script = load("res://scripts/utils/settings_manager.gd")
		sm = sm_script.new()
		sm.name = "SettingsManager"
		root.add_child(sm)

	var maps = sm.get_available_maps()
	print("SettingsManager discovered %d maps:" % maps.size())
	var bkz_info: Dictionary = {}
	for m in maps:
		print("  - %s: %s" % [m["id"], m["desc"]])
		if m["id"] == "bkz_goldbhop":
			bkz_info = m

	assert(not bkz_info.is_empty(), "bkz_goldbhop must be present in get_available_maps()")
	assert(bkz_info["bsp"] == "res://maps/bkz_goldbhop.bsp", "BSP path should be res://maps/bkz_goldbhop.bsp")
	assert(bkz_info["glb"] == "res://maps/bkz_goldbhop.glb", "GLB path should be res://maps/bkz_goldbhop.glb")
	print("[PASS] Map discovery and metadata verified.")

	# 2. Test Main Menu UI map selection dialog
	var menu_scene = load("res://scenes/ui/main_menu.tscn")
	var menu = menu_scene.instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame

	var map_dialog = menu._map_dialog
	assert(map_dialog != null, "Map select dialog must exist in menu")
	menu._on_play_pressed()
	assert(map_dialog.visible, "Map dialog should become visible after Play clicked")

	# Select bkz_goldbhop in the list
	var bkz_idx := -1
	for i in range(map_dialog._available_maps.size()):
		if map_dialog._available_maps[i]["id"] == "bkz_goldbhop":
			bkz_idx = i
			break
	assert(bkz_idx != -1, "bkz_goldbhop must be in dialog list")
	map_dialog._map_list.select(bkz_idx)
	map_dialog._on_map_selected(bkz_idx)
	assert(map_dialog._lbl_map_name.text.contains("bkz_goldbhop"), "Map title label should display bkz_goldbhop")
	print("Dialog title: ", map_dialog._lbl_map_name.text)
	print("Dialog desc: ", map_dialog._lbl_map_desc.text)
	print("Dialog details: ", map_dialog._lbl_map_details.text)
	print("[PASS] Main menu map selection dialog UI verified.")

	# 3. Simulate user selecting bkz_goldbhop and clicking 'Начать игру'
	map_dialog._on_start_pressed()
	assert(sm.current_map_name == "bkz_goldbhop", "current_map_name must be bkz_goldbhop")
	assert(sm.current_map_bsp == "res://maps/bkz_goldbhop.bsp", "current_map_bsp must be bkz_goldbhop.bsp")
	assert(sm.current_map_glb == "res://maps/bkz_goldbhop.glb", "current_map_glb must be bkz_goldbhop.glb")
	menu.queue_free()
	await process_frame

	# 4. Load main.tscn with bkz_goldbhop active
	var main_scene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var map_node = main.get_node_or_null("Map")
	assert(map_node != null, "Map node should exist in Main")
	print("Visual map node: ", map_node.name)

	var player = main.get_node_or_null("Player")
	assert(player != null, "Player should exist in Main")
	assert(player.bsp != null, "Player bsp must be loaded")
	print("Player initial spawn origin: ", player.pm.origin)

	# In bkz_goldbhop, spawn is around (-3376, -3792, 80)
	assert(abs(player.pm.origin.x - (-3376)) < 100.0, "Player X should be near spawn -3376")
	assert(abs(player.pm.origin.y - (-3792)) < 100.0, "Player Y should be near spawn -3792")

	# Settle onto the ground
	for i in range(30):
		player.run_command({"forward": 0.0, "side": 0.0, "up": 0.0, "buttons": 0}, 10)

	print("Player origin after settle: ", player.pm.origin)
	print("Player onground: ", player.pm.onground)
	assert(player.pm.onground != -1, "Player should be standing on solid ground in bkz_goldbhop")

	# 5. Move player around (turn toward open corridor at yaw 90 / +Y)
	player.view_angles = Vector3(0, 90, 0)
	player._footstep_dist = 0.0
	var steps := 0
	var fwd_cmd := {"forward": 400.0, "side": 0.0, "up": 0.0, "buttons": CSPlayerMove.IN_FORWARD}
	for i in range(50):
		var prev = player._last_footstep_sound_index
		player.run_command(fwd_cmd, 10)
		if player._last_footstep_sound_index != prev:
			steps += 1

	print("Player moved to: ", player.pm.origin)
	print("Player horizontal speed: ", player.pm.horizontal_speed())
	print("Footsteps triggered on bkz_goldbhop: ", steps)
	assert(player.pm.horizontal_speed() > 200.0, "Player should reach running speed on bkz_goldbhop")
	assert(steps > 0, "Moving on bkz_goldbhop should trigger footsteps")

	print("\n=== ALL BKZ_GOLDBHOP TESTS PASSED SUCCESSFULLY! ===")
	quit(0)
