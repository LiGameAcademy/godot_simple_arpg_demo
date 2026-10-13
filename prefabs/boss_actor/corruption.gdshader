shader_type spatial;
render_mode diffuse_burley;

uniform float corruption_amount : hint_range(0.0, 1.0) = 1.0;
uniform vec4 base_color : source_color = vec4(0.55, 0.55, 0.55, 1.0);
uniform sampler2D base_texture : source_color;
uniform bool use_texture = false;
uniform vec4 corruption_color : source_color = vec4(0.16, 0.035, 0.26, 1.0);
uniform vec4 crack_color : source_color = vec4(0.05, 0.85, 0.8, 1.0);
uniform float emission_strength : hint_range(0.0, 3.0) = 0.7;
varying vec3 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	float bands = sin(local_position.y * 23.0 + sin(local_position.x * 13.0) *2.4 + sin(local_position.z * 11.0)) ;
	float crack = 1.0 - smoothstep(0.025, 0.095, abs(bands));
	vec3 original = base_color.rgb;
	if (use_texture) {
		original *= texture(base_texture, UV).rgb;
	}
	ALBEDO = mix(original, corruption_color.rgb, corruption_amount * 0.5);
	ALBEDO = mix(ALBEDO, crack_color.rgb, corruption_amount * 0.45);
	EMISSION = crack_color.rgb * crack * corruption_amount * emission_strength;
	ROUGHNESS = 0.65;
}
