shader_type particles;
render_mode disable_velocity, disable_force, keep_data;

uniform vec2 wind = vec2(-8.0, 0.0);
uniform float open_rate = 14.0;
uniform float swell_share = 0.45;
uniform float swell_seconds = 4.0;
uniform float churn = 0.0;
uniform float gravity = 0.0;
uniform float foam_gravity = 1.0;
uniform bool seeded_alpha = false;
uniform float top = -100000.0;
uniform float bottom = 100000.0;

float opened(float t) {
	return (1.0 - exp(-open_rate * t)) * (1.0 + swell_share * t / swell_seconds);
}

void process() {
	float pull = min(min(COLOR.r, COLOR.g), COLOR.b) > 0.9 ? gravity * foam_gravity : gravity;
	float before = CUSTOM.x;
	float now = before + DELTA;
	CUSTOM.x = now;
	float phase = CUSTOM.z * 977.0;
	vec2 swirl = vec2(sin(now * 1.3 + phase), cos(now * 1.1 + phase)) * churn * DELTA;
	vec2 step_move = VELOCITY.xy * (opened(now) - opened(before)) + wind * DELTA + swirl
			+ vec2(0.0, 0.5 * pull * (now * now - before * before));
	TRANSFORM[3].xy += step_move;
	COLOR.a = 1.0 - clamp((now - CUSTOM.y) / max(CUSTOM.w - CUSTOM.y, 0.001), 0.0, 1.0);
	if (seeded_alpha) {
		COLOR.a *= CUSTOM.z;
	}
	if (TRANSFORM[3].y < top || TRANSFORM[3].y > bottom) {
		COLOR.a = 0.0;
	}
	if (now >= CUSTOM.w) {
		ACTIVE = false;
	}
}
