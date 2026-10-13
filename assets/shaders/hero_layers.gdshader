shader_type canvas_item;
// Mallow's shader: per-body-region colour layers (appearance + worn gear) driven
// by a region mask that matches the current sprite sheet, plus the shared actor
// effects (hit flash, outline, tint, dissolve). See tools/build_hero_masks.py.

uniform sampler2D mask_tex : filter_nearest;
uniform bool use_mask = false;
// 5 regions (head, chest, arms, legs, feet) x 4 colours (light, mid, dark, extra)
uniform vec4 region_cols[20];
uniform float region_glow[5];
uniform vec4 glow_color = vec4(1.0, 0.85, 0.45, 1.0);
uniform vec4 skin_color = vec4(1.0, 0.9, 0.8, 1.0);
uniform vec4 accent_color = vec4(1.0, 0.82, 0.48, 1.0);
uniform vec4 eye_color = vec4(0.95, 0.92, 0.95, 1.0);
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
	if (use_mask && c.a > 0.1) {
		vec4 m = texture(mask_tex, UV);
		if (m.a > 0.5) {
			int region = int(round(m.r * 255.0 / 32.0));
			int shade = int(round(m.g * 255.0 / 40.0));
			if (region == 6) {
				c.rgb = shade == 5 ? eye_color.rgb : (shade == 3 ? accent_color.rgb : skin_color.rgb);
			} else if (region >= 1 && region <= 5) {
				int base = (region - 1) * 4;
				bool covers = region == 3 || region == 5;
				if (shade <= 2) {
					c.rgb = region_cols[base + shade].rgb;
				} else if (shade == 3) {
					c.rgb = covers ? region_cols[base + 3].rgb : accent_color.rgb;
				} else if (shade == 4) {
					c.rgb = covers ? region_cols[base + 3].rgb : skin_color.rgb;
				} else {
					c.rgb = eye_color.rgb;
				}
				float g = region_glow[region - 1];
				if (g > 0.0) {
					float sweep = 0.5 + 0.5 * sin(TIME * 3.0 + UV.y * 90.0 - UV.x * 40.0);
					c.rgb = mix(c.rgb, glow_color.rgb, g * 0.35 * sweep);
				}
			}
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
