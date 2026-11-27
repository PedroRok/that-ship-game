shader_type canvas_item;

uniform vec2 rect_size = vec2(150.0, 90.0);
uniform vec4 base_color : source_color = vec4(0.015, 0.075, 0.085, 1.0);
uniform vec4 line_color : source_color = vec4(0.30, 0.86, 0.82, 1.0);
uniform float dot_gap = 4.0;
uniform float band_speed = 0.12;
uniform float dot_strength = 1.0;
uniform float scan_strength = 1.0;
uniform float band_strength = 1.0;

varying float fade;

void vertex() {
	fade = COLOR.a;
}

void fragment() {
	vec2 px = floor(UV * rect_size);
	vec3 col = base_color.rgb;

	if (mod(px.x, dot_gap) < 1.0 && mod(px.y, dot_gap) < 1.0) {
		col += line_color.rgb * 0.07 * dot_strength;
	}

	float band_pos = fract(TIME * band_speed) * (rect_size.y + 30.0) - 15.0;
	float band = clamp(1.0 - abs(px.y - band_pos) / 14.0, 0.0, 1.0);
	col += line_color.rgb * floor(band * 4.0) / 4.0 * 0.07 * band_strength;

	if (mod(px.y, 2.0) < 1.0) {
		col *= 1.0 - 0.12 * scan_strength;
	}
	col *= 0.98 + 0.02 * sin(TIME * 31.0);

	vec2 edge = min(px, rect_size - px - 1.0);
	float nearest = min(edge.x, edge.y);
	col += line_color.rgb * (nearest < 2.0 ? 0.05 : 0.0);
	col *= 0.82 + 0.18 * clamp(nearest / 10.0, 0.0, 1.0);

	float bx = min(px.x, rect_size.x - 1.0 - px.x);
	float by = min(px.y, rect_size.y - 1.0 - px.y);
	if ((bx < 1.0 && by < 7.0) || (by < 1.0 && bx < 7.0)) {
		col = line_color.rgb;
	}
	COLOR = vec4(col, fade);
}
