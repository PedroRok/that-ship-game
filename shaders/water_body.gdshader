shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture;
uniform vec4 water_color : source_color;
uniform sampler2D wave_noise : repeat_enable;

void fragment() {
	// Called for every pixel the material is visible on.
	vec2 uv = vec2(SCREEN_UV.x , SCREEN_UV.y - UV.y);
	vec4 color = texture(screen_texture, uv);
	float mix_value = 1.0 - UV.y;
	COLOR = mix(water_color, color, mix_value);
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
