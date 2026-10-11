shader_type canvas_item;

uniform float meadow_tint : hint_range(0.0, 0.7) = 0.34;
uniform float water_tint : hint_range(0.0, 0.7) = 0.28;

void fragment() {
	vec4 texel = texture(TEXTURE, UV) * COLOR;
	float green_mask = smoothstep(0.035, 0.30, texel.g - texel.r);
	float blue_mask = smoothstep(0.08, 0.34, texel.b - texel.r);
	vec3 sage = mix(texel.rgb, vec3(0.38, 0.68, 0.60), meadow_tint * green_mask);
	vec3 lagoon = mix(sage, vec3(0.31, 0.69, 0.70), water_tint * blue_mask);
	COLOR = vec4(lagoon, texel.a);
}
