extends SceneTree

const ARENA := Vector3(100, 900, -601)

func _initialize() -> void:
	print("--- Running Footstep Sounds Test ---")
	var sm = root.get_node_or_null("SettingsManager")
	if sm:
		sm.current_map_name = "35hp_3"
		sm.current_map_bsp = "res://maps/35hp_3.bsp"
		sm.current_map_glb = "res://maps/35hp_3.glb"
		sm.save_settings()

	var main_scene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)

	await process_frame
	await process_frame

	var player = main.get_node("Player")
	print("Loaded footstep sounds count: ", player.footstep_sounds.size())
	assert(player.footstep_sounds.size() == 2, "Should have loaded exactly 2 footstep sounds")

	# Test 1: Alternating playback between step1 and step2
	var played: Dictionary = {}
	for i in range(10):
		player._play_footstep_sound()
		var idx = player._last_footstep_sound_index
		played[idx] = played.get(idx, 0) + 1
		print("Footstep %2d: selected sound index %d" % [i + 1, idx])

	assert(played.has(0) and played.has(1), "Both footstep sounds should be played")
	assert(played[0] == 5 and played[1] == 5, "Footstep sounds should strictly alternate 0 and 1")
	print("[PASS] Test 1: Footsteps alternate correctly between both sounds")

	# Setup player on open arena floor
	player.pm.spawn(ARENA, 0.0)
	player.view_angles = Vector3(0, 0, 0)
	for i in 50:
		player.run_command({"forward": 0.0, "side": 0.0, "up": 0.0, "buttons": 0}, 10)

	print("Map loaded: ", sm.current_map_name if sm else "none", " pm.origin: ", player.pm.origin, " onground: ", player.pm.onground)
	assert(player.pm.onground != -1, "Player should be standing on ground")

	# Test 2: Normal running (speed 250) triggers footsteps
	player._footstep_dist = 0.0
	var steps_triggered := 0
	var run_cmd := {"forward": 400.0, "side": 0.0, "up": 0.0, "buttons": CSPlayerMove.IN_FORWARD}

	# Run for 100 ticks (1000ms = 1s = 250 units distance).
	# At 75 units per step, 250 units should trigger 3 footsteps.
	for tick in range(100):
		var prev_idx = player._last_footstep_sound_index
		player.run_command(run_cmd, 10)
		if player._last_footstep_sound_index != prev_idx:
			steps_triggered += 1
			print("Tick %d: footstep triggered! (step count: %d, sound index: %d)" % [tick, steps_triggered, player._last_footstep_sound_index])

	print("Running 1s: speed = %.1f, footsteps triggered = %d" % [player.pm.horizontal_speed(), steps_triggered])
	assert(steps_triggered >= 2, "Running at 250 u/s should trigger footsteps")
	print("[PASS] Test 2: Running triggers footsteps at proper intervals")

	# Test 3: Walking (Shift walk: speed 130 u/s <= 135) is completely silent
	player._footstep_dist = 0.0
	var walk_steps := 0
	var walk_cmd := {"forward": 250.0 * player.cl_movespeedkey, "side": 0.0, "up": 0.0, "buttons": CSPlayerMove.IN_FORWARD}

	for tick in range(100):
		var prev_idx = player._last_footstep_sound_index
		player.run_command(walk_cmd, 10)
		if player._last_footstep_sound_index != prev_idx:
			walk_steps += 1

	print("Walking 1s: speed = %.1f, footsteps triggered = %d" % [player.pm.horizontal_speed(), walk_steps])
	assert(walk_steps == 0, "Walking with Shift should be completely silent (got %d steps)" % walk_steps)
	print("[PASS] Test 3: Walking with Shift is silent")

	# Test 4: Ducking / crouch-walking is completely silent
	player._footstep_dist = 0.0
	var duck_steps := 0
	var duck_cmd := {"forward": 400.0, "side": 0.0, "up": 0.0, "buttons": CSPlayerMove.IN_FORWARD | CSPlayerMove.IN_DUCK}

	for tick in range(100):
		var prev_idx = player._last_footstep_sound_index
		player.run_command(duck_cmd, 10)
		if player._last_footstep_sound_index != prev_idx:
			duck_steps += 1

	print("Crouch-walking 1s: speed = %.1f, footsteps triggered = %d" % [player.pm.horizontal_speed(), duck_steps])
	assert(duck_steps == 0, "Crouch-walking should be completely silent (got %d steps)" % duck_steps)
	print("[PASS] Test 4: Crouch-walking is silent")

	print("\nALL FOOTSTEP SOUND TESTS PASSED SUCCESSFULLY!")
	quit(0)
