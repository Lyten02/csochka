extends SceneTree

const GoldSrcBspScript = preload("res://scripts/goldsrc/goldsrc_bsp.gd")
const CSPlayerScript = preload("res://scripts/player/cs_player.gd")
const CSHudScript = preload("res://scripts/ui/hud.gd")

func _initialize() -> void:
	if not preload("res://tests/settings_snapshot.gd").protect(self):
		return
	print("\n=== Running BKZ GoldBhop Kreedz Timer & Button Interaction Tests ===")

	var bsp_path := "res://maps/bkz_goldbhop.bsp"
	var bsp: GoldSrcBsp = GoldSrcBspScript.load_file(ProjectSettings.globalize_path(bsp_path))
	if bsp == null:
		push_error("FAILED to load bkz_goldbhop.bsp")
		quit(1)
		return

	# Setup root node, player, camera and HUD
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

	var hud: CSHud = CSHudScript.new()
	hud.name = "HUD"
	hud.player_path = NodePath("../Player")
	test_root.add_child(hud)

	await process_frame
	await process_frame

	# -------------------------------------------------------------
	# Test 1: Button Detection in bkz_goldbhop
	# -------------------------------------------------------------
	print("\n--- Test 1: Button Detection in bkz_goldbhop ---")
	print("Found %d buttons in map" % player.kz_buttons.size())
	assert(player.kz_buttons.size() >= 2, "Must find at least start and stop buttons")

	var start_btn: Dictionary = {}
	var stop_btn: Dictionary = {}
	for b in player.kz_buttons:
		if b["type"] == "start":
			start_btn = b
		elif b["type"] == "stop":
			stop_btn = b

	assert(not start_btn.is_empty(), "Start button must be detected")
	assert(not stop_btn.is_empty(), "Stop button must be detected")
	assert(start_btn["model"] == "*95", "Start button must be model *95")
	assert(stop_btn["model"] == "*97", "Stop button must be model *97")
	print("[PASS] Start button (*95, center %s) and Stop button (*97, center %s) detected successfully" % [
		str(start_btn["center"]), str(stop_btn["center"])])

	# -------------------------------------------------------------
	# Test 2: Aimed Button Ray / Proximity Detection
	# -------------------------------------------------------------
	print("\n--- Test 2: Aimed Button Ray / Proximity Detection ---")
	# Place player in front of start button facing west (-X, yaw = 180)
	# Start button is at mins=(-3568, -3416, 0), maxs=(-3536, -3384, 64)
	player.pm.origin = Vector3(-3500.0, -3400.0, 32.0)
	player.view_angles = Vector3(0.0, 180.0, 0.0) # facing -X towards -3536..-3568

	var aimed := player.get_aimed_button()
	assert(not aimed.is_empty(), "Player facing start button at dist 36u must detect it")
	assert(aimed["type"] == "start", "Aimed button must be type 'start'")
	print("[PASS] Looking at start button: detected successfully (%s)" % aimed["model"])

	# Turn away (yaw = 0.0 facing east)
	player.view_angles = Vector3(0.0, 0.0, 0.0)
	assert(player.get_aimed_button().is_empty(), "Looking away from button must not detect it")
	print("[PASS] Looking away: not detected")

	# Move far away
	player.pm.origin = Vector3(-2000.0, -2000.0, 0.0)
	player.view_angles = Vector3(0.0, 180.0, 0.0)
	assert(player.get_aimed_button().is_empty(), "Too far away must not detect button")
	print("[PASS] Far away: not detected")

	# -------------------------------------------------------------
	# Test 3: Starting the Timer with 'E' on Start Button
	# -------------------------------------------------------------
	print("\n--- Test 3: Starting the Timer with 'E' on Start Button ---")
	player.pm.origin = Vector3(-3500.0, -3400.0, 32.0)
	player.view_angles = Vector3(0.0, 180.0, 0.0)

	var timer_started := [false]
	player.kz_timer_started.connect(func(): timer_started[0] = true)

	assert(player.kz_timer_active == false, "Timer must be inactive initially")
	var used := player._try_use_button()
	assert(used == true, "_try_use_button must return true on aimed button")
	assert(timer_started[0] == true, "kz_timer_started signal must fire")
	assert(player.kz_timer_active == true, "kz_timer_active must be true")
	assert(player.kz_timer_elapsed == 0.0, "kz_timer_elapsed must start at 0.0")
	print("[PASS] Timer successfully started at 00:00.00!")

	# Advance physics by 100 ticks (1.00s at 10ms/tick)
	for t in 100:
		player.run_command({"forward": 0.0, "side": 0.0, "up": 0.0, "buttons": 0}, 10)

	assert(is_equal_approx(player.kz_timer_elapsed, 1.0), "Timer must advance exactly 1.00s after 100 ticks of 10ms")
	print("[PASS] Timer elapsed after 100 ticks: %.2fs" % player.kz_timer_elapsed)

	# -------------------------------------------------------------
	# Test 4: Stopping the Timer with 'E' on Stop Button (Finish Run)
	# -------------------------------------------------------------
	print("\n--- Test 4: Stopping the Timer with 'E' on Stop Button ---")
	# Advance another 150 ticks (1.50s -> total 2.50s)
	for t in 150:
		player.run_command({"forward": 0.0, "side": 0.0, "up": 0.0, "buttons": 0}, 10)

	assert(is_equal_approx(player.kz_timer_elapsed, 2.5), "Timer must be 2.50s")

	# Move player in front of stop button
	# Stop button is at mins=(-112, -976, 336), maxs=(-80, -944, 400), center=(-96, -960, 368)
	player.pm.origin = Vector3(-60.0, -960.0, 368.0)
	player.view_angles = Vector3(0.0, 180.0, 0.0) # facing -X towards -80..-112

	var stop_aimed := player.get_aimed_button()
	assert(not stop_aimed.is_empty(), "Must detect stop button")
	assert(stop_aimed["type"] == "stop", "Must be type 'stop'")

	var stopped_data := {"fired": false, "time": 0.0, "is_record": false}
	player.kz_timer_stopped.connect(func(final_time: float, is_rec: bool):
		stopped_data["fired"] = true
		stopped_data["time"] = final_time
		stopped_data["is_record"] = is_rec
	)

	# Debounce bypass by setting last msec back
	player._last_button_use_msec = 0
	var stop_used := player._try_use_button()
	assert(stop_used == true, "_try_use_button must succeed on stop button")
	assert(stopped_data["fired"] == true, "kz_timer_stopped must fire")
	assert(is_equal_approx(stopped_data["time"], 2.5), "Final time must be 2.50s")
	assert(stopped_data["is_record"] == true, "First completion must be a record")
	assert(player.kz_timer_active == false, "kz_timer_active must now be false")
	assert(is_equal_approx(player.kz_best_time, 2.5), "player.kz_best_time must be updated to 2.50s")
	print("[PASS] Finished run: final time = %.2fs, new record = %s" % [stopped_data["time"], stopped_data["is_record"]])

	# -------------------------------------------------------------
	# Test 5: Invalid Stop (Pressing Stop without Starting)
	# -------------------------------------------------------------
	print("\n--- Test 5: Invalid Stop without Starting ---")
	var invalid_stop_fired := [false]
	player.kz_timer_invalid_stop.connect(func(): invalid_stop_fired[0] = true)

	player._last_button_use_msec = 0
	player._try_use_button()
	assert(invalid_stop_fired[0] == true, "kz_timer_invalid_stop must fire if timer is not active")
	print("[PASS] Pressing stop button while inactive correctly emitted kz_timer_invalid_stop")

	# -------------------------------------------------------------
	# Test 6: Second Run with Personal Record Comparison
	# -------------------------------------------------------------
	print("\n--- Test 6: Second Run with Personal Record Comparison ---")
	# Move back to start button and start again
	player.pm.origin = Vector3(-3500.0, -3400.0, 32.0)
	player.view_angles = Vector3(0.0, 180.0, 0.0)
	player._last_button_use_msec = 0
	player._try_use_button()
	assert(player.kz_timer_active == true, "Timer restarted")

	# Slower run: 350 ticks = 3.50s (slower than 2.50s record)
	for t in 350:
		player.run_command({"forward": 0.0, "side": 0.0, "up": 0.0, "buttons": 0}, 10)

	player.pm.origin = Vector3(-60.0, -960.0, 368.0)
	player.view_angles = Vector3(0.0, 180.0, 0.0)
	player._last_button_use_msec = 0
	stopped_data["fired"] = false
	player._try_use_button()

	assert(stopped_data["fired"] == true)
	assert(stopped_data["is_record"] == false, "3.50s run must NOT be a new record when best is 2.50s")
	assert(is_equal_approx(player.kz_best_time, 2.5), "Best time must remain 2.50s")
	print("[PASS] Slower run (3.50s) correctly recognized as non-record (best remains 2.50s)")

	# Faster run: 180 ticks = 1.80s (faster than 2.50s record)
	player.pm.origin = Vector3(-3500.0, -3400.0, 32.0)
	player.view_angles = Vector3(0.0, 180.0, 0.0)
	player._last_button_use_msec = 0
	player._try_use_button()

	for t in 180:
		player.run_command({"forward": 0.0, "side": 0.0, "up": 0.0, "buttons": 0}, 10)

	player.pm.origin = Vector3(-60.0, -960.0, 368.0)
	player.view_angles = Vector3(0.0, 180.0, 0.0)
	player._last_button_use_msec = 0
	stopped_data["fired"] = false
	player._try_use_button()

	assert(stopped_data["fired"] == true)
	assert(stopped_data["is_record"] == true, "1.80s run MUST be a new record (beat 2.50s)")
	assert(is_equal_approx(player.kz_best_time, 1.8), "Best time must be updated to 1.80s")
	print("[PASS] Faster run (1.80s) successfully recorded as new record!")

	# -------------------------------------------------------------
	# Test 7: Timer Reset on Respawn
	# -------------------------------------------------------------
	print("\n--- Test 7: Timer Reset on Respawn ---")
	player.pm.origin = Vector3(-3500.0, -3400.0, 32.0)
	player.view_angles = Vector3(0.0, 180.0, 0.0)
	player._last_button_use_msec = 0
	player._try_use_button()
	assert(player.kz_timer_active == true)

	var reset_fired := [false]
	player.kz_timer_reset.connect(func(): reset_fired[0] = true)

	player.respawn(0)
	assert(player.kz_timer_active == false, "Respawn must stop active timer")
	assert(player.kz_timer_elapsed == 0.0, "Respawn must reset elapsed time")
	assert(reset_fired[0] == true, "kz_timer_reset must fire on respawn")
	print("[PASS] Respawn correctly resets and cancels timer")

	# -------------------------------------------------------------
	# Test 8: HUD Display Formatting
	# -------------------------------------------------------------
	print("\n--- Test 8: HUD Display Formatting ---")
	assert(CSHud.format_kz_time(0.0) == "00:00.00")
	assert(CSHud.format_kz_time(5.12) == "00:05.12")
	assert(CSHud.format_kz_time(65.48) == "01:05.48")
	assert(CSHud.format_kz_time(125.09) == "02:05.09")
	print("[PASS] All time formatting tests passed!")

	print("\n========================================================")
	print(">>> ALL BKZ GOLDBHOP TIMER TESTS PASSED SUCCESSFULLY! <<<")
	print("========================================================\n")
	quit(0)
