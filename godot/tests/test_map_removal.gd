extends SceneTree

const SettingsManagerScript = preload("res://scripts/utils/settings_manager.gd")
const REMOVED := ["bhop_flyblocks", "bhop_perfect2012", "bhop_without_colors", "kz_bhop", "kzsk_xmas2010", "kzy_fastbhop", "kzy_junglerocks"]
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func save_map(name: String, bsp: String, glb: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("map", "current_map", name)
	cfg.set_value("map", "current_map_bsp", bsp)
	cfg.set_value("map", "current_map_glb", glb)
	check(cfg.save(SettingsManagerScript.CONFIG_PATH) == OK, "Synthetic config must save")

func _initialize() -> void:
	if not preload("res://tests/settings_snapshot.gd").protect(self):
		return
	var sm = root.get_node_or_null("SettingsManager")
	if sm == null:
		sm = SettingsManagerScript.new()
		sm.name = "SettingsManager"
		root.add_child(sm)

	var maps: Array[Dictionary] = sm.get_available_maps()
	check(maps.size() == 15, "Catalog must contain exactly 15 maps, got %d" % maps.size())
	var ids := {}
	for map in maps:
		ids[map["id"]] = true
		check(FileAccess.file_exists(map["bsp"]), "Missing BSP: " + map["bsp"])
		check(ResourceLoader.exists(map["glb"]), "Missing GLB: " + map["glb"])
	check(ids.size() == 15, "Catalog must have 15 distinct IDs")
	for id in REMOVED:
		check(not ids.has(id), "Removed map in catalog: " + id)

	save_map("kz_bhop", "res://maps/kz_bhop.bsp", "res://maps/kz_bhop.glb")
	sm.load_settings()
	check(sm.current_map_name == "35hp_3", "Missing map name must fall back to 35hp_3")
	check(sm.current_map_bsp == "res://maps/35hp_3.bsp", "Missing BSP must fall back")
	check(sm.current_map_glb == "res://maps/35hp_3.glb", "Missing GLB must fall back")

	save_map("bhop_dea", "res://maps/bhop_dea.bsp", "res://maps/bhop_dea.glb")
	sm.load_settings()
	check(sm.current_map_name == "bhop_dea", "Valid map name must survive")
	check(sm.current_map_bsp == "res://maps/bhop_dea.bsp", "Valid BSP must survive")
	check(sm.current_map_glb == "res://maps/bhop_dea.glb", "Valid GLB must survive")

	save_map("bhop_dea", "res://maps/bhop_dea.bsp", "res://maps/missing.glb")
	sm.load_settings()
	check(sm.current_map_name == "35hp_3" and sm.current_map_bsp == "res://maps/35hp_3.bsp" and sm.current_map_glb == "res://maps/35hp_3.glb", "Missing GLB must fall back")
	print("MAP REMOVAL TEST: %s (%d failures; %d maps)" % ["PASS" if failures == 0 else "FAIL", failures, maps.size()])
	quit(0 if failures == 0 else 1)
