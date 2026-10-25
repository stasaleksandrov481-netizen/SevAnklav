shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, repeat_enable, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_position.xz / 3.0;
	ALBEDO = texture(albedo_texture, uv).rgb * tint.rgb;
	ROUGHNESS = 0.95;
}
