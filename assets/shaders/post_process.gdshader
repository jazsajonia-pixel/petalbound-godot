shader_type canvas_item;
// Screen-space grade: soft bloom, lift/gamma/gain, saturation, warm/cool split tone,
// vignette, damage pulse and a gentle film grain. Drawn under the HUD.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float bloom = 0.32;
uniform float bloom_threshold = 0.86;
uniform float bloom_radius = 3.0;
uniform float saturation = 1.08;
uniform float contrast = 1.06;
uniform float exposure = 1.0;
uniform vec4 shadow_tint = vec4(0.34, 0.32, 0.52, 1.0);
uniform vec4 highlight_tint = vec4(1.0, 0.95, 0.86, 1.0);
uniform float split_tone = 0.14;
uniform float vignette = 0.32;
uniform float damage = 0.0;
uniform float grain = 0.018;
uniform float quality = 1.0;
uniform float fade = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = texture(screen_tex, uv).rgb;
	if (quality > 0.5 && bloom > 0.0) {
		vec2 px = SCREEN_PIXEL_SIZE * bloom_radius;
		vec3 acc = vec3(0.0);
		float wsum = 0.0;
		for (int i = 0; i < 12; i++) {
			float a = float(i) * 0.5236;
			float r = (i % 2 == 0) ? 2.0 : 4.5;
			vec2 o = vec2(cos(a), sin(a)) * px * r;
			vec3 s = texture(screen_tex, uv + o).rgb;
			float l = dot(s, vec3(0.3, 0.55, 0.15));
			acc += s * smoothstep(bloom_threshold, 1.0, l) * (l - bloom_threshold) / (1.0 - bloom_threshold);
			wsum += 1.0;
		}
		c += acc / wsum * bloom * 1.1;
	}
	c *= exposure;
	c = (c - 0.5) * contrast + 0.5;
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(luma), c, saturation);
	vec3 tone = mix(shadow_tint.rgb, highlight_tint.rgb, smoothstep(0.15, 0.85, luma));
	c = mix(c, c * tone * 1.12, split_tone);
	vec2 v = (uv - 0.5) * vec2(1.25, 1.0);
	float vig = smoothstep(0.35, 0.95, length(v));
	c *= 1.0 - vig * vignette;
	c = mix(c, vec3(0.75, 0.08, 0.12), damage * vig * 0.85);
	c += (hash(uv * 913.7 + TIME) - 0.5) * grain;
	c = mix(c, vec3(0.03, 0.03, 0.06), fade);
	COLOR = vec4(c, 1.0);
}
