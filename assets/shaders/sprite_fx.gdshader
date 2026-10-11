shader_type canvas_item;
// Shared actor shader: palette swap (outfits), hit flash, outline, dissolve-on-death.

uniform int swap_count = 0;
uniform vec4 src_colors[8];
uniform vec4 dst_colors[8];
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline : hint_range(0.0, 1.0) = 0.0;
uniform vec4 outline_color = vec4(1.0, 0.95, 0.7, 1.0);
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 dissolve_color = vec4(1.0, 0.85, 0.55, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint_color = vec4(1.0);
uniform sampler2D noise_tex : repeat_enable, filter_nearest;

varying vec4 vcol;

void vertex() {
	vcol = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	for (int i = 0; i < 8; i++) {
		if (i >= swap_count) { break; }
		if (distance(c.rgb, src_colors[i].rgb) < 0.035) {
			c.rgb = dst_colors[i].rgb;
		}
	}
	if (outline > 0.0 && c.a < 0.1) {
		vec2 px = TEXTURE_PIXEL_SIZE;
		float a = texture(TEXTURE, UV + vec2(px.x, 0.0)).a + texture(TEXTURE, UV - vec2(px.x, 0.0)).a
			+ texture(TEXTURE, UV + vec2(0.0, px.y)).a + texture(TEXTURE, UV - vec2(0.0, px.y)).a;
		if (a > 0.0) {
			c = vec4(outline_color.rgb, outline_color.a * outline);
		}
	}
	c.rgb = mix(c.rgb, tint_color.rgb, tint_amount);
	c.rgb = mix(c.rgb, flash_color.rgb, flash);
	if (dissolve > 0.0) {
		float n = texture(noise_tex, UV * 6.0).b;
		if (n < dissolve) { discard; }
		if (n < dissolve + 0.08) { c.rgb = dissolve_color.rgb; }
	}
	COLOR = c * vcol;
}
