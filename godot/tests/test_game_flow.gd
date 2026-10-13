extends SceneTree

func _initialize() -> void:
	if not preload("res://tests/settings_snapshot.gd").protect(self):
		return
	print("--- Running Game Flow Test ---")
	var menu_scene = load("res://scenes/ui/main_menu.tscn")
	var menu = menu_scene.instantiate()
	root.add_child(menu)

	current_scene = menu
	await process_frame
	await process_frame

	# Simulate clicking Play and selecting 35hp_3
	menu._btn_play.grab_focus()
	menu._btn_play.emit_signal("pressed")
	await process_frame
	menu._on_map_selected_launch({"name": "35hp_3", "bsp": "res://maps/35hp_3.bsp"})
	
	await process_frame
	await process_frame
	await process_frame

	# Verify main scene loaded
	var main = root.get_node_or_null("Main")
	assert(main != null, "Main scene should be active in root")
	var player = main.get_node_or_null("Player")
	assert(player != null, "Player should exist")
	var hud = main.get_node_or_null("HUD")
	assert(hud != null, "HUD should exist")
	var pause_menu = main.get_node_or_null("PauseMenu")
	assert(pause_menu != null, "PauseMenu should exist")

	print("[PASS] Scene transition: Main Menu -> Main Game scene loaded successfully!")
	player.set_physics_process(false)
	assert(player._can_inspect_knife(), "Main menu focus must not block F after Play")
	var sm := root.get_node("SettingsManager")
	var original_id: String = sm.current_knife_id
	pause_menu.open_menu()
	pause_menu._btn_knives.grab_focus()
	pause_menu._on_knives_pressed()
	await process_frame
	var dialog = pause_menu._knife_dialog
	dialog._knife_list.grab_focus()
	var index := 0
	for i in range(dialog._available_knives.size()):
		if dialog._available_knives[i].get("inspect_anim") != null:
			index = i
			break
	dialog._on_knife_item_selected(index)
	dialog._on_select_pressed()
	dialog._btn_cancel.grab_focus()
	dialog._on_cancel_pressed()
	pause_menu._btn_resume.grab_focus()
	pause_menu._on_resume_pressed()
	await process_frame
	assert(player._can_inspect_knife(), "Knife selection and Resume must not leave F blocked")
	var knife = player.knife
	var anim: AnimationPlayer = knife._anim
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	anim.advance(10.0)
	# Phase 1 has no production inspect clips. A test-only clip exercises dispatch
	# on the real player/scene; phase 2 uses the selected knife's actual clip.
	if knife._inspect_anim.is_empty():
		var probe := Animation.new()
		probe.length = 0.5
		anim.get_animation_library("").add_animation("focus_test_inspect", probe)
		knife._inspect_anim = "focus_test_inspect"
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F
	event.pressed = true
	player._unhandled_input(event)
	assert(knife._is_inspecting, "F starts inspect after real menu selection and resume")
	sm.set_current_knife(original_id)
	print("[PASS] F works after Main Menu -> Play and Pause -> Knife -> Select -> Close -> Resume")
	print("Game flow verified!")
	quit(0)
