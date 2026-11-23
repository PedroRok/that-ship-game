shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec2 rect_size = vec2(376.0, 176.0);
uniform vec4 dark_color : source_color = vec4(0.015, 0.075, 0.085, 1.0);
uniform vec4 line_color : source_color = vec4(0.37, 0.85, 0.81, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.8;
uniform float dot_gap = 4.0;
uniform float band_speed = 0.12;
uniform float band_strength : hint_range(0.0, 1.0) = 1.0;
uniform float scan_strength : hint_range(0.0, 1.0) = 0.22;

void fragment() {
	vec2 px = floor(UV * rect_size);
	vec3 src = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(src, vec3(0.299, 0.587, 0.114));
	vec3 duo = mix(dark_color.rgb, line_color.rgb, clamp(l * 1.15, 0.0, 1.0));
	vec3 col = mix(src, duo, tint_strength);

	if (mod(px.x, dot_gap) < 1.0 && mod(px.y, dot_gap) < 1.0) {
		col += line_color.rgb * 0.06;
	}
	float band_pos = fract(TIME * band_speed) * (rect_size.y + 30.0) - 15.0;
	float band = clamp(1.0 - abs(px.y - band_pos) / 14.0, 0.0, 1.0);
	col += line_color.rgb * floor(band * 4.0) / 4.0 * 0.07 * band_strength;
	if (mod(px.y, 2.0) < 1.0) {
		col *= 1.0 - scan_strength;
	}
	col *= 0.98 + 0.02 * sin(TIME * 31.0);

	vec2 edge = min(px, rect_size - px - 1.0);
	float nearest = min(edge.x, edge.y);
	col *= 0.82 + 0.18 * clamp(nearest / 10.0, 0.0, 1.0);

	float bx = min(px.x, rect_size.x - 1.0 - px.x);
	float by = min(px.y, rect_size.y - 1.0 - px.y);
	if ((bx < 1.0 && by < 7.0) || (by < 1.0 && bx < 7.0)) {
		col = line_color.rgb;
	}
	COLOR = vec4(col, 1.0);
}
