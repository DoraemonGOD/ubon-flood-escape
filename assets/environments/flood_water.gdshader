shader_type canvas_item;
// Animated floodwater around the house: slow murky swell, light streaks and
// rain-drop ripples. Uses world position so any polygon size tiles seamlessly.

uniform vec4 deep_color : source_color = vec4(0.157, 0.341, 0.329, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.267, 0.49, 0.455, 1.0);
uniform vec4 light_color : source_color = vec4(0.66, 0.8, 0.74, 1.0);
uniform float wave_scale = 0.011;
uniform float ripple_cell = 56.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float swell(vec2 p, float t) {
	return 0.5 * sin(p.x * 1.3 + t * 0.9 + sin(p.y * 0.9 + t * 0.6) * 1.5)
		+ 0.5 * sin(p.y * 2.1 - t * 0.7 + p.x * 0.4);
}

float hash(vec2 c) {
	return fract(sin(dot(c, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 p = world_pos * wave_scale;
	float t = TIME;
	float w = swell(p, t);
	float n = swell(p * 2.3 + vec2(4.0, 1.0), t * 1.3);
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, 0.5 + 0.3 * w);

	float streak = smoothstep(0.88, 0.98, 0.5 + 0.5 * sin(p.x * 3.0 + n * 1.6 + t * 0.5));
	streak *= smoothstep(0.3, 0.9, 0.5 + 0.5 * sin(p.y * 7.0 + t));
	col = mix(col, light_color.rgb, streak * 0.35);

	vec2 cell = floor(world_pos / ripple_cell);
	vec2 local = fract(world_pos / ripple_cell) - 0.5;
	float h = hash(cell);
	float phase = fract(t * 0.6 + h);
	float d = length(local * vec2(1.0, 1.7));
	float ring = smoothstep(0.035, 0.0, abs(d - phase * 0.42)) * (1.0 - phase) * step(0.35, h);
	col += ring * 0.18;

	COLOR = vec4(col, opacity);
}
