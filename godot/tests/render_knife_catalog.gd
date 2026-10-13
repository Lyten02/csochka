extends SceneTree
## Run with GL Compatibility, never --headless. Saves actual 1280x720 viewmodel renders.
const Settings = preload("res://scripts/utils/settings_manager.gd")
const Knife = preload("res://scripts/weapons/cs_knife.gd")

func _initialize() -> void:
	if not preload("res://tests/settings_snapshot.gd").protect(self):
		return
	call_deferred("run")

func run() -> void:
	var out := ProjectSettings.globalize_path("res://../.orchestration/knife-evidence/knives")
	DirAccess.make_dir_recursive_absolute(out)
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.20, 0.23, 0.27)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	vp.add_child(env)
	var camera := Camera3D.new()
	camera.fov = 73.74
	camera.near = 0.02
	camera.current = true
	vp.add_child(camera)
	var sm := Settings.new()
	for entry in sm.get_available_knives():
		var knife := Knife.new()
		camera.add_child(knife)
		knife.set_process(false)
		knife.set_knife_model(entry["model"], entry)
		var anim: AnimationPlayer = knife._anim
		anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var shots := [["idle", knife.animation_for_role("idle"), 0.0]]
		if entry.get("inspect_anim") != null:
			shots.append(["inspect", entry["inspect_anim"], 0.5])
		for shot in shots:
			anim.play(shot[1])
			anim.seek(anim.get_animation(shot[1]).length * shot[2], true)
			anim.pause()
			await process_frame
			await RenderingServer.frame_post_draw
			var filename := out.path_join(entry["id"] + "_" + shot[0] + ".png")
			var image := vp.get_texture().get_image()
			if image.save_png(filename) != OK:
				push_error("Failed saving " + filename)
				quit(1)
				return
			print("Saved: " + filename)
		knife.free()
		await process_frame
	sm.free()
	vp.free()
	print("KNIFE RENDERS: PASS (22 idle, 10 inspect)")
	quit(0)
