shader_type canvas_item;

uniform sampler2D refraction_map;

uniform sampler2D ocean_texture : repeat_enable;

uniform vec2 refraction_stretch = vec2(1.0, 1.0);
uniform float refraction_strength : hint_range(0.0, 0.1) = 0.02;
uniform float speed : hint_range(0.0, 1.0) = 0.1;
uniform float texture_strength : hint_range(0.0, 1.0) = 0.5;

uniform vec4 water_tint : source_color = vec4(0.2, 0.6, 1.0, 0.1);

// Uso na doca submarina: level >= 0 recorta a água pelo nível (0..1) e pela máscara da textura.
uniform float level = -1.0;
uniform float top = 0.2;
uniform float bottom = 0.9;

// Buracos no mar (x0, y0, x1, y1 em coordenadas globais): onde ficam as docas submarinas.
uniform vec4 hole0 = vec4(0.0);
uniform vec4 hole1 = vec4(0.0);

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

varying vec2 globalposition;

void vertex(){
	globalposition = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment()
{
	if (globalposition.x >= hole0.x && globalposition.x < hole0.z && globalposition.y >= hole0.y && globalposition.y < hole0.w) {
		discard;
	}
	if (globalposition.x >= hole1.x && globalposition.x < hole1.z && globalposition.y >= hole1.y && globalposition.y < hole1.w) {
		discard;
	}
	float dock_edge = 0.0;
	if (level >= 0.0) {
		float wave = sin(UV.x * 23.0 + TIME * 1.3) * 0.5 + sin(UV.x * 9.0 - TIME * 0.8 + 1.7) * 0.8 + sin(UV.x * 51.0 + TIME * 2.1) * 0.25;
		float calm = 0.4 + 0.6 * (0.5 + 0.5 * sin(TIME * 0.45));
		float surface = bottom - level * (bottom - top) + wave * calm * 0.004;
		if (level <= 0.001 || UV.y < surface || texture(TEXTURE, UV).a < 0.01) {
			discard;
		}
		dock_edge = 1.0 - smoothstep(0.0, 0.02, UV.y - surface);
	}
	vec2 uv = globalposition / 512.0;
	
	vec2 refraction_offset = texture(
		refraction_map, 
		vec2(
			mod(uv.x * refraction_stretch.x + TIME * speed, 1.0), 
			mod(uv.y * refraction_stretch.y + TIME * speed, 1.0))).xy;
	refraction_offset -= 0.5; 
	
	vec4 ocean_text = texture(ocean_texture, vec2(uv.x * 9. +TIME * speed, uv.y *9. +TIME * speed) + refraction_offset*0.2);
	
	float strength = mix(0.0, 0.3, texture_strength);
	
	ocean_text.rgba = mix(ocean_text.rgba *2.0, vec4(0.0), SCREEN_UV.y + strength);
	if (SCREEN_UV.y> 1.0- strength) {
		ocean_text.rgba *= 0.0;
	}
	
	
	
	vec4 refraction = texture(SCREEN_TEXTURE, SCREEN_UV - refraction_offset * refraction_strength);
	
	vec4 color = vec4(1.0);
	color = mix(vec4(0.0), color, SCREEN_UV.y);
	color.a = 1.0;

	color.rgb = mix(refraction.rgb, water_tint.rgb, water_tint.a);
	float mix_value = 1.0 - (SCREEN_UV.y);
	vec4 color2 = color + ocean_text;
	color2.rgb = color2.rgb * 0.3 * SCREEN_UV.y;
	COLOR = mix(color2, color *1.8, mix_value);
	COLOR.rgb = mix(COLOR.rgb, vec3(0.8, 0.95, 1.0), dock_edge * 0.35);
}