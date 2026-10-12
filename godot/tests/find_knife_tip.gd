extends SceneTree

func _initialize() -> void:
	var k_scene = load("res://scenes/weapons/knife.tscn")
	var k = k_scene.instantiate()
	var root_node = Node3D.new()
	root.add_child(root_node)
	root_node.add_child(k)

	var anim: AnimationPlayer = k.find_child("AnimationPlayer", true, false)
	if anim and anim.has_animation("idle"):
		anim.play("idle")
		anim.seek(0.0, true)

	await process_frame
	await process_frame

	var skel: Skeleton3D = k.find_child("Skeleton3D", true, false)
	var b_knife = skel.find_bone("Bone25")
	var m_knife = skel.get_bone_global_pose(b_knife)

	# Find MeshInstance3D:
	var meshes = k.find_children("", "MeshInstance3D", true, false)
	print("Found %d MeshInstance3D nodes" % meshes.size())
	for mi in meshes:
		var mesh: Mesh = mi.mesh
		print("Mesh: ", mi.name, " surfaces: ", mesh.get_surface_count())
		for s in range(mesh.get_surface_count()):
			var arrays = mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var knife_verts: Array[Vector3] = []
			for vi in range(verts.size()):
				# In GLTF, bones array has 4 weights per vert
				var b_idx = bones[vi * 4]
				if b_idx == b_knife:
					knife_verts.append(verts[vi])
			if knife_verts.size() > 0:
				print("Surface %d has %d knife vertices!" % [s, knife_verts.size()])
				# In rest pose, find max distance from bone 25 origin:
				var max_dist = 0.0
				var tip_vert = Vector3.ZERO
				for v in knife_verts:
					var d = v.distance_to(m_knife.origin)
					if d > max_dist:
						max_dist = d
						tip_vert = v
				print("Bone 25 origin: ", m_knife.origin)
				print("Tip vert in rest pose: ", tip_vert, " dist: ", max_dist)
				print("Tip relative to bone 25: ", m_knife.affine_inverse() * tip_vert)

	quit(0)
