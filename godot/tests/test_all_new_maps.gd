extends SceneTree

const GoldSrcBspScript = preload("res://scripts/goldsrc/goldsrc_bsp.gd")
const CSPlayerScript = preload("res://scripts/player/cs_player.gd")
const MapSelectDialogScript = preload("res://scripts/ui/map_select_dialog.gd")

func _initialize() -> void:
	if not preload("res://tests/settings_snapshot.gd").protect(self):
		return
	print("\n========================================================")
	print(">>> RUNNING TESTS FOR ALL 8 NEW MAPS & TABS SYSTEM <<<")
	print("========================================================\n")

	var sm = root.get_node_or_null("SettingsManager")
	if sm == null:
		var sm_script = load("res://scripts/utils/settings_manager.gd")
		sm = sm_script.new()
		sm.name = "SettingsManager"
		root.add_child(sm)

	var new_kz_maps := ["bkz_noob", "kzy_juhxbhop", "kzru_airway", "kzsca_toonbhop"]
	var new_bhop_maps := ["bhop_tk_speedrun", "bhop_ytt_neon_light", "bhop_train", "bhop_blocks"]
	var all_new_maps := new_kz_maps + new_bhop_maps

	# --- 1. Map Catalog Verification ---
	print("--- 1. Testing Map Catalog & Categorization ---")
	var available_maps: Array = sm.get_available_maps()
	var map_dict: Dictionary = {}
	for m in available_maps:
		map_dict[m["id"]] = m

	for map_name in all_new_maps:
		assert(map_dict.has(map_name), "Map '%s' must be present in get_available_maps()" % map_name)
		var entry: Dictionary = map_dict[map_name]
		assert(FileAccess.file_exists(entry["bsp"]), "BSP file for '%s' must exist" % map_name)
		assert(FileAccess.file_exists(entry["glb"]), "GLB file for '%s' must exist" % map_name)
		assert(entry["desc"] != "", "Description for '%s' must be populated" % map_name)
		var expected_cat := "kz" if map_name in new_kz_maps else "bhop"
		assert(entry.get("category") == expected_cat, "Map '%s' category must be '%s', got '%s'" % [map_name, expected_cat, entry.get("category")])
		print("  [PASS] Catalog entry valid: %s (Category: %s, GLB: %s)" % [map_name, entry["category"], entry["glb"]])

	# --- 2. Map Selection Dialog Tabs Verification ---
	print("\n--- 2. Testing Map Selection Dialog Tabs ---")
	var dialog: CSMapSelectDialog = MapSelectDialogScript.new()
	root.add_child(dialog)
	await process_frame

	# Check KZ tab
	dialog._set_category("kz")
	for m in dialog._displayed_maps:
		assert(m.get("category") == "kz" or m["name"].begins_with("kz") or m["name"].begins_with("bkz"), "KZ tab must only show KZ maps")
	print("  [PASS] KZ tab successfully filtered %d KZ maps" % dialog._displayed_maps.size())
	assert(dialog._displayed_maps.size() >= 5, "Must have at least 5 KZ maps")

	# Check Bhop tab
	dialog._set_category("bhop")
	for m in dialog._displayed_maps:
		assert(m.get("category") == "bhop" or m["name"].contains("bhop"), "Bhop tab must only show Bhop maps")
	print("  [PASS] Bhop tab successfully filtered %d Bhop maps" % dialog._displayed_maps.size())
	assert(dialog._displayed_maps.size() >= 9, "Must have at least 9 Bhop maps")

	dialog.queue_free()

	# --- 3. Per-Map Functional Verification ---
	for map_name in all_new_maps:
		print("\n--------------------------------------------------------")
		print(">>> Testing Map: %s <<<" % map_name)
		print("--------------------------------------------------------")

		var bsp_path := "res://maps/%s.bsp" % map_name
		var global_bsp_path := ProjectSettings.globalize_path(bsp_path)
		var bsp: GoldSrcBsp = GoldSrcBspScript.load_file(global_bsp_path)
		assert(bsp != null, "Failed to load %s" % bsp_path)

		var glb_path := "res://maps/%s.glb" % map_name
		var glb_res = ResourceLoader.load(glb_path)
		assert(glb_res != null, "Failed to load PackedScene for %s" % glb_path)
		var glb_inst: Node = glb_res.instantiate()
		assert(glb_inst != null, "Failed to instantiate GLB for %s" % map_name)
		glb_inst.free()

		var test_root := Node3D.new()
		var player: CSPlayer = CSPlayerScript.new()
		player.name = "Player"
		var cam := Camera3D.new()
		cam.name = "Camera3D"
		player.add_child(cam)
		test_root.add_child(player)
		root.add_child(test_root)

		player.setup(bsp)
		player.set_physics_process(false)

		await process_frame
		await process_frame

		# (a) Check Spawns
		assert(player.spawns.size() > 0, "Map %s must have spawns" % map_name)
		print("  [PASS] Spawns found: %d" % player.spawns.size())

		# (b) Check Buttons
		var start_btn: Dictionary = {}
		var stop_btn: Dictionary = {}
		for btn in player.kz_buttons:
			if btn["type"] == "start":
				start_btn = btn
			elif btn["type"] == "stop":
				stop_btn = btn

		assert(not start_btn.is_empty(), "Map %s must have a START button" % map_name)
		assert(not stop_btn.is_empty(), "Map %s must have a STOP button" % map_name)
		print("  [PASS] Start button: %s (model: %s, target: %s)" % [start_btn["type"], start_btn["model"], start_btn["target"]])
		print("  [PASS] Stop button: %s (model: %s, target: %s)" % [stop_btn["type"], stop_btn["model"], stop_btn["target"]])

		# (c) Test Timer Activation via Start Button
		var timer_state := {"started": false, "stopped": false, "final_time": 0.0}
		player.kz_timer_started.connect(func(): timer_state["started"] = true)
		player.kz_timer_stopped.connect(func(t: float, _best: bool):
			timer_state["stopped"] = true
			timer_state["final_time"] = t
		)

		_aim_at_button(player, start_btn)
		var used_start := player._try_use_button()
		assert(used_start, "Start button use must return true")
		assert(player.kz_timer_active, "KZ timer must be active after start button use")
		assert(timer_state["started"], "kz_timer_started signal must have fired")

		# Advance physics time
		player.run_command({"forward": 0.0, "side": 0.0, "up": 0.0, "buttons": 0}, 50)
		assert(player.kz_timer_elapsed > 0.04, "Timer must have elapsed time")

		# Stop button
		_aim_at_button(player, stop_btn)
		player._last_button_use_msec = -1000
		var used_stop := player._try_use_button()
		assert(used_stop, "Stop button use must return true")
		assert(not player.kz_timer_active, "KZ timer must be inactive after stop button use")
		assert(timer_state["stopped"], "kz_timer_stopped signal must have fired")
		assert(timer_state["final_time"] > 0.04, "Final recorded time must be positive")
		print("  [PASS] Timer test passed: Start -> %0.3fs -> Stop!" % timer_state["final_time"])

		# (d) Test Pit Fall Teleportation
		var prev_teleports := player.teleport_count
		var hp_before := player.health

		var pit_trig: GoldSrcBsp.PhysEnt = null
		for trig in bsp.triggers:
			if trig.classname == "trigger_teleport":
				pit_trig = trig
				break

		var spawn_pos := GoldSrcBspScript.parse_vec(player.spawns[0]["origin"])
		if pit_trig != null:
			player.pm.origin = (pit_trig.mins + pit_trig.maxs) * 0.5
		else:
			player.pm.origin = Vector3(spawn_pos.x, spawn_pos.y, spawn_pos.z - 80.0)
		player.pm.velocity = Vector3(0.0, 0.0, -600.0)
		player.pm.onground = 0

		player.run_command({"forward": 0.0, "side": 0.0, "up": 0.0, "buttons": 0}, 10)

		assert(player.teleport_count > prev_teleports, "Map %s must teleport player upon pit fall" % map_name)
		assert(player.health == hp_before, "Map %s must not inflict fall damage on pit teleport" % map_name)
		print("  [PASS] Pit fall teleported back safely (HP: %d)" % player.health)

		# (e) Test Standing at Spawn: MUST NEVER timeout or teleport!
		player.respawn(0)
		prev_teleports = player.teleport_count
		var spawn_timeout := {"timeout": false}
		player.bhop_block_timeout.connect(func(): spawn_timeout["timeout"] = true)
		for _step in 50:
			player.run_command({"forward": 0.0, "side": 0.0, "up": 0.0, "buttons": 0}, 10)
		assert(not spawn_timeout["timeout"], "Standing at spawn in %s must NEVER trigger timeout" % map_name)
		assert(player.block_stand_timer == 0.0, "Standing at spawn in %s must keep block_stand_timer at 0" % map_name)
		assert(player.teleport_count == prev_teleports, "Standing at spawn in %s must not teleport player" % map_name)
		print("  [PASS] Standing at spawn for 0.5s is completely safe (no false timeout)")

		# (f) Test Standing on Bhop Block Timeout (>0.35s) for Bhop maps
		var block_ent: GoldSrcBsp.PhysEnt = null
		if map_name in new_bhop_maps:
			for pe in bsp.physents:
				if pe.classname in ["func_door", "func_conveyor", "func_wall_toggle"]:
					var ent_pos := (pe.mins + pe.maxs) * 0.5
					if not player._is_in_spawn_area(ent_pos):
						block_ent = pe
						break
		if block_ent != null:
			prev_teleports = player.teleport_count
			var block_state := {"timeout": false}
			player.bhop_block_timeout.connect(func(): block_state["timeout"] = true)
			player.pm.onground = block_ent.index
			player.pm.origin = Vector3((block_ent.mins.x + block_ent.maxs.x) * 0.5, (block_ent.mins.y + block_ent.maxs.y) * 0.5, block_ent.maxs.z + 37.0)

			for _step in 45:
				player.run_command({"forward": 0.0, "side": 0.0, "up": 0.0, "buttons": 0}, 10)

			assert(player.teleport_count > prev_teleports, "Map %s must teleport player after standing on bhop block >0.35s" % map_name)
			assert(block_state["timeout"], "bhop_block_timeout signal must be emitted")
			print("  [PASS] Standing on bhop block for >0.35s successfully triggered timeout teleport!")

		test_root.queue_free()

	print("\n========================================================")
	print(">>> ALL 8 NEW MAPS & TABS SYSTEM PASSED 100%! <<<")
	print("========================================================\n")
	quit(0)


func _aim_at_button(player: CSPlayer, btn: Dictionary) -> void:
	var center: Vector3 = btn["center"]
	for offset_dir in [Vector3(0, -35, 0), Vector3(0, 35, 0), Vector3(-35, 0, 0), Vector3(35, 0, 0), Vector3(0, 0, -35), Vector3(0, 0, 35)]:
		player.pm.origin = center + offset_dir
		player.pm.origin.z = center.z - player.pm.view_ofs.z
		var eye := player.pm.origin + player.pm.view_ofs
		var to_btn := (center - eye).normalized()
		var yaw := rad_to_deg(atan2(to_btn.y, to_btn.x))
		var pitch := rad_to_deg(-asin(clampf(to_btn.z, -1.0, 1.0)))
		player.view_angles = Vector3(pitch, yaw, 0.0)
		if not player.get_aimed_button().is_empty():
			return
