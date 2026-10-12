extends SceneTree

func _initialize() -> void:
	var out_dir := "C:/Users/zxcursed/.gemini/antigravity/brain/956c65b0-33f6-41d9-8b72-e82454f3f7a8/scratch"

	var menu_scene = load("res://scenes/ui/main_menu.tscn")
	var menu = menu_scene.instantiate()
	root.add_child(menu)

	await process_frame
	await process_frame
	await process_frame

	# 1. Main menu capture
	var img1 = root.get_viewport().get_texture().get_image()
	img1.save_png("%s/menu_main.png" % out_dir)
	print("Saved menu_main.png")

	# 2. Open Settings dialog
	menu._btn_settings.emit_signal("pressed")
	await process_frame
	await process_frame
	var img2 = root.get_viewport().get_texture().get_image()
	img2.save_png("%s/menu_settings.png" % out_dir)
	print("Saved menu_settings.png")

	# 3. Switch to Gameplay ("Разное") tab
	menu._settings_dialog._tab_container.current_tab = 0
	await process_frame
	await process_frame
	var img3 = root.get_viewport().get_texture().get_image()
	img3.save_png("%s/menu_settings_gameplay.png" % out_dir)
	print("Saved menu_settings_gameplay.png")

	# 4. Switch to Keyboard ("Клавиатура") tab
	menu._settings_dialog._tab_container.current_tab = 1
	await process_frame
	await process_frame
	var img4 = root.get_viewport().get_texture().get_image()
	img4.save_png("%s/menu_settings_keyboard.png" % out_dir)
	print("Saved menu_settings_keyboard.png")

	# 5. Open Map Select dialog
	menu._settings_dialog.visible = false
	menu._btn_play.emit_signal("pressed")
	await process_frame
	await process_frame
	var img5 = root.get_viewport().get_texture().get_image()
	img5.save_png("%s/menu_map_select.png" % out_dir)
	print("Saved menu_map_select.png")

	print("All menu screenshots captured successfully!")
	quit(0)
