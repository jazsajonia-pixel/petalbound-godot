shader_type canvas_item;
// Petalbound world ground: biome splatting, organic roads, animated water and shorelines,
// all resolved per world pixel so edges stay crisp at any camera zoom.

uniform sampler2D floor_atlas : filter_nearest;
uniform sampler2D biome_map : filter_nearest;
uniform sampler2D field_map : filter_linear;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform vec2 world_px = vec2(4096.0, 2816.0);
uniform vec2 map_tiles = vec2(256.0, 176.0);
uniform vec2 atlas_px = vec2(352.0, 417.0);
// per biome: xy = plain fill tile, z = first decorated tile x, w = decorated count
uniform vec4 ground_tiles[8];
uniform vec4 path_tiles[8];
uniform vec4 water_shallow[8];
uniform vec4 water_deep[8];
uniform vec4 biome_grade[8];
uniform vec4 foam_color = vec4(0.93, 1.0, 1.0, 1.0);
uniform vec4 shore_line = vec4(0.16, 0.29, 0.34, 1.0);
uniform vec2 moonwell_px = vec2(2048.0, 416.0);
uniform float moonwell_power = 0.0;
uniform float blight = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

int biome_at(vec2 wp) {
	vec2 n = texture(noise_tex, wp / 384.0).rg - 0.5;
	vec2 n2 = texture(noise_tex, wp / 61.0 + 0.37).rg - 0.5;
	vec2 warped = wp + floor(n * 18.0 + n2 * 7.0);
	ivec2 t = ivec2(clamp(floor(warped / 16.0), vec2(0.0), map_tiles - 1.0));
	return int(texelFetch(biome_map, t, 0).r * 255.0 + 0.5);
}

vec3 tile_sample(vec4 def, vec2 wp, float salt) {
	vec2 tile = floor(wp / 16.0);
	float h = hash21(tile + salt);
	vec2 cell = def.xy;
	if (h > 0.78 && def.w > 0.0) {
		cell = vec2(def.z + floor(hash21(tile * 1.7 + salt) * def.w), def.y);
	}
	vec2 local = mod(wp, 16.0);
	// rotate plain cells by mirroring to break repetition
	if (h < 0.39) { local.x = 15.0 - local.x; }
	vec2 uv = (cell * 16.0 + local + 0.5) / atlas_px;
	return texture(floor_atlas, uv).rgb;
}

void fragment() {
	vec2 wp = floor(UV * world_px);
	int b = biome_at(wp);
	vec3 col = tile_sample(ground_tiles[b], wp, 0.0);

	// biome borders: 1px ink line plus soft shading on the lower-priority side
	int bn = biome_at(wp + vec2(0.0, -1.0));
	int bs = biome_at(wp + vec2(0.0, 1.0));
	int bw = biome_at(wp + vec2(-1.0, 0.0));
	int be = biome_at(wp + vec2(1.0, 0.0));
	int top = max(max(bn, bs), max(bw, be));
	if (top > b) {
		col *= 0.80;
	}

	// macro colour variation so large fields never look tiled
	float macro = texture(noise_tex, wp / 900.0 + 0.11).b;
	col *= 0.94 + macro * 0.11;
	col = mix(col, col * biome_grade[b].rgb, biome_grade[b].a);

	vec3 field = texture(field_map, (wp + 0.5) / world_px).rgb;
	float jag = (texture(noise_tex, wp / 23.0 + 0.71).b - 0.5);

	// roads
	float road = field.r + jag * 0.22;
	if (road > 0.5) {
		vec3 dirt = tile_sample(path_tiles[b], wp, 3.0);
		if (road < 0.555) { dirt *= 0.80; }
		col = dirt;
	} else if (road > 0.44) {
		col *= 0.90;
	}

	// water
	float w = field.g + jag * 0.10;
	float depth = field.b;
	if (w > 0.5) {
		vec3 shallow = water_shallow[b].rgb;
		vec3 deep = water_deep[b].rgb;
		vec3 wc = mix(shallow, deep, smoothstep(0.30, 0.95, depth));
		float t = TIME;
		float wave = sin((wp.x + sin(wp.y * 0.11 + t * 0.7) * 7.0) * 0.085 + t * 1.3) * sin(wp.y * 0.23 - t * 0.8 + wp.x * 0.015);
		float row = mod(wp.y, 3.0);
		if (wave > 0.80 && row < 1.0) {
			wc = mix(wc, foam_color.rgb, 0.45);
		} else if (wave < -0.86 && row < 1.0) {
			wc *= 0.90;
		}
		float spark = hash21(floor(wp / 2.0) + floor(t * 2.5) * 0.173);
		if (spark > 0.9965 && depth > 0.2) { wc = vec3(1.0); }
		float foam_w = 0.04 + 0.026 * sin(t * 2.1 + (wp.x * 0.13 + wp.y * 0.17));
		if (w < 0.5 + foam_w) {
			wc = foam_color.rgb;
		} else if (w < 0.5 + foam_w + 0.035) {
			wc = mix(wc, foam_color.rgb, 0.4);
		}
		// Moonwell: golden shimmer once restored
		float mw = length(wp - moonwell_px);
		if (mw < 64.0) {
			float ring = sin(mw * 0.35 - t * 3.0) * 0.5 + 0.5;
			vec3 gold = mix(vec3(0.55, 0.62, 0.86), vec3(1.0, 0.86, 0.45), moonwell_power);
			wc = mix(wc, gold, (0.35 + ring * 0.35) * (1.0 - mw / 64.0));
		}
		col = wc;
	} else if (w > 0.475) {
		col = mix(col, shore_line.rgb, 0.85);
	} else if (w > 0.42) {
		col *= 0.80;
	}

	// blight drains colour until the Moonseeds return
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(luma) * vec3(0.92, 0.95, 1.02), blight * 0.45);
	COLOR = vec4(col, 1.0);
}

