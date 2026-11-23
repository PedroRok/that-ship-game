shader_type canvas_item;
#include "res://shaders/sky_clouds_pp.gdshaderinc"


uniform vec2 rect_size = vec2(1281.0, 716.0);
uniform float horizon_y = 367.0;
uniform float speed = 6.0;
uniform float time_offset = 0.0;

uniform vec4 sky_top : source_color = vec4(0.12, 0.40, 0.78, 1.0);
uniform vec4 sky_mid : source_color = vec4(0.34, 0.64, 0.93, 1.0);
uniform vec4 sky_bottom : source_color = vec4(0.82, 0.93, 1.0, 1.0);

void fragment() {
	vec2 px = floor(UV * rect_size);
	vec3 col = sky_gradient(px, horizon_y, sky_top.rgb, sky_mid.rgb, sky_bottom.rgb, 20.0);

	if (px.y < horizon_y) {
		for (int i = 0; i < 6; i++) {
			float fi = float(5 - i);
			float scale = 1.0 - fi * 0.13;
			float yc0 = 150.0 + fi * 14.0;
			float seed = 3.0 + fi * 9.0;
			if (px.y > yc0 + 60.0 || px.y < yc0 - 220.0 * scale) {
				continue;
			}
			float scroll = (TIME + time_offset) * speed * (1.0 - fi * 0.13);
			float s0 = floor(scroll);
			float f = scroll - s0;
			float bias = (1.0 - scale) * 0.10;
			float mt = (TIME + time_offset) * morph_speed;
			vec4 a = cloud_pp(px, s0, seed, yc0, scale, bias, mt);
			vec4 b = cloud_pp(px, s0 + 1.0, seed, yc0, scale, bias, mt);
			float haze = floor(min(fi * 0.12, 0.6) * 10.0 + 0.5) / 10.0;
			vec3 ca = a.a > 0.5 ? mix(a.rgb, col, haze) : col;
			vec3 cb = b.a > 0.5 ? mix(b.rgb, col, haze) : col;
			col = mix(ca, cb, f);
		}
	}
	COLOR = vec4(col, 1.0);
}
