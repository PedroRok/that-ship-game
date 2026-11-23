shader_type canvas_item;
#include "res://shaders/sky_variants/sky_common.gdshaderinc"


uniform vec2 rect_size = vec2(1281.0, 716.0);
uniform float horizon_y = 367.0;
uniform float block = 2.0;
uniform float speed = 6.0;
uniform float cover_strength = 0.0;
uniform float top_bumps = 0.0;
uniform float time_offset = 0.0;
uniform float front_scale = 1.35;
uniform float front_y = 175.0;
uniform float front_speed = 1.35;
uniform float front_density = -0.02;

uniform vec4 sky_top : source_color = vec4(0.12, 0.40, 0.78, 1.0);
uniform vec4 sky_mid : source_color = vec4(0.34, 0.64, 0.93, 1.0);
uniform vec4 sky_bottom : source_color = vec4(0.82, 0.93, 1.0, 1.0);

const vec3 C_HIGH = vec3(1.0, 1.0, 1.0);
const vec3 C_LIGHT = vec3(0.90, 0.95, 1.0);
const vec3 C_MID = vec3(0.74, 0.85, 0.96);
const vec3 C_SHADOW = vec3(0.56, 0.69, 0.88);
const vec3 C_DEEP = vec3(0.42, 0.55, 0.78);

float cloud_v(vec2 c, float scroll, float seed, float yc0, float scale) {
	float x = c.x * block;
	float y = c.y * block;
	float yc = yc0 + (vnoise(vec2(x / (150.0 * scale), seed + 40.0)) - 0.5) * 34.0 * scale;
	float up = yc - y;
	float cover = smoothstep(0.25, 0.75, vnoise(vec2(x / (700.0 * scale), seed + 70.0)));
	float n = vnoise(vec2(x / (90.0 * scale), seed)) * 0.50
			+ vnoise(vec2(x / (30.0 * scale), y / (18.0 * scale) + seed)) * 0.32
			+ vnoise(vec2(x / (11.0 * scale), y / (8.0 * scale) + seed * 2.0)) * 0.18;
	n += (cover - 0.45) * cover_strength + front_density;
	float size = 0.55 + 0.9 * vnoise(vec2(x / (220.0 * scale), seed + 11.0));
	size *= 1.0 + (cover - 0.5) * cover_strength * 2.0;
	float h = (34.0 + 56.0 * vnoise(vec2(x / (120.0 * scale), seed + 5.0))) * scale * size;
	float puff = 0.0;
	for (int k = 0; k < 3; k++) {
		float fk = float(k);
		float pw = (62.0 - fk * 20.0) * scale;
		float xx = x + fk * 17.0;
		float pid = floor(xx / pw);
		float pu = fract(xx / pw) * 2.0 - 1.0;
		float ph = 0.45 + 0.55 * hash21(vec2(pid, seed + fk * 7.0));
		puff = max(puff, sqrt(max(1.0 - pu * pu, 0.0)) * ph * (1.0 - fk * 0.18));
	}
	float bumps = 0.55 + 0.65 * puff + 0.10 * vnoise(vec2(x / (9.0 * scale), seed + 95.0));
	float prof = smoothstep(0.30, 0.66, n) * mix(1.0, bumps, top_bumps);
	float top_v = (h * prof - up) / (h * 0.35 + 2.0);
	float base_v = (up + 4.0) / (14.0 * scale);
	float side_v = (n - 0.38) * 5.0;
	return min(min(top_v, base_v), side_v);
}

bool inside(vec2 c, float scroll, float seed, float yc0, float scale) {
	float v = cloud_v(c, scroll, seed, yc0, scale);
	float t = bayer(c);
	return v > 0.0 && (v > 0.22 || v > 0.22 * t);
}

void fragment() {
	vec2 px = floor(UV * rect_size);
	vec4 out_col = vec4(0.0);
	if (px.y < horizon_y) {
		float e1 = max(1.0, ceil(2.0 / block));
		float e2 = max(2.0, ceil(5.0 / block));
		float scale = front_scale;
		float yc0 = front_y;
		float seed = 91.0;
		float scroll = floor((TIME + time_offset) * speed * front_speed * 1.0);
		vec2 c = floor(vec2(px.x + scroll, px.y) / block);
		if (px.y <= yc0 + 60.0 && px.y >= yc0 - 220.0 * scale) {
			if (inside(c, scroll, seed, yc0, scale)) {
				float v = cloud_v(c, scroll, seed, yc0, scale);
				bool lit_edge = !inside(c + vec2(0.0, -e1), scroll, seed, yc0, scale)
						|| !inside(c + vec2(-e1, 0.0), scroll, seed, yc0, scale);
				bool shade1 = !inside(c + vec2(e1, e1), scroll, seed, yc0, scale);
				bool shade2 = !inside(c + vec2(e2, e2 * 1.5), scroll, seed, yc0, scale);
				bool low = !inside(c + vec2(0.0, e2 * 2.0), scroll, seed, yc0, scale);
				float x = c.x * block;
				float patch_n = vnoise(vec2(x / 26.0, c.y * block / 15.0 + seed));
				vec3 cc = C_LIGHT;
				if (patch_n > 0.62) { cc = C_MID; }
				if (shade2) { cc = C_MID; }
				if (shade1 || low) { cc = C_SHADOW; }
				if (low && shade1) { cc = C_DEEP; }
				if (v < 0.35 && !lit_edge) { cc = (cc == C_DEEP) ? C_DEEP : C_SHADOW; }
				if (lit_edge && !shade1) { cc = C_HIGH; }
				out_col = vec4(cc, 1.0);
			}
		}
	}
	COLOR = out_col;
}
