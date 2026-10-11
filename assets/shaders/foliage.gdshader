shader_type canvas_item;
// Wind sway for trees and bushes plus a soft see-through hole when the hero walks behind canopy.
// Sprites are anchored at their base (VERTEX.y <= 0), so only the top of the sprite moves.

uniform float sway = 1.4;
uniform float speed = 1.1;
uniform vec2 player_pos = vec2(-9999.0);
uniform vec2 gust_dir = vec2(1.0, 0.0);
uniform float gust = 0.0;
uniform float blight = 0.0;
uniform float occlusion = 1.0;

varying vec2 world_pos;
varying float base_y;
varying vec4 vcol;

void vertex() {
	vcol = COLOR;
	vec2 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	float height = clamp(-VERTEX.y / 48.0, 0.0, 1.0);
	float phase = origin.x * 0.045 + origin.y * 0.03;
	float s = sin(TIME * speed + phase) * 0.6 + sin(TIME * speed * 2.3 + phase * 1.7) * 0.25;
	VERTEX.x += (s * sway + gust * gust_dir.x * 2.5) * height * height;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	base_y = origin.y;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(c.rgb, vec3(luma) * vec3(0.9, 0.95, 1.02), blight * 0.4);
	if (occlusion > 0.0 && player_pos.y < base_y - 2.0) {
		vec2 d = (world_pos - (player_pos + vec2(0.0, -8.0))) / vec2(15.0, 17.0);
		float r = length(d);
		if (r < 1.0) {
			// dithered hole keeps the pixel-art feel
			vec2 p = floor(world_pos);
			float dither = mod(p.x + p.y, 2.0);
			float a = r < 0.7 ? 0.35 : (dither > 0.5 ? 0.35 : 1.0);
			c.a *= mix(1.0, a, occlusion);
		}
	}
	COLOR = c * vcol;
}
