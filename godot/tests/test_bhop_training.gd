extends SceneTree

const GoldSrcBspScript = preload("res://scripts/goldsrc/goldsrc_bsp.gd")
const CSPlayerScript = preload("res://scripts/player/cs_player.gd")
const CSHudScript = preload("res://scripts/ui/hud.gd")

func _initialize() -> void:
	print("\n=== Running bhop_training_final Integration & Timer Tests ===")

	var sm = root.get_node_or_null("SettingsManager")
	if sm == null:
		var sm_script = load("res://scripts/utils/settings_manager.gd")
		sm = sm_script.new()
		sm.name = "SettingsManager"
		root.add_child(sm)

	# -------------------------------------------------------------
	# Test 1: Available Maps Catalog contains bhop_training_final
	# -------------------------------------------------------------
	print("\n--- Test 1: SettingsManager Map Catalog ---")
	var maps: Array[Dictionary] = sm.get_available_maps()
	var found_map: Dictionary = {}
	for m in maps:
		print(" - Map: %s | BSP: %s | GLB: %s" % [m.get("name"), m.get("bsp"), m.get("glb")])
		if m.get("name") == "bhop_training_final":
			found_map = m

	assert(not found_map.is_empty(), "bhop_training_final must be in available maps")
	assert(found_map.get("bsp") == "res://maps/bhop_training_final.bsp", "bsp path mismatch")
	assert(found_map.get("glb") == "res://maps/bhop_training_final.glb", "glb path mismatch")
	assert("bhop_training_final" in found_map.get("desc", ""), "Description must contain map name")
	assert("GoldSrc" in found_map.get("details", ""), "Details must contain specs")
	print("[PASS] bhop_training_final registered in map catalog with GLB and BSP!")

	# -------------------------------------------------------------
	# Test 2: GLB Visual Mesh Instantiation & Integrity
	# -------------------------------------------------------------
	print("\n--- Test 2: GLB Visual Mesh Verification ---")
	assert(ResourceLoader.exists("res://maps/bhop_training_final.glb"), "GLB file must exist")
	var glb_packed = load("res://maps/bhop_training_final.glb") as PackedScene
	assert(glb_packed != null, "GLB PackedScene must load")
	var glb_inst = glb_packed.instantiate()
	assert(glb_inst != null, "GLB scene must instantiate")
	var mesh_instances: Array[MeshInstance3D] = []
	for child in glb_inst.get_children():
		if child is MeshInstance3D:
			mesh_instances.append(child)
	print("Found %d MeshInstance3D nodes in GLB scene" % mesh_instances.size())
	assert(mesh_instances.size() >= 1, "Must contain at least 1 mesh node")
	glb_inst.queue_free()
	print("[PASS] GLB visual mesh loads and instantiates cleanly!")

	# -------------------------------------------------------------
	# Test 3: BSP Collision & Entity Loading
	# -------------------------------------------------------------
	print("\n--- Test 3: BSP Loading & Button Detection ---")
	var bsp_path := "res://maps/bhop_training_final.bsp"
	var bsp: GoldSrcBsp = GoldSrcBspScript.load_file(ProjectSettings.globalize_path(bsp_path))
	assert(bsp != null, "bhop_training_final.bsp must load")
	print("Loaded BSP: %d entities, %d physents, %d models" % [bsp.entities.size(), bsp.physents.size(), bsp.model_mins.size()])

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

	print("Found %d buttons in bhop_training_final" % player.kz_buttons.size())
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
	assert(start_btn["model"] == "*48", "Start button must be model *48")
	assert(stop_btn["model"] == "*121", "Stop button must be model *121")
	print("[PASS] Start button (*48, center %s) and Stop button (*121, center %s) detected successfully" % [
		str(start_btn["center"]), str(stop_btn["center"])])

	# -------------------------------------------------------------
	# Test 4: Starting Timer on Start Button with 'E'
	# -------------------------------------------------------------
	print("\n--- Test 4: Starting Timer on Start Button with 'E' ---")
	# Start button is at mins=(0, -1696, -480), maxs=(8, -1664, -448)
	# Place player in front of start button: eye around (45, -1680, -450), facing -X (yaw = 180)
	player.pm.origin = Vector3(45.0, -1680.0, -464.0)
	player.view_angles = Vector3(0.0, 180.0, 0.0)

	var aimed := player.get_aimed_button()
	assert(not aimed.is_empty(), "Player facing start button must detect it")
	assert(aimed["type"] == "start", "Aimed button must be type 'start'")
	print("[PASS] Aimed at start button: model=%s" % aimed["model"])

	var timer_started := [false]
	player.kz_timer_started.connect(func(): timer_started[0] = true)

	var used := player._try_use_button()
	assert(used == true, "_try_use_button must return true on aimed start button")
	assert(timer_started[0] == true, "kz_timer_started signal must fire")
	assert(player.kz_timer_active == true, "kz_timer_active must be true")
	print("[PASS] Kreedz timer started successfully on bhop_training_final!")

	# Simulate time elapsed
	player.kz_timer_elapsed = 42.75

	# -------------------------------------------------------------
	# Test 5: Stopping Timer on Finish Button with 'E'
	# -------------------------------------------------------------
	print("\n--- Test 5: Stopping Timer on Finish Button with 'E' ---")
	# Stop button is at mins=(-3152, 1520, -480), maxs=(-3120, 1536, -448)
	# Center is (-3136, 1528, -464).
	# Place player in front of stop button facing -Y (yaw = -90 / 270) or +Y (yaw = 90)
	player.pm.origin = Vector3(-3136.0, 1490.0, -464.0)
	player.view_angles = Vector3(0.0, 90.0, 0.0) # looking towards +Y (1520..1536)

	aimed = player.get_aimed_button()
	assert(not aimed.is_empty(), "Player facing stop button must detect it")
	assert(aimed["type"] == "stop", "Aimed button must be type 'stop'")
	print("[PASS] Aimed at stop button: model=%s" % aimed["model"])

	var stop_result: Dictionary = {}
	player.kz_timer_stopped.connect(func(final_time: float, is_best: bool):
		stop_result["time"] = final_time
		stop_result["best"] = is_best
	)

	player._last_button_use_msec = 0
	used = player._try_use_button()
	assert(used == true, "_try_use_button must return true on stop button")
	assert(player.kz_timer_active == false, "kz_timer_active must be false after stop")
	assert(stop_result.get("time") == 42.75, "Recorded time must match elapsed time")
	assert(stop_result.get("best") == true, "First completion must be new best time")
	print("[PASS] Kreedz timer stopped successfully! Time: %.2fs" % stop_result["time"])

	# Check SettingsManager persisted record
	var best_rec: float = sm.get_best_time("bhop_training_final")
	assert(best_rec == 42.75, "SettingsManager must store best time for bhop_training_final")
	print("[PASS] SettingsManager record confirmed: %.2fs" % best_rec)

	# -------------------------------------------------------------
	# Test 6: Bhop Blocks detection & Stand-Teleport logic
	# -------------------------------------------------------------
	print("\n--- Test 6: Bhop Door Blocks Verification ---")
	var func_doors := 0
	for pe in bsp.physents:
		if pe.classname == "func_door":
			func_doors += 1
	print("Found %d func_door bhop blocks in bhop_training_final" % func_doors)
	assert(func_doors >= 10, "Map must contain multiple func_door bhop blocks")
	print("[PASS] Bhop door blocks present in physents!")

	print("\n========================================================")
	print(">>> ALL BHOP TRAINING FINAL INTEGRATION TESTS PASSED! <<<")
	print("========================================================\n")

	test_root.queue_free()
	quit(0)
