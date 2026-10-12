extends SceneTree

func _initialize() -> void:
	var glb: PackedScene = load("res://models/knife_black.glb")
	var inst: Node3D = glb.instantiate()
	root.add_child(inst)

	var anim: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
	if anim:
		anim.play("draw")
		anim.advance(1.0) # finish draw
		if anim.has_animation("idle"):
			anim.play("idle")
			anim.seek(0.0, true)

	await process_frame
	await process_frame

	var skel: Skeleton3D = inst.find_child("Skeleton3D", true, false)
	var mi: MeshInstance3D = inst.find_child("v_knife_mesh", true, false)
	var b25 = skel.find_bone("Bone25")
	var arrays = mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var ibm: Transform3D = skel.get_bone_rest(b25).affine_inverse()

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

	var bone_pose: Transform3D = skel.get_bone_global_pose(b25)
	var skin_m: Transform3D = bone_pose * ibm

	var tip_p = skin_m * verts[tip_idx]
	var base_p = skin_m * verts[base_idx]
	var spine_p = skin_m * verts[spine_idx]
	var edge_p = skin_m * verts[edge_idx]

	var blade_dir = (tip_p - base_p).normalized()
	var edge_dir = (edge_p - spine_p).normalized()
	var normal_dir = blade_dir.cross(edge_dir).normalized()

	print("Model space at idle t=0:")
	print("  blade_dir:  ", blade_dir)
	print("  edge_dir:   ", edge_dir)
	print("  normal_dir: ", normal_dir)
	print("  base_p:     ", base_p)

	# We want:
	# blade_dir -> (0, 1, 0) (UP)
	# edge_dir  -> (-1, 0, 0) (LEFT)
	# normal_dir -> (0, 0, 1) (FORWARD/TOWARDS CAMERA)

	# Desired target basis in camera space:
	# X column = -edge_dir = (1, 0, 0) -> edge is (-1, 0, 0)
	# Y column = blade_dir = (0, 1, 0)
	# Z column = normal_dir = (0, 0, 1)
	var current_basis = Basis(edge_dir, blade_dir, normal_dir)
	# Target basis: X = (-1, 0, 0), Y = (0, 1, 0), Z = (0, 0, -1) (orthonormal)
	var target_basis = Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1))
	var required_rot_basis = target_basis * current_basis.inverse()
	var euler_rad = required_rot_basis.get_euler()
	print("Exact Euler rotation (degrees): ", Vector3(rad_to_deg(euler_rad.x), rad_to_deg(euler_rad.y), rad_to_deg(euler_rad.z)))

	quit(0)
