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
	env.background_color = Color(0.9, 0.9, 0.9)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env_node.environment = env
	vp.add_child(env_node)

	var cam := Camera3D.new()
	cam.fov = 74.0
	cam.near = 0.02
	cam.far = 100.0
	cam.current = true
	vp.add_child(cam)

	# Let's test rotations with Yaw ~ -90 or +90 or around that to orient shoulders at bottom
	# and both hands visible!
	# In GoldSrc, pitch/yaw/roll:
	var test_configs = [
		{"rot": Vector3(0.0, -90.0, 0.0), "off": Vector3(0.0, -0.2, -0.4), "scale": 1.0, "name": "yaw_m90"},
		{"rot": Vector3(0.0, 90.0, 0.0), "off": Vector3(0.0, -0.2, -0.4), "scale": 1.0, "name": "yaw_p90"},
		{"rot": Vector3(-10.0, -90.0, 0.0), "off": Vector3(0.0, -0.2, -0.4), "scale": 1.0, "name": "pitch_m10_yaw_m90"},
		{"rot": Vector3(10.0, -90.0, 0.0), "off": Vector3(0.0, -0.2, -0.4), "scale": 1.0, "name": "pitch_p10_yaw_m90"},
		{"rot": Vector3(0.0, -85.0, 0.0), "off": Vector3(0.0, -0.25, -0.4), "scale": 1.2, "name": "yaw_m85_scale12"},
		{"rot": Vector3(0.0, -95.0, 0.0), "off": Vector3(0.0, -0.25, -0.4), "scale": 1.2, "name": "yaw_m95_scale12"},
		{"rot": Vector3(-5.0, -90.0, 0.0), "off": Vector3(0.0, -0.25, -0.35), "scale": 1.2, "name": "pitch_m5_yaw_m90"},
		{"rot": Vector3(0.0, -90.0, 5.0), "off": Vector3(0.0, -0.25, -0.35), "scale": 1.2, "name": "roll_p5_yaw_m90"},
	]

	for cfg in test_configs:
		for c in cam.get_children():
			cam.remove_child(c)
			c.queue_free()

		var knife: CSKnife = CSKnifeScript.new()
		knife.name = "Knife"
		knife.viewmodel_rotation = cfg["rot"]
		knife.viewmodel_offset = cfg["off"]
		knife.viewmodel_scale = cfg["scale"]
		cam.add_child(knife)
		knife.set_knife_model("res://models/knife_black.glb")

		var anim: AnimationPlayer = knife.find_child("AnimationPlayer", true, false)
		if anim and anim.has_animation("idle"):
			anim.stop()
			anim.play("idle")
			anim.seek(0.0, true)
			anim.pause()

		await process_frame
		await process_frame

		var img := vp.get_texture().get_image()
		if img:
			var path := "user://both_hands_%s.png" % cfg["name"]
			img.save_png(path)
			print("Saved: %s" % ProjectSettings.globalize_path(path))

	quit(0)
