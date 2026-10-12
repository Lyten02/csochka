@tool
extends EditorScenePostImport
## Import hook for maps exported by tools/bsp_to_blender.py: glTF materials carry the texture in
## baseColor (UV0) and the baked RGB lightmap in the occlusion slot (UV1 -> Godot ao_texture on UV2).
## Replace them with unlit lightmapped shaders so the look matches GoldSrc and costs no lights.
## Material "sky" (GoldSrc sky brushes) becomes a window onto the skybox.

const OPAQUE := preload("res://shaders/lightmapped_opaque.gdshader")
const CUTOUT := preload("res://shaders/lightmapped_cutout.gdshader")
const TRANSLUCENT := preload("res://shaders/lightmapped_translucent.gdshader")
const SKY_BRUSH := preload("res://shaders/sky_brush.gdshader")
const SKY_TEXTURE := preload("res://sky/desert_sky.webp")
const SKY_MATERIAL := "sky"


func _post_import(scene: Node) -> Object:
	_convert(scene)
	return scene


func _convert(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var mesh: Mesh = node.mesh
		for i in mesh.get_surface_count():
			var src := mesh.surface_get_material(i) as BaseMaterial3D
			if src != null:
				mesh.surface_set_material(i, _convert_material(src))
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_convert(child)


func _convert_material(src: BaseMaterial3D) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.resource_name = src.resource_name
	if src.resource_name == SKY_MATERIAL:
		mat.shader = SKY_BRUSH
		mat.set_shader_parameter("sky_texture", SKY_TEXTURE)
		return mat
	match src.transparency:
		BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, BaseMaterial3D.TRANSPARENCY_ALPHA_HASH:
			mat.shader = CUTOUT
		BaseMaterial3D.TRANSPARENCY_ALPHA, BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS:
			mat.shader = TRANSLUCENT
		_:
			mat.shader = OPAQUE
	mat.set_shader_parameter("albedo_texture", src.albedo_texture)
	mat.set_shader_parameter("lightmap_texture", src.ao_texture)
	mat.set_shader_parameter("albedo_color", src.albedo_color)
	return mat
