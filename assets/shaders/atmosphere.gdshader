shader_type canvas_item;
// خلفية أجواء ليلية إجرائية: تدرّج + قمر + ضباب + تعتيم حواف.
// إجرائية لا صورة: حادّة على أي دقة، وحجمها صفر، وتعمل على Mobile renderer.

uniform vec4 sky_top   : source_color = vec4(0.027, 0.031, 0.051, 1.0);
uniform vec4 sky_low   : source_color = vec4(0.071, 0.055, 0.067, 1.0);
uniform vec4 moon_tint : source_color = vec4(0.812, 0.878, 0.949, 1.0);
uniform vec4 blood     : source_color = vec4(0.698, 0.071, 0.122, 1.0);
uniform vec2 moon_pos = vec2(0.27, 0.26);
uniform float moon_size = 0.055;
uniform float fog_amount : hint_range(0.0, 1.0) = 0.45;
uniform float vignette_amount : hint_range(0.0, 2.0) = 1.15;
uniform float blood_glow : hint_range(0.0, 1.0) = 0.22;
uniform float time_scale = 0.03;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * noise(p);
		p *= 2.03;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * time_scale;

	// تدرّج السماء
	vec3 col = mix(sky_top.rgb, sky_low.rgb, smoothstep(0.0, 1.0, uv.y));

	// القمر: قرص + هالة
	float aspect = 1.0;
	vec2 d = uv - moon_pos;
	d.x *= aspect;
	float dist = length(d);
	float disc = smoothstep(moon_size, moon_size * 0.82, dist);
	float halo = pow(max(0.0, 1.0 - dist / (moon_size * 7.0)), 3.0);
	col += moon_tint.rgb * (disc * 0.85 + halo * 0.33);

	// ضباب متحرك
	float f = fbm(uv * vec2(3.2, 2.0) + vec2(t, t * 0.6));
	float band = smoothstep(0.25, 0.95, uv.y);
	col = mix(col, col + vec3(0.09, 0.10, 0.12), f * fog_amount * band);

	// توهج دموي من الأسفل
	float up = smoothstep(1.0, 0.45, uv.y);
	col += blood.rgb * up * blood_glow * (0.55 + 0.45 * fbm(uv * 4.0 - vec2(0.0, t * 2.0)));

	// تعتيم الحواف
	vec2 vg = uv - 0.5;
	float v = 1.0 - dot(vg, vg) * vignette_amount;
	col *= clamp(v, 0.0, 1.0);

	COLOR = vec4(col, 1.0);
}
