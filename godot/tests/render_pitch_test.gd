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

	var tests = [
		{"rot": Vector3(110.0, -4.0, -42.0), "off": Vector3(0.18, -0.16, -0.08), "scale": 1.45, "name": "p110"},
		{"rot": Vector3(115.0, -4.0, -42.0), "off": Vector3(0.18, -0.17, -0.08), "scale": 1.45, "name": "p115"},
		{"rot": Vector3(120.0, -4.0, -42.0), "off": Vector3(0.18, -0.18, -0.08), "scale": 1.45, "name": "p120"},
		{"rot": Vector3(125.0, -4.0, -42.0), "off": Vector3(0.18, -0.19, -0.08), "scale": 1.45, "name": "p125"},
	]

	for cfg in tests:
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
			var path := "user://pitch_test_%s.png" % cfg["name"]
			img.save_png(path)
			print("Saved: %s" % ProjectSettings.globalize_path(path))

	quit(0)
