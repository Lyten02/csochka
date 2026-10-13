extends SceneTree

func _initialize() -> void:
	if not preload("res://tests/settings_snapshot.gd").protect(self):
		return
	if DisplayServer.get_name() == "headless":
		push_error("Real renderer required for screenshot")
		quit(1)
		return
	var menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame
	menu._btn_play.emit_signal("pressed")
	await process_frame
	menu._map_dialog._set_category("all")
	await process_frame
	# Windows high-DPI can halve the dialog in the saved 1280x720 frame.
	menu._map_dialog.pivot_offset = menu._map_dialog.size / 2.0
	menu._map_dialog.scale = Vector2(1.8, 1.8)
	await process_frame
	await RenderingServer.frame_post_draw
	if not menu._map_dialog.is_visible_in_tree() or menu._map_dialog._map_list.item_count != 15:
		push_error("Map dialog must show all 15 maps")
		quit(1)
		return
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://../docs/review/2026-10-13-map-removal/map_selection.jpg")
	if image == null:
		push_error("Viewport image missing")
		quit(1)
		return
	if image.get_width() != 1280 or image.get_height() != 720:
		image.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
	var error := image.save_jpg(path, 0.88)
	if image.get_width() != 1280 or image.get_height() != 720 or error != OK:
		push_error("Could not save 1280x720 map-selection JPEG: %d" % error)
		quit(1)
		return
	print("MAP SELECTION CAPTURE: PASS (15 entries, 1280x720): " + path)
	quit(0)
