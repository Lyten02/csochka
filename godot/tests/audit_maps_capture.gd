extends SceneTree
## Read-only audit: real main scene, renderer and player; never saves settings.
var out_dir: String

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var args := OS.get_cmdline_user_args()
	var id := args[0]
	out_dir = args[1]
	var sm = root.get_node("SettingsManager")
	var catalog: Array = sm.get_available_maps()
	var f := FileAccess.open(out_dir.path_join("catalog.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(catalog, "\t"))
	f.close()
	sm.current_map_name = id
	sm.current_map_bsp = "res://maps/%s.bsp" % id
	sm.current_map_glb = "res://maps/%s.glb" % id if ResourceLoader.exists("res://maps/%s.glb" % id) else ""
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.size = Vector2i(1280, 720)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var p = main.get_node("Player")
	p.set_process_input(false)
	p.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var result := {"id": id, "glb": sm.current_map_glb, "samples": []}
	for second in range(6):
		await create_timer(1.0).timeout
		var sample := {"second": second + 1, "origin": str(p.pm.origin), "velocity": str(p.pm.velocity), "ground": p.pm.onground, "solid": p.bsp.test_player_position(p.pm.origin, p.pm.usehull), "teleports": p.teleport_count}
		result.samples.append(sample)
		print("AUDIT_SAMPLE ", JSON.stringify(sample))
	p.set_physics_process(false)
	p.set_process(false)
	await save_image(id + "_spawn")
	var cam: Camera3D = p.get_node("Camera3D")
	var pos := cam.global_position
	var forward := -cam.global_basis.z
	cam.global_position = pos + Vector3.UP * 3.0
	cam.look_at(pos + forward * 12.0, Vector3.UP)
	await save_image(id + "_elevated")
	cam.global_position = pos
	cam.look_at(pos - forward * 12.0, Vector3.UP)
	await save_image(id + "_reverse")
	f = FileAccess.open(out_dir.path_join(id + ".json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(result, "\t"))
	f.close()
	if id == "bkz_goldbhop":
		cam.global_position = Vector3(-3472, 90, 3392) * 0.0254
		cam.look_at(cam.global_position + Vector3(0, -0.08, -1), Vector3.UP)
		await save_image(id + "_course")
	print("AUDIT_COMPLETE ", id)
	quit()

func save_image(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var err := image.save_jpg(out_dir.path_join(label + ".jpg"), 0.85)
	print("AUDIT_IMAGE ", label, " ", image.get_size(), " error=", err)
