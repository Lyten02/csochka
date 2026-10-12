// Unlit GoldSrc-style surface: tiling texture (UV) x baked RGB lightmap atlas (UV2).
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D lightmap_texture : source_color, filter_linear, repeat_disable;
uniform vec4 albedo_color : source_color = vec4(1.0);

vec4 lightmapped(vec2 uv, vec2 uv2) {
	vec4 base = texture(albedo_texture, uv) * albedo_color;
	base.rgb *= texture(lightmap_texture, uv2).rgb;
	return base;
}
