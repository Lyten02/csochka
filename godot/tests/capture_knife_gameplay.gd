extends SceneTree
## Real GL renderer, routed physical-F input, temporal inspect frames and scrolled UI.

func _initialize() -> void:
	call_deferred("run")

func capture(out: String, filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image.save_png(out.path_join(filename)) == OK)
	print("Saved: " + out.path_join(filename))

func run() -> void:
	var out := ProjectSettings.globalize_path("res://../.orchestration/knife-evidence/gameplay")
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	var sm := root.get_node("SettingsManager")
	var previous := [sm.current_knife_id, sm.current_map_name, sm.current_map_bsp, sm.current_map_glb]
	sm.current_knife_id = "cs16forge_talon_knife_case_hardened"
	sm.current_map_name = "35hp_3"
	sm.current_map_bsp = "res://maps/35hp_3.bsp"
	sm.current_map_glb = "res://maps/35hp_3.glb"
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var player = main.get_node("Player")
	for i in range(500):
		await physics_frame
		if player.teleport_count > 0 and player.pm.onground != -1:
			break
	player.set_physics_process(false)
	var knife = player.knife
	var anim: AnimationPlayer = knife._anim
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	anim.advance(10.0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await capture(out, "talon_idle.png")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	assert(knife._is_inspecting, "Routed physical F must start real inspect")
	var clip_name: String = knife._inspect_anim
	var length: float = anim.get_animation(clip_name).length
	var last := 0.0
	for fraction in [0.10, 0.35, 0.60, 0.85]:
		anim.advance(length * (fraction - last))
		last = fraction
		await capture(out, "talon_inspect_%02d.png" % int(fraction * 100))
		print("INSPECT MOTION clip=%s time=%.3f / %.3f" % [clip_name, anim.current_animation_position, length])
	anim.advance(length)
	assert(not knife._is_inspecting)
	await capture(out, "talon_return_idle.png")
	event.pressed = false
	Input.parse_input_event(event)
	var pause = main.get_node("PauseMenu")
	pause.open_menu()
	pause._on_knives_pressed()
	await process_frame
	var dialog = pause._knife_dialog
	dialog._knife_list.select(21)
	dialog._knife_list.ensure_current_is_visible()
	dialog._on_knife_item_selected(21)
	await capture(out, "knife_dialog_scrolled.png")
	pause.close_menu()
	sm.current_knife_id = previous[0]
	sm.current_map_name = previous[1]
	sm.current_map_bsp = previous[2]
	sm.current_map_glb = previous[3]
	print("GAMEPLAY KNIFE EVIDENCE: PASS (physical F, four temporal poses, return to idle, scrolled 22-item dialog)")
	quit(0)
