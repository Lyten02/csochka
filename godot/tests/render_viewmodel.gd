extends SceneTree

const CSKnifeScript = preload("res://scripts/weapons/cs_knife.gd")

func _initialize() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.15, 0.18)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env_node.environment = env
	vp.add_child(env_node)

	var cam := Camera3D.new()
	cam.fov = 73.74
	cam.near = 0.02
	cam.far = 100.0
	cam.current = true
	vp.add_child(cam)

	var test_configs = [
		{"rot": Vector3(38.0, 24.0, 24.0), "off": Vector3(0.13, 0.00, -0.02), "scale": 1.1, "name": "refine_1"},
		{"rot": Vector3(38.0, 24.0, 24.0), "off": Vector3(0.15, 0.02, -0.01), "scale": 1.15, "name": "refine_2"},
		{"rot": Vector3(36.0, 26.0, 26.0), "off": Vector3(0.14, 0.01, -0.02), "scale": 1.15, "name": "refine_3"},
		{"rot": Vector3(36.0, 26.0, 26.0), "off": Vector3(0.16, 0.02, -0.01), "scale": 1.2, "name": "refine_4"},
		{"rot": Vector3(34.0, 28.0, 28.0), "off": Vector3(0.15, 0.02, -0.01), "scale": 1.2, "name": "refine_5"},
		{"rot": Vector3(34.0, 28.0, 28.0), "off": Vector3(0.17, 0.03, 0.00), "scale": 1.25, "name": "refine_6"},
		{"rot": Vector3(40.0, 22.0, 22.0), "off": Vector3(0.15, 0.01, -0.02), "scale": 1.15, "name": "refine_7"},
		{"rot": Vector3(40.0, 25.0, 20.0), "off": Vector3(0.15, 0.02, -0.01), "scale": 1.15, "name": "refine_8"},
	]

	for i in range(test_configs.size()):
		var cfg = test_configs[i]
		for c in cam.get_children():
			cam.remove_child(c)
			c.queue_free()

		var knife: CSKnife = CSKnifeScript.new()
		knife.name = "Knife"
		knife.viewmodel_rotation = cfg["rot"]
		knife.viewmodel_offset = cfg["off"]
		knife.viewmodel_scale = cfg.get("scale", 1.0)
		cam.add_child(knife)
		knife.set_knife_model("res://models/knife_black.glb")
		var anim: AnimationPlayer = knife.find_child("AnimationPlayer", true, false)
		if anim and anim.has_animation("idle"):
			anim.play("idle")
			anim.seek(0.0, true)
		for f in range(4):
			await process_frame

		var img := vp.get_texture().get_image()
		if img:
			var path := "user://refine_%s.png" % cfg["name"]
			img.save_png(path)
			print("Saved: %s" % ProjectSettings.globalize_path(path))

	quit(0)
