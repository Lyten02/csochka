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
	cam.fov = 74.0
	cam.near = 0.02
	cam.far = 100.0
	cam.current = true
	vp.add_child(cam)

	# In Screenshot 1 (user's previous view):
	# baseline rot: (44.0, -14.0, 16.0)
	# At that rotation at t=0, blade was tilted 45 deg left, spine on left, cutting edge on right.
	# Now let's explore rotations around (44, ?, ?) to:
	# 1. Flip edge to left and spine to right
	# 2. Make blade upright (~85-90 deg)
	# Let's test pitch (X), yaw (Y), roll (Z) systematically at t=0.0!

	var test_rots = [
		Vector3(44.0, -14.0, 16.0), # baseline (Screenshot 1)
		Vector3(55.0, -14.0, 10.0),
		Vector3(60.0, -10.0, 0.0),
		Vector3(65.0, -5.0, -10.0),
		Vector3(50.0, -25.0, 20.0),
		Vector3(40.0, -35.0, 30.0),
		Vector3(55.0, -30.0, 15.0),
		Vector3(60.0, -20.0, 5.0),
	]

	for idx in range(test_rots.size()):
		var rot = test_rots[idx]
		for c in cam.get_children():
			cam.remove_child(c)
			c.queue_free()

		var knife: CSKnife = CSKnifeScript.new()
		knife.name = "Knife"
		knife.viewmodel_rotation = rot
		knife.viewmodel_offset = Vector3(0.15, -0.02, -0.02)
		knife.viewmodel_scale = 1.2
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
			var path := "user://t0_test_%d.png" % idx
			img.save_png(path)
			print("Saved: %s (rot=%s)" % [ProjectSettings.globalize_path(path), str(rot)])

	quit(0)
