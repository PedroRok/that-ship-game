shader_type canvas_item;

uniform bool enable:instance_index(0);
uniform bool bold:instance_index(0);
uniform vec4 outline_color:source_color;
uniform float opacity = 100;

vec4 apply_outline_if_needed(sampler2D texture, vec2 uv, vec2 pixel_size, vec2 pixel_offset) {
    if (texture(texture, uv + (pixel_offset * pixel_size)).a > 0.0) {
        vec4 resulting_color = outline_color;
        resulting_color.a = 1.0;
        return resulting_color;
    }
    return vec4(0.0);
}

void fragment() {
	vec4 color = COLOR;
    if (enable) 
    {
        float pixel_size_x = 1.0 / float(textureSize(TEXTURE, 0).x);
        float pixel_size_y = 1.0 / float(textureSize(TEXTURE, 0).y);
        vec2 pixel_size = vec2(pixel_size_x, pixel_size_y);
        
        if (texture(TEXTURE, UV).a == 0.0)
        { 
            for (int x = -1; x <= 1; x++)
            {
                for (int y = -1; y <= 1; y++)
                {
					
					vec4 outline_result;
					if (bold) {
                    	vec2 pixel_offset = vec2(float(x), float(y));
                    	outline_result = apply_outline_if_needed(TEXTURE, UV, pixel_size, pixel_offset);
					} else {
						vec2 pixel_offset = vec2(float(x), float(0));
						outline_result = apply_outline_if_needed(TEXTURE, UV, pixel_size, pixel_offset);
						vec2 pixel_offset_2 = vec2(float(0), float(y));
						vec4 outline_result_2 = apply_outline_if_needed(TEXTURE, UV, pixel_size, pixel_offset_2);
						outline_result = outline_result + outline_result_2;
					}
                    
                    if (outline_result.a > 0.0) {
                        COLOR = outline_result;
                    }
                }
            }
        }
        else
        {
            COLOR = texture(TEXTURE, UV);
        }
    }
	COLOR.a = (COLOR.a/100.0) * opacity;
	if (color.a > 0.1) {
		COLOR = color;
	}
}
