shader_type sky;
render_mode use_quarter_res_pass;

// سماء القمر: فراغ بلا غلاف جوي.
// لا تشتّت ضوئي، لا زرقة، لا تلألؤ — النجوم ثابتة لأن لا هواء يكسر ضوءها.
// كل شيء مرسوم رياضياً: لا صور ولا أصول.

uniform vec3 earth_dir = vec3(0.35, 0.42, -0.84);
uniform float earth_size : hint_range(0.0, 0.3) = 0.085;
uniform vec3 earth_ocean : source_color = vec3(0.09, 0.22, 0.46);
uniform vec3 earth_land : source_color = vec3(0.26, 0.31, 0.19);
uniform vec3 earth_cloud : source_color = vec3(0.92, 0.94, 0.97);
uniform float earth_phase : hint_range(-1.0, 1.0) = 0.35;

uniform vec3 sun_dir = vec3(0.62, 0.55, 0.56);
uniform float sun_size : hint_range(0.0, 0.1) = 0.018;
uniform float star_density : hint_range(0.0, 1.0) = 0.55;
uniform float milky_way : hint_range(0.0, 1.0) = 0.35;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 hash32(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yxz + 33.33);
	return fract((p3.xxy + p3.yzz) * p3.zyx);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n = i.x + i.y * 57.0 + i.z * 113.0;
	float a = fract(sin(n) * 43758.5453);
	float b = fract(sin(n + 1.0) * 43758.5453);
	float c = fract(sin(n + 57.0) * 43758.5453);
	float d = fract(sin(n + 58.0) * 43758.5453);
	float e = fract(sin(n + 113.0) * 43758.5453);
	float g = fract(sin(n + 114.0) * 43758.5453);
	float h = fract(sin(n + 170.0) * 43758.5453);
	float k = fract(sin(n + 171.0) * 43758.5453);
	float x1 = mix(a, b, f.x);
	float x2 = mix(c, d, f.x);
	float x3 = mix(e, g, f.x);
	float x4 = mix(h, k, f.x);
	return mix(mix(x1, x2, f.y), mix(x3, x4, f.y), f.z);
}

float fbm3(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise3(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

// طبقة نجوم: الشبكة تُسقط على وجه المكعب الأقرب فلا تتكدّس عند القطبين
vec3 star_layer(vec3 dir, float scale, float thresh, float bright) {
	vec3 ad = abs(dir);
	vec2 uv;
	if (ad.x >= ad.y && ad.x >= ad.z) {
		uv = dir.yz / ad.x;
	} else if (ad.y >= ad.z) {
		uv = dir.xz / ad.y;
	} else {
		uv = dir.xy / ad.z;
	}
	uv = uv * scale;
	vec2 cell = floor(uv);
	vec2 f = fract(uv);
	vec3 h = hash32(cell + vec2(scale * 7.1));
	if (h.z > thresh) {
		return vec3(0.0);
	}
	vec2 star_pos = vec2(h.x, h.y) * 0.7 + 0.15;
	float d = length(f - star_pos);
	float mag = 1.0 - smoothstep(0.0, 0.065, d);
	mag = pow(mag, 7.0);
	// حرارة لونية: من البرتقالي الخافت إلى الأزرق الحار
	float temp = fract(h.z * 31.7);
	vec3 tint = mix(vec3(1.0, 0.78, 0.62), vec3(0.74, 0.84, 1.0), temp);
	tint = mix(tint, vec3(1.0), 0.45);
	return tint * mag * bright * (0.35 + 0.65 * fract(h.x * 17.3));
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 col = vec3(0.0);

	// الفراغ: أسود حقيقي مع وهج مجرّي بالغ الخفوت
	col += vec3(0.004, 0.005, 0.010);

	// درب التبانة: شريط ضبابي مائل
	vec3 band_axis = normalize(vec3(0.42, 0.28, 0.86));
	float band = 1.0 - abs(dot(dir, band_axis));
	band = pow(clamp(band, 0.0, 1.0), 9.0);
	float dust = fbm3(dir * 4.5);
	float dust2 = fbm3(dir * 11.0 + 23.0);
	vec3 mw = mix(vec3(0.16, 0.17, 0.26), vec3(0.28, 0.26, 0.31), dust2);
	col += mw * band * dust * milky_way;

	// ثلاث طبقات نجوم بكثافات ولمعان مختلف
	col += star_layer(dir, 48.0, 0.14 * star_density + 0.02, 1.0);
	col += star_layer(dir, 96.0, 0.20 * star_density + 0.03, 0.55);
	col += star_layer(dir, 190.0, 0.26 * star_density + 0.04, 0.28);

	// الأرض: القرص الوحيد الملوّن في السماء
	vec3 ed = normalize(earth_dir);
	float ec = dot(dir, ed);
	float edge = cos(earth_size);
	if (ec > edge) {
		// إحداثيات داخل القرص
		vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), ed));
		vec3 up = cross(ed, right);
		vec2 disc = vec2(dot(dir, right), dot(dir, up)) / sin(earth_size);
		float r2 = clamp(dot(disc, disc), 0.0, 1.0);
		float z = sqrt(max(0.0, 1.0 - r2));
		vec3 nrm = normalize(right * disc.x + up * disc.y + ed * z);

		// قارات ومحيطات
		float land = fbm3(nrm * 2.6 + 11.0);
		float mask = smoothstep(0.46, 0.56, land);
		vec3 surf = mix(earth_ocean, earth_land, mask);
		// قمم جليدية
		float polar = smoothstep(0.72, 0.95, abs(nrm.y));
		surf = mix(surf, vec3(0.86, 0.90, 0.94), polar * 0.85);
		// سحب
		float cl = fbm3(nrm * 4.2 + 57.0);
		cl = smoothstep(0.48, 0.70, cl);
		surf = mix(surf, earth_cloud, cl * 0.62);

		// طور الإضاءة: نصف مضاء ونصف مظلم
		vec3 lit_dir = normalize(vec3(earth_phase, 0.18, sqrt(max(0.02, 1.0 - earth_phase * earth_phase))));
		float lam = clamp(dot(nrm, lit_dir), 0.0, 1.0);
		float term = smoothstep(0.0, 0.26, lam);
		vec3 night = surf * 0.035 + vec3(0.012, 0.010, 0.006);
		vec3 lit = surf * (0.35 + 0.95 * lam);
		vec3 earth_col = mix(night, lit, term);

		// هالة الغلاف الجوي عند الحافة
		float rim = smoothstep(0.80, 1.0, r2);
		earth_col += vec3(0.20, 0.38, 0.72) * rim * term * 0.75;

		float aa = smoothstep(1.0, 0.985, r2);
		col = mix(col, earth_col, aa);
	}

	// الشمس: قرص صغير قاسٍ بلا هالة جوية تُذكر
	vec3 sd = normalize(sun_dir);
	float sc = dot(dir, sd);
	float sun_edge = cos(sun_size);
	if (sc > sun_edge) {
		col = vec3(14.0, 13.4, 12.6);
	} else {
		// توهج ضئيل جداً: في الفراغ لا يوجد تشتّت، الوهج من العدسة فقط
		float g = pow(max(0.0, sc), 2200.0);
		col += vec3(1.0, 0.95, 0.88) * g * 2.2;
	}

	COLOR = col;
}
