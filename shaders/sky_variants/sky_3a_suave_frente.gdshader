shader_type canvas_item;
#include "res://shaders/sky_clouds_smooth.gdshaderinc"


uniform vec2 rect_size = vec2(1281.0, 716.0);
uniform float horizon_y = 367.0;
uniform float speed = 6.0;
uniform float time_offset = 0.0;
uniform float front_scale = 1.35;
uniform float front_y = 175.0;
uniform float front_speed = 1.35;
uniform float front_density = -0.02;

void fragment() {
	vec2 pf = UV * rect_size;
	vec4 out_col = vec4(0.0);
	if (pf.y < horizon_y) {
		float scroll = (TIME + time_offset) * speed * front_speed;
		if (pf.y <= front_y + 60.0 && pf.y >= front_y - 220.0 * front_scale) {
			out_col = cloud_pixel(vec2(pf.x + scroll, pf.y), 91.0, front_y, front_scale, front_density);
		}
	}
	COLOR = out_col;
}
