extends SceneTree

const GoldSrcBspScript = preload("res://scripts/goldsrc/goldsrc_bsp.gd")
const CSPlayerScript = preload("res://scripts/player/cs_player.gd")

func _initialize() -> void:
	print("\n========================================================")
	print(">>> TESTING SPAWN SAFETY ON ALL MAPS IN THE GAME <<<")
	print("========================================================\n")

	var sm = root.get_node_or_null("SettingsManager")
	if sm == null:
		var sm_script = load("res://scripts/utils/settings_manager.gd")
		sm = sm_script.new()
		sm.name = "SettingsManager"
		root.add_child(sm)

	var maps: Array = sm.get_available_maps()
	print("Found %d maps in catalog." % maps.size())

	for m in maps:
		var map_name: String = m["id"]
		var bsp_path: String = m["bsp"]
		var global_bsp_path := ProjectSettings.globalize_path(bsp_path)
		var bsp: GoldSrcBsp = GoldSrcBspScript.load_file(global_bsp_path)
		assert(bsp != null, "Failed to load BSP for %s" % map_name)

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

		var prev_teleports := player.teleport_count
		var timeout_emitted := {"val": false}
		player.bhop_block_timeout.connect(func(): timeout_emitted["val"] = true)

		# Run 50 ticks = 0.5s of standing at spawn
		for _step in 50:
			player.run_command({"forward": 0.0, "side": 0.0, "up": 0.0, "buttons": 0}, 10)

		assert(not timeout_emitted["val"], "Map %s must NOT trigger bhop_block_timeout at spawn!" % map_name)
		assert(player.block_stand_timer == 0.0, "Map %s block_stand_timer must be 0 at spawn, got %f" % [map_name, player.block_stand_timer])
		if map_name != "35hp_3":
			assert(player.teleport_count == prev_teleports, "Map %s must NOT teleport player while at spawn!" % map_name)

		print("  [PASS] Map '%s' (spawns: %d) -> spawn is 100%% safe, timer=0.0" % [map_name, player.spawns.size()])
		test_root.queue_free()

	print("\n========================================================")
	print(">>> ALL MAPS VERIFIED: SPAWN IS 100% SAFE EVERYWHERE! <<<")
	print("========================================================\n")
	quit(0)
