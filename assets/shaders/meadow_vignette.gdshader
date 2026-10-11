shader_type canvas_item;

uniform vec4 edge_tint : source_color = vec4(0.12, 0.20, 0.23, 1.0);
uniform float strength : hint_range(0.0, 0.45) = 0.19;
uniform float inner_radius : hint_range(0.1, 1.0) = 0.48;
uniform float outer_radius : hint_range(0.5, 1.8) = 1.25;

void fragment() {
	vec2 centered = (UV - vec2(0.5)) * vec2(1.45, 1.0);
	float edge = smoothstep(inner_radius, outer_radius, length(centered));
	COLOR = vec4(edge_tint.rgb, edge * strength);
}
