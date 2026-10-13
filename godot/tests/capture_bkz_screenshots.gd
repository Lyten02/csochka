extends SceneTree

func _initialize() -> void:
	print("--- Capturing bkz_goldbhop stage screenshots ---")
	var sm = root.get_node_or_null("SettingsManager")
	if sm:
		sm.current_map_name = "bkz_goldbhop"
		sm.current_map_bsp = "res://maps/bkz_goldbhop.bsp"
		sm.current_map_glb = "res://maps/bkz_goldbhop.glb"

	var main_scene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)

	var sub_vp := SubViewport.new()
	sub_vp.size = Vector2i(1280, 720)
	sub_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sub_vp)

	var cam := Camera3D.new()
	cam.fov = 73.74
	cam.near = 0.02
	cam.far = 400.0
	cam.current = true
	sub_vp.add_child(cam)

	await process_frame
	await process_frame

	var UNIT := 0.0254

	var test_points = [
		{"name": "stage_spawn", "origin": Vector3(-3376, -3792, 90), "yaw": 90.0, "pitch": 0.0},
		{"name": "stage_tele001", "origin": Vector3(-3472, -3392, 40), "yaw": 90.0, "pitch": -5.0},
		{"name": "stage_tele004", "origin": Vector3(-2384, -2064, 40), "yaw": 0.0, "pitch": -5.0},
		{"name": "stage_tele008", "origin": Vector3(-2752, -400, 40), "yaw": 0.0, "pitch": -5.0},
		{"name": "stage_tele015", "origin": Vector3(640, -2064, -340), "yaw": 90.0, "pitch": -10.0},
		{"name": "stage_mariika", "origin": Vector3(1888, 1440, 160), "yaw": 270.0, "pitch": -10.0},
		{"name": "stage_gjall", "origin": Vector3(640, 176, 370), "yaw": 180.0, "pitch": -10.0},
		{"name": "stage_ebati", "origin": Vector3(640, -224, 370), "yaw": 90.0, "pitch": -10.0},
	]

	for tp in test_points:
		var o: Vector3 = tp["origin"]
		var godot_pos = Vector3(o.x * UNIT, o.z * UNIT, -o.y * UNIT)
		var yaw: float = tp["yaw"]
		var pitch: float = tp["pitch"]
		var ang_rad = Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0.0)

		var fwd = Vector3(cos(ang_rad.x) * cos(ang_rad.y), cos(ang_rad.x) * sin(ang_rad.y), -sin(ang_rad.x))
		var godot_fwd = Vector3(fwd.x, fwd.z, -fwd.y).normalized()
		var up = Vector3.UP
		cam.global_transform = Transform3D(Basis.looking_at(godot_fwd, up), godot_pos)

		await process_frame
		await process_frame

		var img = sub_vp.get_texture().get_image()
		if img:
			var path = "res://tests/bkz_%s.png" % tp["name"]
			img.save_png(path)
			print("Saved: %s" % path)

	print("--- All stage screenshots captured ---")
	quit(0)
