shader_type sky;

// سماء بتدرّج حقيقي: أفق دافئ يتدرّج إلى عمق السمت، قرص شمس بهالة،
// ضباب أفقي يفصل الأرض عن السماء، وسُحب طبقتين تتحركان ببطء.

uniform vec3 top_color : source_color = vec3(0.09, 0.20, 0.42);
uniform vec3 horizon_color : source_color = vec3(0.62, 0.70, 0.78);
uniform vec3 ground_color : source_color = vec3(0.10, 0.11, 0.12);
uniform vec3 sun_color : source_color = vec3(1.0, 0.92, 0.78);
uniform float sun_size : hint_range(0.0, 0.2) = 0.018;
uniform float sun_glow : hint_range(0.0, 8.0) = 2.6;
uniform float sun_energy : hint_range(0.0, 20.0) = 7.0;
uniform float horizon_sharp : hint_range(0.5, 12.0) = 3.0;
uniform float cloud_amount : hint_range(0.0, 1.0) = 0.42;
uniform float cloud_speed = 0.004;
uniform vec3 cloud_color : source_color = vec3(1.0, 0.96, 0.90);
uniform vec3 cloud_shadow : source_color = vec3(0.42, 0.45, 0.52);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
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
	for (int i = 0; i < 5; i++) {
		v += vnoise(p) * amp;
		p *= 2.03;
		amp *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = EYEDIR;
	float up = dir.y;

	// تدرّج رأسي: الأفق يذوب في السمت بأسّ قابل للضبط
	float t = pow(clamp(up, 0.0, 1.0), 1.0 / horizon_sharp);
	vec3 col = mix(horizon_color, top_color, t);
	// تحت الأفق: لون الأرض البعيدة
	col = mix(col, ground_color, smoothstep(0.0, -0.12, up));

	// الشمس: قرص حادّ داخل هالة واسعة
	float sd = dot(dir, LIGHT0_DIRECTION);
	float disc = smoothstep(1.0 - sun_size, 1.0 - sun_size * 0.35, sd);
	float glow = pow(max(sd, 0.0), 1.0 + sun_glow * 14.0);
	col += sun_color * glow * 0.55;
	col += sun_color * disc * sun_energy;

	// سُحب: طبقتان بسرعتين فتبدو ذات عمق
	if (up > 0.0) {
		vec2 sky_uv = dir.xz / max(up + 0.14, 0.02);
		float drift = TIME * cloud_speed;
		float c1 = fbm(sky_uv * 0.55 + vec2(drift, drift * 0.3));
		float c2 = fbm(sky_uv * 1.35 + vec2(-drift * 1.7, drift * 0.8));
		float c = c1 * 0.65 + c2 * 0.35;
		float cover = smoothstep(0.58 - cloud_amount * 0.34, 0.78, c);
		// إضاءة السحابة من جهة الشمس
		float lit = clamp(sd * 0.5 + 0.5, 0.0, 1.0);
		vec3 cc = mix(cloud_shadow, cloud_color, pow(lit, 1.6));
		cc += sun_color * pow(max(sd, 0.0), 8.0) * 0.6;
		float fade = smoothstep(0.0, 0.22, up);
		col = mix(col, cc, cover * fade * 0.92);
	}

	COLOR = col;
}
