shader_type canvas_item;

uniform vec2 rect_size = vec2(150.0, 90.0);
uniform vec4 base_color : source_color = vec4(0.015, 0.075, 0.085, 1.0);
uniform vec4 line_color : source_color = vec4(0.30, 0.86, 0.82, 1.0);
uniform float sweep_speed = 0.9;
uniform float ring_gap = 24.0;
uniform float grid_gap = 12.0;

void fragment() {
	vec2 px = floor(UV * rect_size);
	vec2 centre = floor(rect_size * 0.5);
	vec2 d = px - centre;
	float dist = length(d);
	vec3 col = base_color.rgb;

	float grid = (mod(px.x, grid_gap) < 1.0 || mod(px.y, grid_gap) < 1.0) ? 0.06 : 0.0;
	float ring = abs(mod(dist, ring_gap) - 0.5) < 0.6 ? 0.10 : 0.0;
	float cross = (abs(d.x) < 0.6 || abs(d.y) < 0.6) ? 0.10 : 0.0;
	col += line_color.rgb * (grid + ring + cross);

	float sweep = TIME * sweep_speed;
	float diff = mod(sweep - atan(d.y, d.x), TAU);
	float trail = floor(exp(-diff * 1.5) * 6.0) / 6.0 * 0.30;
	float head = diff < 0.035 ? 0.35 : 0.0;
	col += line_color.rgb * (trail + head);

	if (mod(px.y, 2.0) < 1.0) {
		col *= 0.86;
	}
	col *= 0.97 + 0.03 * sin(TIME * 23.0);

	vec2 edge = min(px, rect_size - px - 1.0);
	col *= 0.78 + 0.22 * clamp(min(edge.x, edge.y) / 10.0, 0.0, 1.0);

	float bx = min(px.x, rect_size.x - 1.0 - px.x);
	float by = min(px.y, rect_size.y - 1.0 - px.y);
	if ((bx < 1.0 && by < 7.0) || (by < 1.0 && bx < 7.0)) {
		col = line_color.rgb;
	}
	COLOR = vec4(col, 1.0);
}
