extends SceneTree

const GoldSrcBspScript = preload("res://scripts/goldsrc/goldsrc_bsp.gd")
const CSPlayerScript = preload("res://scripts/player/cs_player.gd")

func _initialize() -> void:
	print("\n========================================================")
	print(">>> TESTING ALL DESTINATIONS ON ALL 22 MAPS <<<")
	print("========================================================\n")

	var sm_script = load("res://scripts/utils/settings_manager.gd")
	var sm = sm_script.new()
	var maps: Array = sm.get_available_maps()

	for m in maps:
		var map_name: String = m["id"]
		var bsp_path: String = m["bsp"]
		var global_bsp_path := ProjectSettings.globalize_path(bsp_path)
		var bsp: GoldSrcBsp = GoldSrcBspScript.load_file(global_bsp_path)
		if bsp == null:
			print("Could not load BSP: ", map_name)
			continue

		var test_root := Node3D.new()
		var player: CSPlayer = CSPlayerScript.new()
		var cam := Camera3D.new()
		player.add_child(cam)
		test_root.add_child(player)
		root.add_child(test_root)

		player.setup(bsp)
		player.set_physics_process(false)

		var failed_dests: Array[String] = []
		for dest_name in player._teleport_dest.keys():
			var dest = player._teleport_dest[dest_name]
			# Only check info_teleport_destination and info_target
			var cls: String = dest.get("classname", "")
			if cls != "info_teleport_destination" and cls != "info_target":
				continue
			player._teleport_to(dest)
			var tele_before := player.teleport_count
			for _step in 10:
				player.run_command({"forward": 0.0, "side": 0.0, "up": 0.0, "buttons": 0}, 10)
			if player.teleport_count > tele_before:
				failed_dests.append("%s (origin=%s)" % [dest_name, dest.get("origin")])

		if not failed_dests.is_empty():
			print("[BUG] Map '%s' HAS %d BROKEN DESTINATIONS: %s" % [
				map_name, failed_dests.size(), ", ".join(failed_dests)
			])
		else:
			print("[OK]  Map '%s' all destinations safe." % map_name)

		test_root.queue_free()

	quit(0)
