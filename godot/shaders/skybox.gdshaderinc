// Equirectangular skybox lookup shared by the sky and the map's sky brushes.
// Same convention as three.js equirectUv (image from tools/make_skybox.py):
// u = atan(d.z, d.x) / 2pi + 0.5, v measured from the top row.
uniform sampler2D sky_texture : source_color, filter_linear, repeat_enable;

vec3 skybox_color(vec3 dir) {
	vec3 d = normalize(dir);
	vec2 uv = vec2(atan(d.z, d.x) / TAU + 0.5, 0.5 - asin(clamp(d.y, -1.0, 1.0)) / PI);
	return textureLod(sky_texture, uv, 0.0).rgb; // LOD 0: no mip seam at the atan wrap
}
