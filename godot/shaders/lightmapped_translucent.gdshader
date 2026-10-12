shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

#include "res://shaders/lightmapped.gdshaderinc"

void fragment() {
	vec4 c = lightmapped(UV, UV2);
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
