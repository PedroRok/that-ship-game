
#include "res://shaders/sky_common.gdshaderinc"

uniform float block = 2.0;
uniform float cloud_fade = 0.6;
uniform float morph_speed = 0.01;

const vec3 C_HIGH = vec3(1.0, 1.0, 1.0);
const vec3 C_LIGHT = vec3(0.90, 0.95, 1.0);
const vec3 C_MID = vec3(0.74, 0.85, 0.96);
const vec3 C_SHADOW = vec3(0.56, 0.69, 0.88);
const vec3 C_DEEP = vec3(0.42, 0.55, 0.78);

float cv(vec2 c, float seed, float yc0, float scale, float bias, float mt) {
	float x = c.x * block;
	float y = c.y * block;
	float yc = yc0 + (vnoise(vec2(x / (150.0 * scale), seed + 40.0 + mt * 0.5)) - 0.5) * 34.0 * scale;
	float up = yc - y;
	float n = vnoise(vec2(x / (90.0 * scale), seed + mt)) * 0.50
			+ vnoise(vec2(x / (30.0 * scale), y / (18.0 * scale) + seed + mt * 1.5)) * 0.32
			+ vnoise(vec2(x / (11.0 * scale), y / (8.0 * scale) + seed * 2.0 + mt * 2.5)) * 0.18;
	n += bias;
	float size = 0.55 + 0.9 * vnoise(vec2(x / (220.0 * scale), seed + 11.0 + mt * 0.7));
	float h = (34.0 + 56.0 * vnoise(vec2(x / (120.0 * scale), seed + 5.0 + mt * 0.8))) * scale * size;
	float prof = smoothstep(0.30, 0.66, n);
	float top_v = (h * prof - up) / (h * 0.35 + 2.0);
	float base_v = (up + 4.0) / (14.0 * scale);
	float side_v = (n - 0.38) * 5.0;
	return min(min(top_v, base_v), side_v);
}

bool cin(vec2 c, float seed, float yc0, float scale, float bias, float mt) {
	return cv(c, seed, yc0, scale, bias, mt) > 0.0;
}

vec4 cloud_pp(vec2 px, float scroll_i, float seed, float yc0, float scale, float bias, float mt) {
	vec2 c = floor(vec2(px.x + scroll_i, px.y) / block);
	float v = cv(c, seed, yc0, scale, bias, mt);
	if (v <= 0.0) {
		return vec4(0.0);
	}
	float alpha = smoothstep(0.0, cloud_fade, v);
	if (alpha <= bayer(c)) {
		return vec4(0.0);
	}
	float e1 = max(1.0, ceil(2.0 / block));
	float e2 = max(2.0, ceil(5.0 / block));
	bool lit_edge = !cin(c + vec2(0.0, -e1), seed, yc0, scale, bias, mt) || !cin(c + vec2(-e1, 0.0), seed, yc0, scale, bias, mt);
	bool shade1 = !cin(c + vec2(e1, e1), seed, yc0, scale, bias, mt);
	bool shade2 = !cin(c + vec2(e2, e2 * 1.5), seed, yc0, scale, bias, mt);
	bool low = !cin(c + vec2(0.0, e2 * 2.0), seed, yc0, scale, bias, mt);
	float patch_n = vnoise(vec2(c.x * block / 26.0, c.y * block / 15.0 + seed + mt * 2.0));

	vec3 cc = C_LIGHT;
	if (patch_n > 0.62) { cc = C_MID; }
	if (shade2) { cc = C_MID; }
	if (shade1 || low) { cc = C_SHADOW; }
	if (low && shade1) { cc = C_DEEP; }
	if (v < 0.35 && !lit_edge) { cc = (cc == C_DEEP) ? C_DEEP : C_SHADOW; }
	if (lit_edge && !shade1) { cc = C_HIGH; }
	return vec4(cc, 1.0);
}
