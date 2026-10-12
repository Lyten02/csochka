extends SceneTree

func _initialize():
	var glb = load("res://maps/bhop_training_final.glb").instantiate()
	print("bhop_training_final children:")
	for c in glb.get_children():
		print("  child: ", c.name, " (", c.get_class(), ")")
		if c is MeshInstance3D:
			var m: Mesh = c.mesh
			print("    surfaces: ", m.get_surface_count())
			for i in m.get_surface_count():
				var mat = m.surface_get_material(i)
				var mat_name: String = mat.resource_name if mat else "null"
				var sh_name = mat.shader.resource_path if (mat is ShaderMaterial and mat.shader) else "no shader"
				print("      surface %d: %s | shader: %s" % [i, mat_name, sh_name])
	quit(0)
