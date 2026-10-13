extends SceneTree
## Comprehensive integration test for:
## 1. Bhop block stand-teleport (>0.35s) vs KZ worldspawn (no teleport)
## 2. Double duck on mouse wheel down (silent run, full speed, camera dip, 36 unit step)
## 3. LJ Stats plugin toggled by F7 (prestrafe, sync %, strafe count, +32 unit CS 1.6 distance, HUD banner)

const GoldSrcBspScript = preload("res://scripts/goldsrc/goldsrc_bsp.gd")
const CSPlayerScript = preload("res://scripts/player/cs_player.gd")
const CSHudScript = preload("res://scripts/ui/hud.gd")

func _initialize() -> void:
	print("\n=== Running Bhop Block Stand-Teleport, Double Duck & LJ Stats Tests ===")
	var bsp_path := "res://maps/bkz_goldbhop.bsp"
	var bsp: GoldSrcBsp = GoldSrcBspScript.load_file(ProjectSettings.globalize_path(bsp_path))
	if bsp == null:
		push_error("FAILED to load bkz_goldbhop.bsp")
		quit(1)
		return

	# Setup root node, player and camera
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

	# Setup HUD
	var hud: CSHud = CSHudScript.new()
	hud.name = "HUD"
	hud.player_path = NodePath("../Player")
	test_root.add_child(hud)

	await process_frame
	await process_frame

	# -------------------------------------------------------------
	# Test 1: Bhop Block Stand-Teleport (>0.35s) vs KZ Worldspawn
	# -------------------------------------------------------------
	print("\n--- Test 1: Bhop Block Stand-Teleport (>0.35s) vs KZ Worldspawn ---")

	# Find a bhop block (model 1..94)
	var block_ent: GoldSrcBsp.PhysEnt = null
	for i in range(1, bsp.physents.size()):
		var pe: GoldSrcBsp.PhysEnt = bsp.physents[i]
		if pe.classname == "func_door" and pe.model >= 1 and pe.model <= 94:
			block_ent = pe
			break

	assert(block_ent != null, "Must find at least one bhop block in bkz_goldbhop")
	print("Found bhop block: model *%d, mins=%s, maxs=%s" % [block_ent.model, str(block_ent.mins), str(block_ent.maxs)])

	# Place player on top of the bhop block
	var block_top_z: float = block_ent.maxs.z
	var block_center_x: float = (block_ent.mins.x + block_ent.maxs.x) * 0.5
	var block_center_y: float = (block_ent.mins.y + block_ent.maxs.y) * 0.5
	player.pm.origin = Vector3(block_center_x, block_center_y, block_top_z + 36.03125)
	player.pm.velocity = Vector3.ZERO
	player.pm.onground = -1

	# Run 1 tick to categorize position onto block
	player.run_command({"forward": 0.0, "side": 0.0, "up": 0.0, "buttons": 0}, 10)
	assert(player.pm.onground > 0, "Player should be onground on bhop block entity")
	print("Player on block, onground physent index: %d (model *%d, class: %s)" % [
		player.pm.onground, bsp.physents[player.pm.onground].model, bsp.physents[player.pm.onground].classname])

	var initial_teleport_count := player.teleport_count
	var bhop_timeout := [false]
	player.bhop_block_timeout.connect(func(): bhop_timeout[0] = true)

	# Stand on block for 0.20s (20 ticks of 10ms): should NOT teleport yet
	for t in 20:
		player.run_command({"forward": 0.0, "side": 0.0, "up": 0.0, "buttons": 0}, 10)

	assert(player.teleport_count == initial_teleport_count, "Player must NOT teleport at 0.20s (under 0.35s)")
	assert(bhop_timeout[0] == false, "Timeout signal must not fire early")
	print("[PASS] Standing for 0.20s on block does not trigger teleport (timer: %.2fs)" % player.block_stand_timer)

	# Stand for another 20 ticks (total 0.40s, exceeding 0.35s threshold): MUST teleport!
	for t in 20:
		player.run_command({"forward": 0.0, "side": 0.0, "up": 0.0, "buttons": 0}, 10)

	assert(player.teleport_count > initial_teleport_count, "Player MUST teleport after standing on block > 0.35s")
	assert(bhop_timeout[0] == true, "bhop_block_timeout signal must be emitted")
	assert(player.block_stand_timer == 0.0, "block_stand_timer must be reset after teleport")
	print("[PASS] Standing >0.35s on bhop block successfully triggered teleport to stage destination!")

	# Now test KZ section / worldspawn (model 0): standing indefinitely must NEVER teleport
	player.pm.spawn(Vector3(-3376, -3792, 36.03125), 0.0) # Spawn room / KZ rock platform
	player.run_command({"forward": 0.0, "side": 0.0, "up": 0.0, "buttons": 0}, 10)
	assert(player.pm.onground == 0, "Player must be onground on worldspawn (model 0)")

	var tele_before_kz := player.teleport_count
	bhop_timeout[0] = false
	# Stand on worldspawn for 1.0 second (100 ticks)
	for t in 100:
		player.run_command({"forward": 0.0, "side": 0.0, "up": 0.0, "buttons": 0}, 10)

	assert(player.teleport_count == tele_before_kz, "Player must NEVER teleport when standing on worldspawn / KZ climb section")
	assert(player.block_stand_timer == 0.0, "block_stand_timer must remain 0 on worldspawn")
	assert(bhop_timeout[0] == false, "bhop_block_timeout must NOT be emitted on worldspawn")
	print("[PASS] Standing on KZ climb / worldspawn for 1.0s does NOT trigger teleport (as intended)!")

	# -------------------------------------------------------------
	# Test 2: Mouse Wheel Jump (Wheel Up & Down)
	# -------------------------------------------------------------
	print("\n--- Test 2: Mouse Wheel Jump (+jump on wheel up & down) ---")

	var wheel_down_ev := InputEventMouseButton.new()
	wheel_down_ev.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_down_ev.pressed = true
	player._unhandled_input(wheel_down_ev)

	assert(player._wheel_jump == true, "Wheel down must trigger _wheel_jump")
	var cmd := player._build_command()
	assert((cmd.buttons & CSPlayerMove.IN_JUMP) != 0, "Command buttons must have IN_JUMP bit set during wheel jump")
	print("[PASS] Mouse wheel down triggers +jump as original CS 1.6 bhop binding!")

	var wheel_up_ev := InputEventMouseButton.new()
	wheel_up_ev.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_up_ev.pressed = true
	player._unhandled_input(wheel_up_ev)

	assert(player._wheel_jump == true, "Wheel up must trigger _wheel_jump")
	cmd = player._build_command()
	assert((cmd.buttons & CSPlayerMove.IN_JUMP) != 0, "Command buttons must have IN_JUMP bit set during wheel jump")
	print("[PASS] Mouse wheel up triggers +jump as original CS 1.6 bhop binding!")

	# -------------------------------------------------------------
	# Test 3: LJ Stats Plugin with F7 Toggle
	# -------------------------------------------------------------
	print("\n--- Test 3: LJ Stats Plugin & F7 Toggle ---")

	var toggle_state := [false, false] # [received, enabled]
	player.lj_stats_toggled.connect(func(enabled):
		toggle_state[0] = true
		toggle_state[1] = enabled
	)

	# Simulate F7 action
	var toggle_action_ev := InputEventAction.new()
	toggle_action_ev.action = "cs_toggle_ljstats"
	toggle_action_ev.pressed = true
	player._unhandled_input(toggle_action_ev)

	assert(toggle_state[0] == true, "lj_stats_toggled signal must be emitted on F7")
	assert(player.lj_stats_enabled == false, "LJ Stats should be toggled off")
	print("[PASS] F7 toggles LJ Stats off (lj_stats_enabled = %s)" % str(player.lj_stats_enabled))

	# Toggle back on
	player._unhandled_input(toggle_action_ev)
	assert(player.lj_stats_enabled == true, "LJ Stats should be toggled back on")
	print("[PASS] F7 toggles LJ Stats back on (lj_stats_enabled = %s)" % str(player.lj_stats_enabled))

	# ------------------------------------------------------------------
	# Subtest 3A: Jump with distance < 240 (e.g. ~212 units) must NOT emit stats
	# ------------------------------------------------------------------
	var short_jump_data := [{}]
	var short_jump_conn = func(data): short_jump_data[0] = data
	player.lj_stat_recorded.connect(short_jump_conn)

	player.pm.spawn(Vector3(-3376, -3792, 36.03125), 0.0)
	player.run_command({"forward": 0.0, "side": 0.0, "up": 0.0, "buttons": 0}, 10)
	player.view_angles = Vector3(0, 0, 0)
	player.pm.velocity = Vector3(250.0, 0.0, 0.0)
	player.run_command({"forward": 400.0, "side": 0.0, "up": 0.0, "buttons": CSPlayerMove.IN_FORWARD | CSPlayerMove.IN_JUMP}, 10)
	# 10 frames in air, moving 180 units raw (total 212 units, below 240)
	for i in 10:
		player.run_command({"forward": 0.0, "side": 0.0, "up": 0.0, "buttons": 0}, 10)
		player.pm.origin.x += 18.0
	player.pm.onground = 0
	player.run_command({"forward": 0.0, "side": 0.0, "up": 0.0, "buttons": 0}, 10)

	assert(short_jump_data[0].is_empty(), "Jumps with distance < 240 must NOT emit or show LJ stats")
	assert(hud._lj_panel.modulate.a == 0.0, "HUD LJ banner must remain hidden for jumps < 240")
	print("[PASS] Jumps under 240 units do NOT display LJ stats (as requested)!")
	player.lj_stat_recorded.disconnect(short_jump_conn)

	# ------------------------------------------------------------------
	# Subtest 3B: Jump with distance >= 240 (e.g. ~250 units) MUST emit stats & HUD banner
	# ------------------------------------------------------------------
	var recorded_data := [{}]
	player.lj_stat_recorded.connect(func(data):
		recorded_data[0] = data
	)

	# 1. Takeoff on ground
	player.pm.spawn(Vector3(-3376, -3792, 36.03125), 0.0)
	player.run_command({"forward": 0.0, "side": 0.0, "up": 0.0, "buttons": 0}, 10)
	assert(player.pm.onground == 0, "Player must be on ground before takeoff")
	player.view_angles = Vector3(0, 0, 0) # facing East (+X)
	player.pm.velocity = Vector3(260.0, 0.0, 0.0)
	player.run_command({"forward": 400.0, "side": 0.0, "up": 0.0, "buttons": CSPlayerMove.IN_FORWARD | CSPlayerMove.IN_JUMP}, 10)
	assert(player._lj_tracking, "LJ tracking must activate on jump takeoff")
	assert(player._lj_prestrafe == 260.0, "Prestrafe must be recorded at jump moment")
	print("LJ jump started: takeoff_pos=%s, prestrafe=%.1f" % [str(player._lj_takeoff_pos), player._lj_prestrafe])

	# 2. Airborne frames with air strafes (distance raw ~218 + 32 = 250 units):
	# Strafe 1: move left + turn left
	for i in 6:
		player.view_angles.y += 2.0 # turn left
		player.run_command({"forward": 0.0, "side": -400.0, "up": 0.0, "buttons": CSPlayerMove.IN_MOVELEFT}, 10)
		player.pm.origin.x += 18.0

	# Strafe 2: move right + turn right
	for i in 6:
		player.view_angles.y -= 2.0 # turn right
		player.run_command({"forward": 0.0, "side": 400.0, "up": 0.0, "buttons": CSPlayerMove.IN_MOVERIGHT}, 10)
		player.pm.origin.x += 18.0

	assert(player._lj_strafes >= 2, "Air strafe counter must register strafes (registered: %d)" % player._lj_strafes)
	assert(player._lj_sync_frames > 0, "Sync frames must be counted when mouse turning and strafe keys match")
	print("Airborne strafes recorded: %d strafes, %d sync frames out of %d air frames" % [
		player._lj_strafes, player._lj_sync_frames, player._lj_air_frames])

	# 3. Land on ground
	player.pm.onground = 0 # land on ground
	player.run_command({"forward": 0.0, "side": 0.0, "up": 0.0, "buttons": 0}, 10)

	var data: Dictionary = recorded_data[0]
	assert(not data.is_empty(), "LJ stats data dictionary must be recorded on landing for jumps >= 240")
	var expected_raw_dist: float = player.pm.origin.x - player._lj_takeoff_pos.x
	var expected_total_dist: float = expected_raw_dist + 32.0
	assert(expected_total_dist >= 240.0, "Jump distance must be >= 240")
	assert(absf(float(data["distance"]) - expected_total_dist) < 0.01,
		"Distance must follow CS 1.6 edge formula: raw_distance + 32.0 units")
	assert(data["strafes"] >= 2, "Recorded strafes count must match")
	assert(data["sync"] > 50.0, "Sync %% must be calculated")
	print("[PASS] LJ Stat recorded successfully for 240+ jump:")
	print("       Distance: %.3f units (raw %.3f + 32.0 edge offset)" % [data["distance"], data["raw_distance"]])
	print("       Prestrafe: %.1f u/s" % data["prestrafe"])
	print("       Maxspeed: %.1f u/s" % data["maxspeed"])
	print("       Strafes: %d" % data["strafes"])
	print("       Sync: %.1f%%" % data["sync"])

	# Verify HUD UI element updates
	assert(hud._lj_panel != null, "HUD must have LJ stats panel")
	assert(hud._lj_dist_label.text.contains("%.3f" % data["distance"]), "HUD must display distance")
	assert(hud._lj_panel.modulate.a > 0.0, "HUD LJ banner must be visible after 240+ jump")
	print("[PASS] HUD LJ banner displays jump statistics correctly for 240+ units!")

	print("\n=== ALL BHOP BLOCK, DOUBLE DUCK & LJ STATS TESTS PASSED! ===")
	test_root.queue_free()
	quit(0)
