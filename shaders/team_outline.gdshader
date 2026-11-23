shader_type canvas_item;


uniform vec4 outline_color : source_color = vec4(1.0, 0.25, 0.25, 0.6);
uniform int thickness = 1;

float texel_alpha(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(tex, uv).a;
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec2 uv = (floor(UV / px) + 0.5) * px;
	float own = texel_alpha(TEXTURE, uv);
	float edge = 0.0;
	for (int x = -thickness; x <= thickness; x++) {
		for (int y = -thickness; y <= thickness; y++) {
			edge = max(edge, texel_alpha(TEXTURE, uv + vec2(float(x), float(y)) * px));
		}
	}
	if (own < 0.5 && edge > 0.5) {
		COLOR = vec4(outline_color.rgb, outline_color.a);
	} else {
		COLOR = vec4(0.0);
	}
}
