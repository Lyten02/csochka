extends SceneTree

const CSKnifeScript = preload("res://scripts/weapons/cs_knife.gd")

func _initialize() -> void:
	var cam := Camera3D.new()
	cam.fov = 73.74
	cam.near = 0.02
	cam.far = 100.0
	cam.current = true
	root.add_child(cam)

	var knife: CSKnife = CSKnifeScript.new()
	knife.name = "Knife"
	knife.viewmodel_rotation = Vector3(38.0, 24.0, 24.0)
	knife.viewmodel_offset = Vector3(0.15, 0.02, -0.01)
	knife.viewmodel_scale = 1.15
	cam.add_child(knife)
	knife.set_knife_model("res://models/knife_black.glb")

	var anim: AnimationPlayer = knife.find_child("AnimationPlayer", true, false)
	print("After set_knife_model: anim=", anim.current_animation, " pos=", anim.current_animation_position)

	if anim and anim.has_animation("idle"):
		anim.play("idle")
		anim.seek(0.0, true)
		print("After play idle seek 0: anim=", anim.current_animation, " pos=", anim.current_animation_position)

	for f in range(6):
		await process_frame
		var skel: Skeleton3D = knife.find_child("Skeleton3D", true, false)
		var b25 = skel.find_bone("Bone25")
		var p = skel.get_bone_global_pose(b25).origin
		print("Frame %d: anim=%s pos=%.3f bone25_origin=%s" % [f, anim.current_animation, anim.current_animation_position, str(p)])

	quit(0)
