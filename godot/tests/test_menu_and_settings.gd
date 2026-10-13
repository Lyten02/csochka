extends SceneTree

var failures := 0
var out_dir := ""

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image != null, "Viewport image must exist")
	if image:
		check(image.save_png(out_dir.path_join(filename)) == OK, "Save " + filename)

func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://../.orchestration/knife-evidence/menu")
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(out_dir)

	var menu_scene = load("res://scenes/ui/main_menu.tscn")
	var menu = menu_scene.instantiate()
	root.add_child(menu)

	await process_frame
	await process_frame
	await process_frame

	# 1. Main menu capture
	check(menu._btn_play.is_visible_in_tree(), "Main menu play button visible")
	check(not menu._settings_dialog.visible, "Settings initially closed")
	await capture("menu_main.png")

	# 2. Open Settings dialog
	menu._btn_settings.emit_signal("pressed")
	await process_frame
	await process_frame
	check(menu._settings_dialog.is_visible_in_tree(), "Settings opened")
	await capture("menu_settings.png")

	# 3. Switch to Gameplay ("Разное") tab
	menu._settings_dialog._tab_container.current_tab = 0
	await process_frame
	await process_frame
	check(menu._settings_dialog._tab_container.current_tab == 0, "Gameplay tab selected")
	await capture("menu_settings_gameplay.png")

	# 4. Switch to Keyboard ("Клавиатура") tab
	menu._settings_dialog._tab_container.current_tab = 1
	await process_frame
	await process_frame
	check(menu._settings_dialog._tab_container.current_tab == 1, "Keyboard tab selected")
	await capture("menu_settings_keyboard.png")

	# 5. Open Map Select dialog
	menu._settings_dialog.visible = false
	menu._btn_play.emit_signal("pressed")
	await process_frame
	await process_frame
	check(menu._map_dialog.is_visible_in_tree(), "Map selection opened")
	check(not menu._settings_dialog.visible, "Settings closed before map selection")
	await capture("menu_map_select.png")

	menu._btn_knives.emit_signal("pressed")
	await process_frame
	check(menu._knife_dialog.is_visible_in_tree(), "Knife selection opened")
	check(not menu._map_dialog.visible, "Map selection closed before knife selection")
	check(menu._knife_dialog._knife_list.item_count >= 2, "Knife list populated")
	menu.free()
	print("MENU AND SETTINGS TESTS: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)
