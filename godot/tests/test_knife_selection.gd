extends SceneTree

const SettingsManagerScript = preload("res://scripts/utils/settings_manager.gd")
const CSKnifeScript = preload("res://scripts/weapons/cs_knife.gd")
const CSKnifeSelectDialogScript = preload("res://scripts/ui/knife_select_dialog.gd")
const CSPlayerScript = preload("res://scripts/player/cs_player.gd")
const GoldSrcBspScript = preload("res://scripts/goldsrc/goldsrc_bsp.gd")

func _initialize() -> void:
	print("\n=== Running CS 1.6 Knife Selection & Model Integration Tests ===")

	var sm = root.get_node_or_null("SettingsManager")
	if sm == null:
		sm = SettingsManagerScript.new()
		sm.name = "SettingsManager"
		root.add_child(sm)

	# -------------------------------------------------------------
	# Test 1: SettingsManager Knife Catalog
	# -------------------------------------------------------------
	print("\n--- Test 1: SettingsManager Knife Catalog ---")
	var knives: Array = sm.get_available_knives()
	print("Available knives count: %d" % knives.size())
	assert(knives.size() >= 2, "There must be at least 2 knives available (default + black)")

	var found_default := false
	var found_black := false
	for k in knives:
		print(" - Knife ID: %s | Name: %s | Model: %s" % [k["id"], k["name"], k["model"]])
		assert(k.has("id") and k["id"] != "", "Knife must have a non-empty id")
		assert(k.has("name") and k["name"] != "", "Knife must have a non-empty name")
		assert(k.has("model") and k["model"] != "", "Knife must have a non-empty model path")
		assert(k.has("desc"), "Knife must have a desc field")
		assert(k.has("details"), "Knife must have a details field")
		if k["id"] == "knife_default":
			found_default = true
		if k["id"] == "knife_black":
			found_black = true

	assert(found_default, "knife_default must exist in catalog")
	assert(found_black, "knife_black must exist in catalog")
	print("[PASS] Knife catalog contains both default and black night knife definitions.")

	# -------------------------------------------------------------
	# Test 2: Models & Icons Exist and Load
	# -------------------------------------------------------------
	print("\n--- Test 2: Model & Icon Resource Verification ---")
	assert(ResourceLoader.exists("res://models/knife.glb"), "knife.glb must exist")
	assert(ResourceLoader.exists("res://models/knife_black.glb"), "knife_black.glb must exist")
	assert(ResourceLoader.exists("res://models/knife_default_thumb.png"), "knife_default_thumb.png must exist")
	assert(ResourceLoader.exists("res://models/knife_black_thumb.png"), "knife_black_thumb.png must exist")

	var scn_default = load("res://models/knife.glb") as PackedScene
	var scn_black = load("res://models/knife_black.glb") as PackedScene
	assert(scn_default != null, "knife.glb must load as PackedScene")
	assert(scn_black != null, "knife_black.glb must load as PackedScene")
	print("[PASS] Both knife GLB models and preview thumbnails load properly.")

	# -------------------------------------------------------------
	# Test 3: CSKnife Node & Hot Swapping
	# -------------------------------------------------------------
	print("\n--- Test 3: CSKnife Hot-swapping and Animations ---")
	var knife_node = CSKnifeScript.new()
	root.add_child(knife_node)

	# Initially load default knife
	knife_node.set_knife_model("res://models/knife.glb")
	var anim: AnimationPlayer = knife_node.find_child("AnimationPlayer", true, false)
	assert(anim != null, "AnimationPlayer must exist in default knife")
	assert(anim.has_animation("draw"), "Knife must have draw animation")
	assert(anim.has_animation("slash1"), "Knife must have slash1 animation")
	assert(anim.has_animation("stab"), "Knife must have stab animation")

	# Swap to black knife
	knife_node.set_knife_model("res://models/knife_black.glb")
	anim = knife_node.find_child("AnimationPlayer", true, false)
	assert(anim != null, "AnimationPlayer must exist after swapping to black knife")
	assert(anim.has_animation("draw"), "Black knife must have draw animation")
	assert(anim.has_animation("idle"), "Black knife must have idle animation")
	assert(anim.has_animation("slash1"), "Black knife must have slash1 animation")
	assert(anim.has_animation("stab"), "Black knife must have stab animation")

	var hit_data := {"fired": false, "is_stab": false}
	knife_node.attack_hit.connect(func(is_sec):
		hit_data["fired"] = true
		hit_data["is_stab"] = is_sec
	)

	knife_node.attack()
	assert(hit_data["fired"] and not hit_data["is_stab"], "attack() should fire attack_hit(false)")

	# Simulate slash animation finishing so knife can attack again
	knife_node._on_animation_finished("slash1")
	hit_data["fired"] = false

	knife_node.attack2()
	assert(hit_data["fired"] and hit_data["is_stab"], "attack2() should fire attack_hit(true)")

	print("[PASS] CSKnife model hot-swapping and animation playback verified.")

	# -------------------------------------------------------------
	# Test 4: CSKnifeSelectDialog UI Functionality
	# -------------------------------------------------------------
	print("\n--- Test 4: CSKnifeSelectDialog UI ---")
	var dialog = CSKnifeSelectDialogScript.new()
	root.add_child(dialog)
	dialog.visible = true

	await process_frame
	await process_frame

	var selected_data := {"info": {}}
	dialog.knife_selected.connect(func(info):
		selected_data["info"] = info
	)

	# Select the second item (knife_black)
	dialog._on_knife_item_selected(1)
	dialog._on_select_pressed()

	assert(not selected_data["info"].is_empty(), "knife_selected signal should be emitted on selection")
	assert(selected_data["info"].get("id") == "knife_black", "Selected knife should be knife_black")
	assert(sm.current_knife_id == "knife_black", "SettingsManager should record knife_black as active")
	assert(sm.get_current_knife_model() == "res://models/knife_black.glb", "Active model path should be knife_black.glb")
	print("[PASS] CSKnifeSelectDialog successfully equips knife_black and updates settings.")

	# -------------------------------------------------------------
	# Test 5: CSPlayer Integration & Auto-Updating Knife
	# -------------------------------------------------------------
	print("\n--- Test 5: CSPlayer Knife Auto-Instantiation and Hot-Reload ---")
	var bsp_path := "res://maps/35hp_3.bsp"
	var bsp = GoldSrcBspScript.load_file(ProjectSettings.globalize_path(bsp_path))
	assert(bsp != null, "35hp_3.bsp should load")

	var player = CSPlayerScript.new()
	player.name = "Player"
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	player.add_child(cam)
	root.add_child(player)

	await process_frame
	await process_frame

	player.setup(bsp)
	player.set_physics_process(false)

	assert(player.knife != null, "Player knife must be automatically instantiated under Camera3D")
	var current_player_anim: AnimationPlayer = player.knife.find_child("AnimationPlayer", true, false)
	assert(current_player_anim != null, "Player knife must have active AnimationPlayer")

	# Test switching back to default knife via SettingsManager
	sm.set_current_knife("knife_default")
	assert(sm.current_knife_id == "knife_default")
	assert(player.knife != null)
	current_player_anim = player.knife.find_child("AnimationPlayer", true, false)
	assert(current_player_anim != null, "Player knife animation player must remain active after setting change")

	print("[PASS] CSPlayer properly manages knife viewmodel and responds to knife selection.")

	print("\n>>> ALL KNIFE INTEGRATION TESTS PASSED SUCCESSFULLY! <<<\n")
	quit(0)
