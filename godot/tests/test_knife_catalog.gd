extends SceneTree

const Settings = preload("res://scripts/utils/settings_manager.gd")
const Knife = preload("res://scripts/weapons/cs_knife.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	if not preload("res://tests/settings_snapshot.gd").protect(self):
		return
	call_deferred("run")

func run() -> void:
	var sm := Settings.new()
	var entries := sm.get_available_knives()
	check(entries.size() == 22, "Expected 22 selectable knives")
	var manifest: Array = JSON.parse_string(FileAccess.get_file_as_string("res://../models_src/knives/manifest.json"))
	var sources := {}
	for source in manifest:
		sources[source["slug"]] = source
	var count := 0
	var knife := Knife.new()
	root.add_child(knife)
	knife.set_process(false)
	for entry in entries:
		if entry["id"].begins_with("cs16forge_"):
			var player_text: String = entry["desc"] + "\n" + entry["details"]
			check(not entry["source_slug"] in player_text and not "GoldSrc" in player_text, "Player details exclude technical provenance")
			check("cs16forge.com" in player_text, "Player details retain source credit")
			check(("F" if entry["inspect_anim"] != null else "Без осмотра") in player_text, "Player details retain inspect availability")
		check(ResourceLoader.exists(entry["icon"]), "Icon exists: " + entry["id"])
		knife.set_knife_model(entry["model"], entry)
		var anim: AnimationPlayer = knife._anim
		check(anim != null, "AnimationPlayer loads: " + entry["id"])
		if not anim:
			continue
		for mesh in knife.find_children("", "MeshInstance3D", true, false):
			for surface in range(mesh.mesh.get_surface_count()):
				var material: BaseMaterial3D = mesh.get_surface_override_material(surface)
				if material and material.resource_name.ends_with("__goldsrc_additive"):
					check(material.blend_mode == BaseMaterial3D.BLEND_MODE_ADD, "Chrome overlay remains additive")
		if entry["id"].begins_with("cs16forge_"):
			for dependency in ResourceLoader.get_dependencies(entry["model"]):
				check(not ".png" in dependency, "GLB textures stay embedded, without duplicate PNG dependencies")
		anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for role in ["idle", "draw", "slash1", "slash2", "midslash1", "midslash2", "stab", "stab_miss"]:
			check(anim.has_animation(knife.animation_for_role(role)), entry["id"] + " role " + role)
		if entry.get("inspect_anim") != null:
			count += 1
			var name: String = entry["inspect_anim"]
			check(anim.has_animation(name), "Inspect exists: " + entry["id"])
			if not anim.has_animation(name):
				continue
			var source: Dictionary = sources[entry["source_slug"]]["inspect"]
			var clip := anim.get_animation(name)
			var expected: float = (float(source["frames"]) - 1.0) / float(source["fps"])
			check(absf(clip.length - expected) < 0.001, "Inspect duration: " + entry["id"])
			check(clip.get_track_count() > 0, "Inspect has real animation tracks")
			anim.advance(30.0)
			knife.inspect()
			check(knife._is_inspecting, "Inspect starts: " + entry["id"])
			anim.advance(expected + 0.1)
			check(not knife._is_inspecting and anim.current_animation == knife.animation_for_role("idle"), "Inspect returns to idle: " + entry["id"])
			print("[PASS] %s inspect=%s duration=%.5f expected=%.5f" % [entry["id"], name, clip.length, expected])
		else:
			for name in anim.get_animation_list():
				check(not "inspect" in name.to_lower(), "Unsupported knife has no inspect clip: " + entry["id"])
			if entry["id"].begins_with("cs16forge_"):
				check(sources[entry["source_slug"]]["sequences"].size() == 8, "Unsupported source has exactly eight sequences")
			print("[PASS] %s no inspect" % entry["id"])
		await process_frame
	check(count == 10, "Exactly ten inspect knives")
	knife.free()
	sm.free()
	await process_frame
	print("KNIFE CATALOG: %s (22 selectable, %d inspect, %d failures)" % ["PASS" if failures == 0 else "FAIL", count, failures])
	quit(0 if failures == 0 else 1)
