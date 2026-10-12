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

	var test_rots = [
		Vector3(85.0, -5.0, -35.0),
		Vector3(90.0, -5.0, -45.0),
		Vector3(95.0, -5.0, -55.0),
		Vector3(100.0, -5.0, -65.0),
		Vector3(90.0, 5.0, -45.0),
		Vector3(95.0, 10.0, -55.0),
		Vector3(85.0, -15.0, -30.0),
		Vector3(95.0, -15.0, -50.0),
	]

	for idx in range(test_rots.size()):
		var rot = test_rots[idx]
		for c in cam.get_children():
			cam.remove_child(c)
			c.queue_free()

		var knife: CSKnife = CSKnifeScript.new()
		knife.name = "Knife"
		knife.viewmodel_rotation = rot
		knife.viewmodel_offset = Vector3(0.18, -0.05, -0.04)
		knife.viewmodel_scale = 1.35
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
			var path := "user://t0_pitch_%d.png" % idx
			img.save_png(path)
			print("Saved: %s (rot=%s)" % [ProjectSettings.globalize_path(path), str(rot)])

	quit(0)
