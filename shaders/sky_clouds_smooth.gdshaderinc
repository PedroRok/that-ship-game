
#include "res://shaders/sky_common.gdshaderinc"

uniform float cloud_fade = 0.7;

const vec3 C_HIGH = vec3(1.0, 1.0, 1.0);
const vec3 C_LIGHT = vec3(0.90, 0.95, 1.0);
const vec3 C_MID = vec3(0.74, 0.85, 0.96);
const vec3 C_SHADOW = vec3(0.56, 0.69, 0.88);
const vec3 C_DEEP = vec3(0.42, 0.55, 0.78);

float cloud_v(vec2 p, float seed, float yc0, float scale, float bias) {
	float x = p.x;
	float y = p.y;
	float yc = yc0 + (vnoise(vec2(x / (150.0 * scale), seed + 40.0)) - 0.5) * 34.0 * scale;
	float up = yc - y;
	float n = vnoise(vec2(x / (90.0 * scale), seed)) * 0.50
			+ vnoise(vec2(x / (30.0 * scale), y / (18.0 * scale) + seed)) * 0.32
			+ vnoise(vec2(x / (11.0 * scale), y / (8.0 * scale) + seed * 2.0)) * 0.18;
	n += bias;
	float size = 0.55 + 0.9 * vnoise(vec2(x / (220.0 * scale), seed + 11.0));
	float h = (34.0 + 56.0 * vnoise(vec2(x / (120.0 * scale), seed + 5.0))) * scale * size;
	float prof = smoothstep(0.30, 0.66, n);
	float top_v = (h * prof - up) / (h * 0.35 + 2.0);
	float base_v = (up + 4.0) / (14.0 * scale);
	float side_v = (n - 0.38) * 5.0;
	return min(min(top_v, base_v), side_v);
}

float cloud_in(vec2 p, float seed, float yc0, float scale, float bias) {
	return smoothstep(0.0, 0.12, cloud_v(p, seed, yc0, scale, bias));
}

vec3 cloud_ramp(float s) {
	s = clamp(s, 0.0, 4.0);
	float i = min(floor(s), 3.0);
	float f = smoothstep(0.3, 0.7, s - i);
	vec3 a = i < 0.5 ? C_DEEP : i < 1.5 ? C_SHADOW : i < 2.5 ? C_MID : C_LIGHT;
	vec3 b = i < 0.5 ? C_SHADOW : i < 1.5 ? C_MID : i < 2.5 ? C_LIGHT : C_HIGH;
	return mix(a, b, f);
}

vec4 cloud_pixel(vec2 p, float seed, float yc0, float scale, float bias) {
	float v = cloud_v(p, seed, yc0, scale, bias);
	float alpha = smoothstep(0.0, cloud_fade, v);
	if (alpha <= 0.0) {
		return vec4(0.0);
	}
	float e1 = 2.0;
	float e2 = 5.0;
	float lit = 1.0 - cloud_in(p + vec2(0.0, -e1), seed, yc0, scale, bias) * cloud_in(p + vec2(-e1, 0.0), seed, yc0, scale, bias);
	float sh1 = 1.0 - cloud_in(p + vec2(e1, e1), seed, yc0, scale, bias);
	float sh2 = 1.0 - cloud_in(p + vec2(e2, e2 * 1.5), seed, yc0, scale, bias);
	float low = 1.0 - cloud_in(p + vec2(0.0, e2 * 2.0), seed, yc0, scale, bias);
	float patch_n = smoothstep(0.58, 0.64, vnoise(vec2(p.x / 26.0, p.y / 15.0 + seed)));

	float s = 3.0;
	s -= patch_n;
	s = mix(s, min(s, 2.0), sh2);
	float u = max(sh1, low);
	s = mix(s, min(s, 1.0), u);
	s = mix(s, 0.0, sh1 * low);
	float thin = (1.0 - smoothstep(0.25, 0.45, v)) * (1.0 - lit);
	s = mix(s, min(s, 1.0), thin);
	s = mix(s, 4.0, lit * (1.0 - sh1));
	return vec4(cloud_ramp(s), alpha);
}
