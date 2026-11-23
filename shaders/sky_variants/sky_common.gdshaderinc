
const float BAYER4[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

float hash21(vec2 p) {
	uvec2 q = uvec2(ivec2(floor(p)) + ivec2(65536));
	uint h = q.x * 374761393u + q.y * 668265263u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h = h ^ (h >> 16u);
	return float(h & 65535u) / 65535.0;
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
			mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float bayer(vec2 px) {
	return (BAYER4[int(mod(px.y, 4.0)) * 4 + int(mod(px.x, 4.0))] + 0.5) / 16.0;
}

float post(float v, float n, vec2 px) {
	float s = clamp(v, 0.0, 1.0) * (n - 1.0);
	return (floor(s) + step(bayer(px), fract(s))) / (n - 1.0);
}

vec3 sky_gradient(vec2 px, float horizon_y, vec3 top, vec3 mid, vec3 bottom, float bands) {
	float t = clamp(px.y / horizon_y, 0.0, 1.0);
	float g = post(t, bands, px);
	return g < 0.5 ? mix(top, mid, g * 2.0) : mix(mid, bottom, (g - 0.5) * 2.0);
}
