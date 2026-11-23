shader_type canvas_item;


uniform vec2 rect_size = vec2(1281.0, 716.0);
uniform float horizon_y = 367.0;
uniform vec4 sky_top : source_color = vec4(0.10, 0.50, 0.86, 1.0);
uniform vec4 sky_bottom : source_color = vec4(0.62, 0.88, 1.0, 1.0);
uniform vec4 cloud_light : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cloud_mid : source_color = vec4(0.82, 0.92, 1.0, 1.0);
uniform vec4 cloud_shadow : source_color = vec4(0.60, 0.78, 0.96, 1.0);
uniform float speed = 0.5;
uniform float bands = 7.0;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

float hash(float n) {
	return fract(sin(n * 78.233) * 43758.5453);
}

float cloud_sdf(vec2 p, vec2 center, float width, float height, float seed) {
	float d = 1e5;
	for (int k = 0; k < 5; k++) {
		float t = float(k) / 4.0;
		float bump = 1.0 - abs(t - 0.5) * 0.9;
		bump *= 0.75 + 0.5 * hash(seed + float(k) * 3.1);
		float r = height * bump;
		vec2 c = vec2(center.x + (t - 0.5) * width * 0.75, center.y - r * 0.55);
		d = min(d, length(p - c) - r);
	}
	return max(d, p.y - center.y);
}

void fragment() {
	vec2 px = floor(UV * rect_size);

	float t = clamp(px.y / horizon_y, 0.0, 1.0);
	float steps = bands - 1.0;
	float scaled = t * steps;
	float threshold = (BAYER[int(mod(px.y, 4.0)) * 4 + int(mod(px.x, 4.0))] + 0.5) / 16.0;
	float level = floor(scaled) + step(threshold, fract(scaled));
	vec3 color = mix(sky_top.rgb, sky_bottom.rgb, level / steps);

	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float cell = 420.0 - fi * 60.0;
		float scale = 0.55 + fi * 0.3;
		float base_y = 150.0 + fi * 60.0;
		float scroll = floor(TIME * speed * (5.0 + fi * 6.0));
		float x = px.x + scroll;
		if (px.y > base_y + 2.0 || px.y < base_y - 90.0 * scale) {
			continue;
		}
		float cell_i = floor(x / cell);
		for (int n = -1; n <= 1; n++) {
			float id = cell_i + float(n) + fi * 100.0;
			float w = (120.0 + 100.0 * hash(id)) * scale;
			float h = (26.0 + 12.0 * hash(id + 5.0)) * scale;
			float cx = (cell_i + float(n)) * cell + cell * (0.2 + 0.6 * hash(id + 9.0)) - scroll;
			float by = base_y - 30.0 * hash(id + 13.0);
			vec2 center = vec2(cx, by);
			if (abs(px.x - cx) > w * 0.8 || hash(id + 21.0) < 0.25) {
				continue;
			}
			if (cloud_sdf(px, center, w, h, id) < 0.0) {
				vec3 c = cloud_mid.rgb;
				if (cloud_sdf(px + vec2(-2.0, -3.0), center, w, h, id) >= 0.0) {
					c = cloud_light.rgb;
				} else if (px.y > by - 5.0 - 2.0 * scale) {
					c = cloud_shadow.rgb;
				}
				float haze = (2.0 - fi) * 0.25;
				color = mix(c, color, haze);
				break;
			}
		}
	}

	COLOR = vec4(color, 1.0);
}
