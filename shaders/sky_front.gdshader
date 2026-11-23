shader_type canvas_item;
#include "res://shaders/sky_clouds_pp.gdshaderinc"


uniform vec2 rect_size = vec2(1281.0, 716.0);
uniform float horizon_y = 367.0;
uniform float speed = 6.0;
uniform float time_offset = 0.0;
uniform float front_scale = 1.35;
uniform float front_y = 175.0;
uniform float front_speed = 1.35;
uniform float front_density = -0.02;

void fragment() {
	vec2 px = floor(UV * rect_size);
	vec4 out_col = vec4(0.0);
	if (px.y < horizon_y && px.y <= front_y + 60.0 && px.y >= front_y - 220.0 * front_scale) {
		float scroll = (TIME + time_offset) * speed * front_speed;
		float s0 = floor(scroll);
		float f = scroll - s0;
		float mt = (TIME + time_offset) * morph_speed;
		vec4 a = cloud_pp(px, s0, 91.0, front_y, front_scale, front_density, mt);
		vec4 b = cloud_pp(px, s0 + 1.0, 91.0, front_y, front_scale, front_density, mt);
		vec4 pa = vec4(a.rgb * a.a, a.a);
		vec4 pb = vec4(b.rgb * b.a, b.a);
		vec4 m = mix(pa, pb, f);
		out_col = vec4(m.rgb / max(m.a, 0.0001), m.a);
	}
	COLOR = out_col;
}
