shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

#include "res://shaders/lightmapped.gdshaderinc"

void fragment() {
	ALBEDO = lightmapped(UV, UV2).rgb;
}
