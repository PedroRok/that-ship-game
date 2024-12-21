shader_type canvas_item;

uniform vec3 wave_color: source_color = vec3(0.3, 0.2, 0.8); // Color of the wave
uniform vec3 edge_color: source_color = vec3(1.0, 1.0, 1.0); // Color of the edge
uniform sampler2D wave_texture : hint_default_black;         // Texture for the wave
uniform float wave_opacity: hint_range(0.0, 1.0) = 0.8;      // Opacity of the wave
uniform float edge_width: hint_range(0.0, 0.1) = 0.01;       // Thickness of the edge
uniform float texture_blend: hint_range(0.0, 1.0) = 0.5;     // Blend factor for the texture
uniform float speed: hint_range(0.1, 3.0) = 1.0;             // Speed of wave motion

float get_particle_x(int i) {
    return (sin(float(i)) * 0.5) * (sin(float(i) * 6.0) + 0.5) * 1.75 + 0.5;
}

float get_random(vec2 input) {
	return fract(sin(dot(input, vec2(12.25, 10.356))*23.12) * 1054.52);
}


void fragment() {
    // Transparent background
    vec4 col = vec4(0.0, 0.0, 0.0, 0.0);
    // Smooth wave animation
    float sine_3 = sin(UV.x * 12.0 + (TIME * 0.9 * speed)) * 0.005;
    float wave_height = 0.55 + sine_3;

    // Determine the wave and edge areas
    float edge_mask = smoothstep(wave_height - edge_width * 0.2, wave_height, UV.y);
    float wave_mask = smoothstep(wave_height, wave_height + edge_width * 0.9, UV.y);

    // Apply edge color
    col.rgb = mix(col.rgb, edge_color, edge_mask);

    // Apply wave color
    col.rgb = mix(col.rgb, wave_color, wave_mask);

    // Add alpha for non-background areas
    col.a = max(edge_mask, wave_mask) * wave_opacity;

    // Apply static texture to the wave mask
    vec2 texture_coords = vec2(UV.x, UV.y); // Static texture without TIME offset
    vec4 texture_color = texture(wave_texture, texture_coords);

    // Blend texture with the wave
    col.rgb = mix(col.rgb, texture_color.rgb, texture_blend * wave_mask);

	col.rgb = col.rgb / texture_coords.y / sin((texture_coords.y * 1.8) -0.55);

    COLOR = col;
}
