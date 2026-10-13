extends SceneTree

const ARENA := Vector3(100, 900, -601)

func _initialize() -> void:
	if not preload("res://tests/settings_snapshot.gd").protect(self):
		return
	print("--- Running Ladder Sounds Test (2 sounds) ---")
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
	print("Loaded ladder sounds count: ", player.ladder_sounds.size())
	assert(player.ladder_sounds.size() == 2, "Should have loaded exactly 2 ladder sounds")

	# Test 1: Alternating / random playback of the 2 sounds
	var played_indices: Dictionary = {}
	for i in range(10):
		player._play_ladder_sound()
		var idx = player._last_ladder_sound_index
		played_indices[idx] = played_indices.get(idx, 0) + 1
		print("Ladder step %2d: selected sound index %d" % [i + 1, idx])

	print("Ladder sounds played distribution: ", played_indices)
	assert(played_indices.has(0) and played_indices.has(1), "Should have played both ladder sounds")
	print("[PASS] Test 1: Ladder sound selection alternates between both sounds!")

	# Test 2: Real ladder climb on the map triggers ladder sounds
	var ladder: GoldSrcBsp.PhysEnt = null
	for pe in player.bsp.physents:
		if pe.skin == GoldSrcBsp.CONTENTS_LADDER:
			ladder = pe
			break

	assert(ladder != null, "Map should have func_ladder")
	var center := (ladder.mins + ladder.maxs) * 0.5
	var normal_dir := Vector3(-1, 0, 0) if center.x > 0 else Vector3(1, 0, 0)
	var start := Vector3(center.x + normal_dir.x * 40.0, center.y, ARENA.z)
	var yaw := 0.0 if normal_dir.x < 0 else 180.0

	player.pm.spawn(start, yaw)
	player.view_angles = Vector3(0, yaw, 0)
	for i in 50:
		player.run_command({"forward": 0.0, "side": 0.0, "up": 0.0, "buttons": 0}, 10)

	var sounds_triggered = 0
	var z0 = player.pm.origin.z
	player.view_angles = Vector3(-45, yaw, 0)
	var cmd = {"forward": 400.0, "side": 0.0, "up": 0.0, "buttons": CSPlayerMove.IN_FORWARD}

	for tick in range(300):
		var prev_idx = player._last_ladder_sound_index
		player.run_command(cmd, 10)
		if player._last_ladder_sound_index != prev_idx:
			sounds_triggered += 1
			print("Tick %d: ladder sound triggered! (step count: %d, sound index: %d)" % [tick, sounds_triggered, player._last_ladder_sound_index])

	var climbed_units: float = player.pm.origin.z - z0
	print("Climbed vertical units: %.1f, ladder sounds played: %d" % [climbed_units, sounds_triggered])
	assert(climbed_units > 100.0, "Player should have climbed up the ladder")
	assert(sounds_triggered >= 2, "Climbing ladder should have triggered multiple step sounds")
	print("[PASS] Test 2: Ladder climb in map correctly triggers step sounds!")

	print("\nALL LADDER SOUND TESTS PASSED SUCCESSFULLY!")
	quit(0)
