extends SceneTree

func _initialize() -> void:
	var base_rot = Basis.from_euler(Vector3(deg_to_rad(47), deg_to_rad(-14), deg_to_rad(10)))
	var r_z = Basis(Vector3.FORWARD, deg_to_rad(-35))
	var b = r_z * base_rot
	var euler = b.get_euler()
	print("Euler degrees (YXZ): ", Vector3(rad_to_deg(euler.x), rad_to_deg(euler.y), rad_to_deg(euler.z)))
	quit(0)
