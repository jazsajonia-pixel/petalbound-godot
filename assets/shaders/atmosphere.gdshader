shader_type canvas_item;
render_mode blend_mix;
// Screen-space atmosphere: drifting mist (fog sheet), forest light shafts and heat shimmer tint.

uniform sampler2D fog_tex : repeat_enable, filter_nearest;
uniform vec2 camera_px = vec2(0.0);
uniform float fog = 0.0;
uniform vec4 fog_color = vec4(0.86, 0.92, 0.96, 1.0);
uniform float rays = 0.0;
uniform vec4 ray_color = vec4(1.0, 0.96, 0.78, 1.0);
uniform float zoom = 1.6;

void fragment() {
	vec2 world = camera_px + (UV - 0.5) * vec2(640.0, 360.0) / zoom;
	vec2 p = floor(world);
	float f1 = texture(fog_tex, p / vec2(320.0, 180.0) * 0.8 + vec2(TIME * 0.012, TIME * 0.004)).a;
	float f2 = texture(fog_tex, p / vec2(320.0, 180.0) * 0.55 + vec2(-TIME * 0.008, TIME * 0.006) + 0.5).a;
	float mist = clamp((f1 + f2) * 0.5, 0.0, 1.0) * fog;
	vec4 c = vec4(fog_color.rgb, mist * 0.55);
	if (rays > 0.0) {
		float diag = (UV.x * 1.6 + UV.y * 0.9) * 7.0 + camera_px.x * 0.002;
		float shaft = pow(max(0.0, sin(diag + sin(TIME * 0.15) * 0.6)), 14.0) * (1.0 - UV.y * 0.75);
		float shaft2 = pow(max(0.0, sin(diag * 0.63 + 1.7 + TIME * 0.05)), 22.0) * (1.0 - UV.y * 0.6);
		float r = (shaft + shaft2 * 0.7) * rays;
		c.rgb = mix(c.rgb, ray_color.rgb, r / max(0.001, c.a + r));
		c.a = max(c.a, r * 0.32);
	}
	COLOR = c;
}
