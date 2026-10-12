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

	# Base was: rot = Vector3(88.0, -4.0, -42.0), off = Vector3(0.18, -0.16, -0.08), scale = 1.45
	var tests = [
		# Vary Pitch
		{"rot": Vector3(75.0, -4.0, -42.0), "name": "pitch_75"},
		{"rot": Vector3(100.0, -4.0, -42.0), "name": "pitch_100"},
		# Vary Yaw
		{"rot": Vector3(88.0, -20.0, -42.0), "name": "yaw_m20"},
		{"rot": Vector3(88.0, 15.0, -42.0), "name": "yaw_p15"},
		# Vary Roll
		{"rot": Vector3(88.0, -4.0, -20.0), "name": "roll_m20"},
		{"rot": Vector3(88.0, -4.0, -60.0), "name": "roll_m60"},
	]

	for cfg in tests:
		for c in cam.get_children():
			cam.remove_child(c)
			c.queue_free()

		var knife: CSKnife = CSKnifeScript.new()
		knife.name = "Knife"
		knife.viewmodel_rotation = cfg["rot"]
		knife.viewmodel_offset = Vector3(0.18, -0.16, -0.08)
		knife.viewmodel_scale = 1.45
		cam.add_child(knife)
		knife.set_knife_model("res://models/knife_black.glb")

		var anim: AnimationPlayer = knife.find_child("AnimationPlayer", true, false)
		if anim:
			anim.play("draw")
			anim.advance(1.0)
			if anim.has_animation("idle"):
				anim.play("idle")
				anim.seek(0.0, true)

		for f in range(4):
			await process_frame

		var img := vp.get_texture().get_image()
		if img:
			var path := "user://axis_test_%s.png" % cfg["name"]
			img.save_png(path)
			print("Saved: %s" % ProjectSettings.globalize_path(path))

	quit(0)
