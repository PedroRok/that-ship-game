shader_type canvas_item;

uniform float build_progress : hint_range(0.0, 1.0) = 0.0;
uniform int block_size : hint_range(1, 10, 1) = 3;

float calculate_block_priority(vec2 block_pos, vec2 total_blocks) {
    float dist_left = length(vec2(block_pos.x, total_blocks.y - block_pos.y - 1.0));
    float dist_right = length(vec2(total_blocks.x - block_pos.x - 1.0, total_blocks.y - block_pos.y - 1.0));
    
    float min_dist = min(dist_left, dist_right);
    
    float height_factor = (total_blocks.y - block_pos.y) / total_blocks.y;
    
    return min_dist + height_factor * total_blocks.y;
}

void fragment() {
    vec2 texture_size = 1.0 / TEXTURE_PIXEL_SIZE;
    
    
    vec2 block_pos = floor(UV * texture_size / float(block_size));
    
    vec2 total_blocks = floor(texture_size / float(block_size));
    float num_blocks = total_blocks.x * total_blocks.y;
    
    float block_priority = calculate_block_priority(block_pos, total_blocks);
    
    float max_priority = calculate_block_priority(vec2(total_blocks.x / 2.0, 0.0), total_blocks);
    
    vec4 texture_color = texture(TEXTURE, UV);
    
    if (block_priority > max_priority * (build_progress + 0.05)) {
        texture_color.a = 0.0;
    }
    
    COLOR = texture_color;
}