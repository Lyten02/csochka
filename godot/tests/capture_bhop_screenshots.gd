extends SceneTree

func _initialize() -> void:
	if not preload("res://tests/settings_snapshot.gd").protect(self):
		return
	print("--- Capturing bhop_training_final screenshots ---")
	var sm = root.get_node_or_null("SettingsManager")
	if sm == null:
		var sm_script = load("res://scripts/utils/settings_manager.gd")
		sm = sm_script.new()
		sm.name = "SettingsManager"
		root.add_child(sm)

	sm.current_map_name = "bhop_training_final"
	sm.current_map_bsp = "res://maps/bhop_training_final.bsp"
	sm.current_map_glb = "res://maps/bhop_training_final.glb"

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
		{"name": "spawn_start_button", "origin": Vector3(80, -1680, -440), "yaw": 180.0, "pitch": -5.0},
		{"name": "bhop_blocks_overview", "origin": Vector3(300, -1000, -250), "yaw": 90.0, "pitch": -25.0},
		{"name": "finish_button", "origin": Vector3(-3136, 1450, -440), "yaw": 90.0, "pitch": -5.0},
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
		if img and not img.is_empty():
			var path = "res://tests/bhop_%s.png" % tp["name"]
			img.save_png(ProjectSettings.globalize_path(path))
			print("Saved: %s" % path)

	print("--- All bhop_training_final screenshots captured ---")
	quit(0)
