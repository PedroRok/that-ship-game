shader_type canvas_item;

uniform vec4 base_gray: source_color = vec4(0.7, 0.7, 0.7, 1.0);
uniform vec4 shadow_gray: source_color = vec4(0.4, 0.4, 0.4, 1.0);

void fragment() {
    vec2 uv = UV;
    vec2 uv_above = uv + vec2(0.0, -TEXTURE_PIXEL_SIZE.y);
    vec2 uv_above_2 = uv + vec2(0.0, -TEXTURE_PIXEL_SIZE.y *2.);
	vec2 uv_bellow = uv + vec2(0.0, TEXTURE_PIXEL_SIZE.y);
	
    
    vec4 color_above = texture(TEXTURE, uv_above);
	vec4 color_above_2 = texture(TEXTURE, uv_above_2);
	vec4 color_bellow = texture(TEXTURE, uv_bellow);
    vec4 current_color = texture(TEXTURE, uv);
    
    if (current_color.r < 0.21) {
        if (color_above.a < 0.1) {
            COLOR = vec4(shadow_gray.rgb, current_color.a);
        } else if (color_above_2.a < 0.1) {
            COLOR = vec4(shadow_gray.rgb /1.2, current_color.a);
		} else {
            COLOR = vec4(base_gray.rgb, current_color.a);
        }
		if (color_bellow.a < 0.1) {
			COLOR = vec4(shadow_gray.rgb /0.4, current_color.a);
		}
    } else {
        // Mantém transparência onde o pixel original era transparente
        //COLOR = vec4(0.0, 0.0, 0.0, 0.0);
    }
}