shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.37, 0.85, 0.81, 1.0);
varying float fade;

void vertex() {
	fade = COLOR.a;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(tint.rgb * (0.55 + 0.9 * l), c.a * fade);
}
