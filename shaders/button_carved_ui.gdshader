shader_type canvas_item;

uniform vec4 base_gray: source_color = vec4(0.7, 0.7, 0.7, 1.0);
uniform vec4 shadow_gray: source_color = vec4(0.4, 0.4, 0.4, 1.0);
uniform sampler2D reference_texture;

void fragment() {
    vec2 uv = UV;
    vec2 uv_above = uv + vec2(0.0, -TEXTURE_PIXEL_SIZE.y);
    vec2 uv_above_2 = uv + vec2(0.0, -TEXTURE_PIXEL_SIZE.y * 2.0);
    vec2 uv_below = uv + vec2(0.0, TEXTURE_PIXEL_SIZE.y);
    
    vec4 current_color = texture(TEXTURE, uv);
    vec4 reference_color = texture(reference_texture, uv);
    vec4 color_above = texture(TEXTURE, uv_above);
    vec4 color_above_2 = texture(TEXTURE, uv_above_2);
    vec4 color_below = texture(TEXTURE, uv_below);
    
    // Só processa se o pixel de referência não for transparente
    if (reference_color.a > 0.1) {
        float threshold = 1.;
        bool matches_reference = 
            length(current_color.rgb - reference_color.rgb) < threshold;
        
        if (matches_reference) {
            if (color_above.a < 0.1) {
                COLOR = vec4(shadow_gray.rgb, current_color.a);
            } else if (color_above_2.a < 0.1) {
                COLOR = vec4(shadow_gray.rgb / 1.2, current_color.a);
            } else {
                COLOR = vec4(base_gray.rgb, current_color.a);
            }
            
            if (color_below.a < 0.1) {
                COLOR = vec4(shadow_gray.rgb / 0.4, current_color.a);
            }
        }
    }
}