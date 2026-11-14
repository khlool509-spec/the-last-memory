shader_type canvas_item;
// مشهد ليلي إجرائي كامل: قمر وسحب وغابة بثلاث طبقات وقصر بنوافذ
// مضيئة ومطر وضباب. كله محسوب لا مرسوم: حادّ على أي دقة، حجمه صفر،
// ويعمل على Mobile renderer الذي لا يدعم الضباب الحجمي.

uniform vec4 sky_high  : source_color = vec4(0.035, 0.043, 0.075, 1.0);
uniform vec4 sky_low   : source_color = vec4(0.094, 0.063, 0.078, 1.0);
uniform vec4 moon_tint : source_color = vec4(0.878, 0.918, 0.973, 1.0);
uniform vec4 blood     : source_color = vec4(0.698, 0.071, 0.122, 1.0);
uniform vec4 window_lit: source_color = vec4(1.0, 0.584, 0.231, 1.0);

uniform vec2  moon_pos      = vec2(0.30, 0.24);
uniform float moon_size     = 0.062;
uniform float fog_amount    : hint_range(0.0, 1.0) = 0.55;
uniform float rain_amount   : hint_range(0.0, 1.0) = 0.40;
uniform float blood_glow    : hint_range(0.0, 1.0) = 0.18;
uniform float vignette_amount : hint_range(0.0, 2.0) = 1.25;
uniform float wind_speed    = 0.012;
uniform float aspect        = 2.1;

float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float hash1(float x){ return fract(sin(x * 91.3458) * 47453.5453); }

float noise(vec2 p){
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1,0)), f.x),
	           mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), f.x), f.y);
}

float fbm(vec2 p){
	float v = 0.0, a = 0.5;
	for(int i = 0; i < 5; i++){ v += a * noise(p); p *= 2.07; a *= 0.5; }
	return v;
}

// صنوبر ضيّق مدبّب بجذع — لا مثلثات عريضة تشبه الجبال
float treeline(vec2 uv, float density, float height, float base, float seed){
	float x = uv.x * density;
	float cell = floor(x);
	float t = fract(x);
	float h = base + height * (0.55 + 0.45 * hash1(cell + seed));
	float crown = h * pow(max(1.0 - abs(t - 0.5) * 2.0, 0.0), 0.30);
	crown += 0.006 * noise(vec2(x * 14.0, seed));
	float trunk = step(abs(t - 0.5), 0.035) * base * 0.9;
	return max(step(uv.y, crown), step(uv.y, trunk));
}

// نقاط دائرية ناعمة لا مربعات
float stars(vec2 uv){
	vec2 g = uv * vec2(170.0, 80.0);
	vec2 i = floor(g);
	float r = hash(i);
	float on = step(0.990, r);
	vec2 c = vec2(0.25 + 0.5 * hash1(i.x * 1.7 + i.y), 0.25 + 0.5 * hash1(i.y * 2.3 + i.x));
	float d = length(fract(g) - c);
	float point = pow(max(1.0 - d / 0.28, 0.0), 2.5);
	float tw = 0.55 + 0.45 * hash1(i.x + i.y * 3.1);
	return on * point * tw * smoothstep(0.26, 0.9, uv.y);
}

// قصر يعلو خط الأشجار: جسم وسقف وبرج، والنوافذ داخل الجسم فقط
const float MX = 0.625;
const float MBASE = 0.135;
const float MTOP = 0.40;
const float MHW = 0.078;

float mansion(vec2 uv, out float windows){
	windows = 0.0;
	float px = uv.x - MX;
	float body = step(abs(px), MHW) * step(MBASE, uv.y) * step(uv.y, MTOP);
	float rh = 0.085;
	float roof = step(abs(px), max(MHW * (1.0 - (uv.y - MTOP) / rh), 0.0))
	           * step(MTOP, uv.y) * step(uv.y, MTOP + rh);
	float tw = 0.026;
	float tx = MHW * 0.72;
	float tower = step(abs(px - tx), tw) * step(MBASE, uv.y) * step(uv.y, MTOP + 0.10);
	float spire = step(abs(px - tx), max(tw * (1.0 - (uv.y - MTOP - 0.10) / 0.06), 0.0))
	            * step(MTOP + 0.10, uv.y) * step(uv.y, MTOP + 0.16);
	float m = clamp(body + roof + tower + spire, 0.0, 1.0);

	vec2 g = vec2((px + MHW) / (2.0 * MHW) * 5.0, (uv.y - MBASE) / (MTOP - MBASE) * 4.0);
	vec2 gi = floor(g);
	vec2 gf = fract(g);
	float cell = step(0.30, gf.x) * step(gf.x, 0.70) * step(0.25, gf.y) * step(gf.y, 0.72);
	float lit = step(0.42, hash(gi + vec2(3.7, 1.3)));
	windows = body * cell * lit;
	return m;
}

// خطوط مطر مائلة ممتدة لا نقاط
float rain(vec2 uv, float t){
	float px = uv.x * 210.0 + uv.y * 26.0;
	float py = uv.y * 9.0 - t * 5.2;
	float col = floor(px);
	float seed = hash1(col);
	float f = fract(py + seed);
	float active = step(0.90, fract(seed * 7.3));
	float across = 1.0 - smoothstep(0.0, 0.55, abs(fract(px) - 0.5) * 2.0);
	return active * across * pow(max(1.0 - f, 0.0), 2.2);
}

void fragment(){
	vec2 uv = vec2(UV.x, 1.0 - UV.y);   // y لأعلى
	float t = TIME;

	// 1) السماء
	vec3 col = mix(sky_low.rgb, sky_high.rgb, smoothstep(0.0, 1.0, uv.y));

	// 2) القمر وهالته
	vec2 d = (uv - vec2(moon_pos.x, 1.0 - moon_pos.y)) * vec2(aspect, 1.0);
	float dist = length(d);
	float cloud_cover = fbm(uv * vec2(2.4, 1.6) + vec2(t * wind_speed, 0.0));
	float occl = 1.0 - smoothstep(0.42, 0.72, cloud_cover) * 0.55;
	col += moon_tint.rgb * smoothstep(moon_size, moon_size * 0.80, dist) * 0.95 * occl;
	col += moon_tint.rgb * pow(max(0.0, 1.0 - dist / (moon_size * 9.0)), 2.6) * 0.30 * occl;

	col += vec3(0.85, 0.90, 1.0) * stars(uv) * 0.55 * occl;

	// 3) سحب
	float cl = smoothstep(0.40, 0.78, cloud_cover) * smoothstep(0.25, 0.95, uv.y);
	col = mix(col, col + vec3(0.055, 0.058, 0.075), cl * 0.85);

	// 4) القصر خلف الأشجار
	float win;
	float m = mansion(uv, win);
	col = mix(col, vec3(0.022, 0.024, 0.034), m * 0.96);
	float flick = 0.82 + 0.18 * noise(vec2(t * 1.6, 0.0));
	col += window_lit.rgb * win * 0.85 * flick;
	// وهج دافئ حول القصر
	col += window_lit.rgb * m * 0.05;

	// 5) ثلاث طبقات أشجار بعمق متدرّج
	float far  = treeline(uv + vec2(t * wind_speed * 0.15, 0.0), 46.0, 0.085, 0.105, 1.0);
	float mid  = treeline(uv + vec2(-t * wind_speed * 0.25, 0.0), 27.0, 0.135, 0.085, 7.0);
	float near = treeline(uv + vec2(t * wind_speed * 0.4, 0.0), 16.0, 0.215, 0.060, 13.0);
	col = mix(col, vec3(0.040, 0.043, 0.058), far  * 0.82);
	col = mix(col, vec3(0.023, 0.024, 0.035), mid  * 0.91);
	col = mix(col, vec3(0.007, 0.007, 0.013), near * 0.98);

	// 6) ضباب أرضي
	float ground_fog = smoothstep(0.42, 0.0, uv.y) * (0.45 + 0.55 * fbm(uv * vec2(3.4, 5.0) + vec2(t * 0.02, 0.0)));
	col = mix(col, vec3(0.105, 0.115, 0.140), ground_fog * fog_amount);

	// 7) توهج دموي سفلي
	col += blood.rgb * smoothstep(0.35, 0.0, uv.y) * blood_glow;

	// 8) مطر
	col += vec3(0.62, 0.68, 0.80) * rain(uv, t) * rain_amount * 0.55;

	// 9) تعتيم الحواف
	vec2 vg = UV - 0.5;
	col *= clamp(1.0 - dot(vg, vg) * vignette_amount, 0.0, 1.0);

	COLOR = vec4(col, 1.0);
}
