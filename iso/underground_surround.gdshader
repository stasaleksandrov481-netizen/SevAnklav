shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D shale_texture : source_color, repeat_enable, filter_linear_mipmap;
varying vec2 floor_pos;

void vertex() {
	floor_pos = VERTEX.xz;
}

void fragment() {
	vec3 shale = texture(shale_texture, floor_pos / 9.0).rgb;
	float distance_from_bunker = length(floor_pos / vec2(38.0, 37.0));
	float edge = 1.0 - smoothstep(0.47, 0.98, distance_from_bunker);
	ALBEDO = mix(vec3(0.044, 0.067, 0.072), shale * vec3(0.48, 0.54, 0.56), edge);
	ROUGHNESS = 1.0;
}
