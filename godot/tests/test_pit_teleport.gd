extends SceneTree

const GoldSrcBspScript = preload("res://scripts/goldsrc/goldsrc_bsp.gd")
const CSPlayerScript = preload("res://scripts/player/cs_player.gd")

func _initialize() -> void:
	print("\n=== Running Pit & Floor Teleport Tests ===")

	var sm = root.get_node_or_null("SettingsManager")
	if sm == null:
		var sm_script = load("res://scripts/utils/settings_manager.gd")
		sm = sm_script.new()
		sm.name = "SettingsManager"
		root.add_child(sm)

	# -------------------------------------------------------------
	# Test 1: bhop_training_final Stage 1 Pit Teleport
	# -------------------------------------------------------------
	print("\n--- Test 1: bhop_training_final Stage 1 Pit Teleport ---")
	var bsp_path := "res://maps/bhop_training_final.bsp"
	var bsp: GoldSrcBsp = GoldSrcBspScript.load_file(ProjectSettings.globalize_path(bsp_path))
	assert(bsp != null, "Failed to load bhop_training_final.bsp")

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

	assert(player._teleport_dest.size() >= 30, "Must load all info_target destinations into _teleport_dest")
	assert(player._teleport_dest.has("1"), "Destination '1' must exist in _teleport_dest")
	assert(player._teleport_dest.has("2"), "Destination '2' must exist in _teleport_dest")
	print("[PASS] Successfully loaded %d destinations into _teleport_dest" % player._teleport_dest.size())

	# Place player above pit at stage 1
	# Stage 1 blocks are around x=384, y=-1000..0, z=-448
	# Floor pit is at z=-640
	var prev_teleports := player.teleport_count
	var initial_hp := player.health

	# Simulate falling directly onto the floor in stage 1 pit
	player.pm.origin = Vector3(384.0, -1000.0, -604.0)
	player.pm.velocity = Vector3(0.0, 0.0, -600.0) # fast fall velocity
	player.pm.onground = 0

	# Run 1 command tick (10 msec)
	player.run_command({"forward": 0.0, "side": 0.0, "up": 0.0, "buttons": 0}, 10)

	assert(player.teleport_count > prev_teleports, "Player must be teleported upon touching ground in pit")
	assert(player.health == initial_hp, "Fall into teleport pit must not inflict fall damage (HP must stay 100)")

	# Destination 1 is at (384, -1728, -448)
	var expected_dest_pos := GoldSrcBspScript.parse_vec(player._teleport_dest["1"]["origin"])
	print("Player origin after pit fall: ", player.pm.origin, " | expected: ~", expected_dest_pos)
	assert(absf(player.pm.origin.x - expected_dest_pos.x) < 5.0, "X position must match stage 1 destination")
	assert(absf(player.pm.origin.y - expected_dest_pos.y) < 5.0, "Y position must match stage 1 destination")
	print("[PASS] Falling into stage 1 pit successfully teleported player back to stage 1!")

	# -------------------------------------------------------------
	# Test 2: bhop_training_final Stage 2 Pit Teleport
	# -------------------------------------------------------------
	print("\n--- Test 2: bhop_training_final Stage 2 Pit Teleport ---")
	prev_teleports = player.teleport_count
	# Stage 2 pit trigger model *4 covers x=832..1536, y=-640..512, z=-640..-632, target='2'
	player.pm.origin = Vector3(1000.0, -100.0, -604.0)
	player.pm.velocity = Vector3(0.0, 0.0, -600.0)
	player.pm.onground = 0

	player.run_command({"forward": 0.0, "side": 0.0, "up": 0.0, "buttons": 0}, 10)

	assert(player.teleport_count > prev_teleports, "Player must be teleported upon touching stage 2 pit")
	assert(player.health == 100, "HP must remain 100")
	var dest2_pos := GoldSrcBspScript.parse_vec(player._teleport_dest["2"]["origin"])
	print("Player origin after stage 2 pit fall: ", player.pm.origin, " | expected: ~", dest2_pos)
	assert(absf(player.pm.origin.x - dest2_pos.x) < 5.0, "X position must match stage 2 destination")
	assert(absf(player.pm.origin.y - dest2_pos.y) < 5.0, "Y position must match stage 2 destination")
	print("[PASS] Falling into stage 2 pit successfully teleported player back to stage 2!")

	# -------------------------------------------------------------
	# Test 3: Multiple falls in sequence
	# -------------------------------------------------------------
	print("\n--- Test 3: Multiple falls in sequence ---")
	for i in 5:
		prev_teleports = player.teleport_count
		player.pm.origin = Vector3(384.0, -1200.0, -604.0)
		player.pm.velocity = Vector3(0.0, 0.0, -700.0)
		player.pm.onground = 0
		player.run_command({"forward": 0.0, "side": 0.0, "up": 0.0, "buttons": 0}, 10)
		assert(player.teleport_count > prev_teleports, "Iteration %d must teleport" % i)
		assert(player.health == 100, "Iteration %d must have full HP" % i)
	print("[PASS] Repeated falls reliably teleport back every time with full HP!")

	# -------------------------------------------------------------
	# Test 4: bkz_goldbhop Regression Test
	# -------------------------------------------------------------
	print("\n--- Test 4: bkz_goldbhop Teleport Regression ---")
	var bkz_bsp: GoldSrcBsp = GoldSrcBspScript.load_file(ProjectSettings.globalize_path("res://maps/bkz_goldbhop.bsp"))
	assert(bkz_bsp != null)
	player.setup(bkz_bsp)
	await process_frame

	assert(player._teleport_dest.has("tele001"), "bkz_goldbhop must load tele001")
	# Pit for stage 1 in bkz_goldbhop: trigger covers x=-3584..-3328, y=-3344..-2944, z=-80..-64
	prev_teleports = player.teleport_count
	player.pm.origin = Vector3(-3450.0, -3140.0, -40.0)
	player.pm.velocity = Vector3(0.0, 0.0, -600.0)
	player.run_command({"forward": 0.0, "side": 0.0, "up": 0.0, "buttons": 0}, 10)
	assert(player.teleport_count > prev_teleports, "bkz_goldbhop pit must teleport player")
	print("[PASS] bkz_goldbhop pit teleportation works seamlessly!")

	print("\n====================================================")
	print(">>> ALL PIT & FLOOR TELEPORT TESTS PASSED! <<<")
	print("====================================================\n")

	test_root.queue_free()
	quit(0)
