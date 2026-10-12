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

	var knife: CSKnife = CSKnifeScript.new()
	knife.viewmodel_rotation = Vector3(34.0, 28.0, 28.0)
	knife.viewmodel_offset = Vector3(0.16, 0.02, -0.01)
	knife.viewmodel_scale = 1.2
	cam.add_child(knife)
	knife.set_knife_model("res://models/knife_black.glb")

	# Find mesh vertices and bone
	var skel: Skeleton3D = knife.find_child("Skeleton3D", true, false)
	var b_knife = skel.find_bone("Bone25")
	var mi: MeshInstance3D = knife.find_child("v_knife_mesh", true, false)
	var mesh: Mesh = mi.mesh
	var arrays = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var ibm: Transform3D = skel.get_bone_rest(b_knife).affine_inverse()

	# Identify Tip, Base, Spine, CuttingEdge in local mesh space
	var tip_idx = 0
	var base_idx = 0
	var min_z = 999.0
	var max_z = -999.0
	for i in range(verts.size()):
		if verts[i].z < min_z:
			min_z = verts[i].z
			tip_idx = i
		if verts[i].z > max_z:
			max_z = verts[i].z
			base_idx = i

	var spine_idx = 0
	var edge_idx = 0
	var min_y = 999.0
	var max_y = -999.0
	for i in range(verts.size()):
		if verts[i].z < -0.35 and verts[i].z > -0.45:
			if verts[i].y < min_y:
				min_y = verts[i].y
				spine_idx = i
			if verts[i].y > max_y:
				max_y = verts[i].y
				edge_idx = i

	print("Tip vert: ", verts[tip_idx])
	print("Base vert: ", verts[base_idx])
	print("Spine vert: ", verts[spine_idx], " UV: ", uvs[spine_idx])
	print("Edge vert: ", verts[edge_idx], " UV: ", uvs[edge_idx])

	# Test animation frame 0
	var anim: AnimationPlayer = knife.find_child("AnimationPlayer", true, false)
	if anim and anim.has_animation("idle"):
		anim.play("idle")
		anim.seek(0.0, true)

	for f in range(2):
		await process_frame

	var bone_pose: Transform3D = skel.get_bone_global_pose(b_knife)
	var skin_m: Transform3D = skel.global_transform * bone_pose * ibm

	var tip_cam: Vector3 = skin_m * verts[tip_idx]
	var base_cam: Vector3 = skin_m * verts[base_idx]
	var spine_cam: Vector3 = skin_m * verts[spine_idx]
	var edge_cam: Vector3 = skin_m * verts[edge_idx]

	print("Tip in Cam: ", tip_cam)
	print("Base in Cam: ", base_cam)
	print("Spine in Cam: ", spine_cam)
	print("Edge in Cam: ", edge_cam)

	var blade_dir = (tip_cam - base_cam).normalized()
	print("Blade Dir: ", blade_dir)
	print("Edge.x < Spine.x: ", edge_cam.x < spine_cam.x, " (Edge.x = ", edge_cam.x, ", Spine.x = ", spine_cam.x, ")")
	print("Tip.y > Base.y: ", tip_cam.y > base_cam.y)

	quit(0)
