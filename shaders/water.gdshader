shader_type canvas_item;

uniform vec3 wave_color: source_color = vec3(0.3, 0.2, 0.8);
uniform vec3 edge_color: source_color = vec3(1.0, 1.0, 1.0);
uniform sampler2D wave_texture : hint_default_black;
uniform float wave_opacity: hint_range(0.0, 1.0) = 0.8;
uniform float edge_width: hint_range(0.0, 0.1) = 0.01;
uniform float texture_blend: hint_range(0.0, 1.0) = 0.5;
uniform float speed: hint_range(0.1, 3.0) = 1.0;

float get_particle_x(int i) {
    return (sin(float(i)) * 0.5) * (sin(float(i) * 6.0) + 0.5) * 1.75 + 0.5;
}

float get_random(vec2 input) {
	return fract(sin(dot(input, vec2(12.25, 10.356))*23.12) * 1054.52);
}


void fragment() {
    vec4 col = vec4(0.0, 0.0, 0.0, 0.0);
    float sine_3 = sin(UV.x * 12.0 + (TIME * 0.9 * speed)) * 0.005;
    float wave_height = 0.55 + sine_3;

    float edge_mask = smoothstep(wave_height - edge_width * 0.2, wave_height, UV.y);
    float wave_mask = smoothstep(wave_height, wave_height + edge_width * 0.9, UV.y);

    col.rgb = mix(col.rgb, edge_color, edge_mask);

    col.rgb = mix(col.rgb, wave_color, wave_mask);

    col.a = max(edge_mask, wave_mask) * wave_opacity;

    vec2 texture_coords = vec2(UV.x, UV.y);
    vec4 texture_color = texture(wave_texture, texture_coords);

    col.rgb = mix(col.rgb, texture_color.rgb, texture_blend * wave_mask);

	col.rgb = col.rgb / texture_coords.y / sin((texture_coords.y * 1.8) -0.55);

    COLOR = col;
}
