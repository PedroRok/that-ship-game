shader_type canvas_item;

uniform sampler2D noise : filter_nearest, repeat_enable;
uniform float damage = 0.0;
uniform bool per_texel = true;
uniform float base_coverage = 0.28;
uniform float unit_coverage = 0.46;

float chance(vec2 cell) {
	return fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	if (damage > 0.0 && COLOR.a > 0.01) {
		vec2 grid = vec2(textureSize(noise, 0));
		vec2 cell = per_texel ? floor(UV / TEXTURE_PIXEL_SIZE) : floor(UV * grid);
		float value = texture(noise, (cell + 0.5) / grid).r + (chance(cell) - 0.5) * 0.03;
		float hole = 1.0 - (per_texel ? unit_coverage : base_coverage) * damage;
		float ember = per_texel ? 0.07 : 0.025;
		float flicker = chance(cell + floor(TIME * 7.0 + chance(cell) * 7.0));
		if (value > hole) {
			COLOR.rgb = vec3(0.035, 0.025, 0.03);
			if (flicker > 0.93) {
				COLOR.rgb = vec3(0.55, 0.12, 0.03);
			}
		} else if (value > hole - ember) {
			COLOR.rgb = flicker > 0.75 ? vec3(1.0, 0.72, 0.2) : (flicker > 0.3 ? vec3(0.95, 0.36, 0.05) : vec3(0.55, 0.11, 0.03));
		} else if (value > hole - ember - 0.02) {
			COLOR.rgb = chance(cell) > 0.6 ? vec3(0.34, 0.37, 0.41) : vec3(0.09, 0.07, 0.07);
		} else if (value > hole - ember - 0.095) {
			COLOR.rgb *= chance(cell) > 0.5 ? 0.45 : 0.65;
		}
	}
}
