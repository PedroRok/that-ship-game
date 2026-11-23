shader_type canvas_item;

group_uniforms Properties;
uniform bool enabled : instance_index(0) = true;
uniform sampler2D reference_texture;
uniform float shadow_size: hint_range(0.001, 0.15) = 0.01;
uniform bool down_light = true;
uniform bool invert_top_to_bottom = false;
group_uniforms Colors;
uniform vec4 base_gray: source_color = vec4(0.7, 0.7, 0.7, 1.0);
uniform vec4 shadow_gray: source_color = vec4(0.4, 0.4, 0.4, 1.0);
uniform vec4 darker_shadow_gray: source_color = vec4(0.33, 0.33, 0.33, 1.0);
uniform vec4 light_color: source_color = vec4(0.4825, 0.4825, 0.4825, 1.0);
group_uniforms ProgressBar;
uniform float progress_bar : hint_range(0.0, 1.0);
uniform vec4 progress_bar_color : source_color = vec4(0.4825, 0.4825, 0.4825, 1.0);
uniform bool progress_matched_only = false;

vec4 manage_progress_bar(vec2 uv, vec4 color) {
	if (uv.y > (1.0 - progress_bar)) {
		return vec4(mix(color.rgb, progress_bar_color.rgb, progress_bar_color.a), color.a);
	}
	return color;
}

void fragment() {
	if (enabled) {
	    vec2 uv = UV;
		float final_shadow_size = shadow_size;
		if (invert_top_to_bottom) {
			final_shadow_size = shadow_size * -1.;
		}
	    vec2 uv_above = uv + vec2(0.0, -final_shadow_size);
	    vec2 uv_above_2 = uv + vec2(0.0, -final_shadow_size * 2.0);
	    vec2 uv_below = uv + vec2(0.0, final_shadow_size);
	    
	    vec4 current_color = texture(TEXTURE, uv);
	    vec4 reference_color = texture(reference_texture, uv);
		vec4 reference_color_above = texture(reference_texture, uv_above);
		vec4 reference_color_above_2 = texture(reference_texture, uv_above_2);
		vec4 reference_color_below = texture(reference_texture, uv_below);
	    vec4 color_above = texture(TEXTURE, uv_above);
	    vec4 color_above_2 = texture(TEXTURE, uv_above_2);
	    vec4 color_below = texture(TEXTURE, uv_below);
	    
	    if (reference_color.a > 0.1) {
	        float threshold = 0.5;
	        bool matches_reference = 
	            length(current_color.rgb - reference_color.rgb) < threshold
				&&
				length(color_above.rgb - reference_color_above.rgb) < threshold
				&&
				length(color_above_2.rgb - reference_color_above_2.rgb) < threshold
				&&
				length(color_below.rgb - reference_color_below.rgb) < threshold;
	        
	        if (matches_reference) {
				bool current_above = false;
				bool current_above_2 = false;
	            if (color_above.a < 0.1) {
	                COLOR = vec4(shadow_gray.rgb, current_color.a);
					current_above = true;
	            } else if (color_above_2.a < 0.1) {
	                COLOR = vec4(darker_shadow_gray.rgb, current_color.a);
					current_above_2 = true;
	            } else {
	                COLOR = vec4(base_gray.rgb, current_color.a);
	            }
	            
	            if (color_below.a < 0.1 && !current_above && down_light) {
	                COLOR = vec4(light_color.rgb, current_color.a);
	            }
	        }
			if (!progress_matched_only || matches_reference) {
				COLOR = manage_progress_bar(uv, COLOR);
			}
	    }
	}
}

