// GoldSrc sky brushes: a window onto the skybox that hides everything behind it.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;

#include "res://shaders/skybox.gdshaderinc"

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = skybox_color(world_pos - CAMERA_POSITION_WORLD);
}
