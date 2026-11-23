shader_type canvas_item;

uniform vec4 overlay_color: source_color = vec4(0.7, 0.7, 0.7, 1.0);

void fragment() {
	if (COLOR.a > 0.0) {
		COLOR = mix(COLOR, overlay_color, overlay_color.a);
	}
}

