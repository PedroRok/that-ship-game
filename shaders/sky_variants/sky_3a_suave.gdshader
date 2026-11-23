shader_type canvas_item;
#include "res://shaders/sky_clouds_smooth.gdshaderinc"


uniform vec2 rect_size = vec2(1281.0, 716.0);
uniform float horizon_y = 367.0;
uniform float speed = 6.0;
uniform float time_offset = 0.0;

uniform vec4 sky_top : source_color = vec4(0.12, 0.40, 0.78, 1.0);
uniform vec4 sky_mid : source_color = vec4(0.34, 0.64, 0.93, 1.0);
uniform vec4 sky_bottom : source_color = vec4(0.82, 0.93, 1.0, 1.0);

void fragment() {
	vec2 pf = UV * rect_size;
	vec2 px = floor(pf);
	vec3 col = sky_gradient(px, horizon_y, sky_top.rgb, sky_mid.rgb, sky_bottom.rgb, 20.0);

	if (px.y < horizon_y) {
		for (int i = 0; i < 6; i++) {
			float fi = float(5 - i);
			float scale = 1.0 - fi * 0.13;
			float yc0 = 150.0 + fi * 14.0;
			float seed = 3.0 + fi * 9.0;
			float scroll = (TIME + time_offset) * speed * (1.0 - fi * 0.13);
			if (pf.y > yc0 + 60.0 || pf.y < yc0 - 220.0 * scale) {
				continue;
			}
			vec4 cl = cloud_pixel(vec2(pf.x + scroll, pf.y), seed, yc0, scale, (1.0 - scale) * 0.10);
			if (cl.a > 0.0) {
				float haze = floor(min(fi * 0.12, 0.6) * 10.0 + 0.5) / 10.0;
				col = mix(col, mix(cl.rgb, col, haze), cl.a);
			}
		}
	}
	COLOR = vec4(col, 1.0);
}
