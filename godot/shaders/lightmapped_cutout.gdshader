shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

#include "res://shaders/lightmapped.gdshaderinc"

void fragment() {
	vec4 c = lightmapped(UV, UV2);
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
