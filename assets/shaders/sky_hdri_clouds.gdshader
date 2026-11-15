shader_type sky;

// سماء حيّة: كرة HDRI مصوّرة تحمل الإضاءة والعمق، وفوقها طبقتا
// غيوم متحرّكتان تُضيئهما الشمس نفسها.
//
// لماذا لا غيوم حجمية: كلفتها على الجوال لا تُحتمَل. ولماذا لا
// HDRI وحدها: ساكنة فتموت السماء. الحلّ المهني للجوال هو طبقات
// مُسقَطة على قبّة، بسرعات واتجاهات مختلفة، مع إضاءة من اتجاه
// الشمس — فتُقرأ حركةً وعمقاً بكلفة شادر واحد.
//
// خريطة الإشعاع (الإضاءة المحيطة) تُبنى مرّة واحدة من هذه السماء،
// والزمن لا يُوسّخها، فحركة الغيوم لا تكلّف إعادة بناء.

uniform float anim_time = -1.0;   // ≥0 يستبدل TIME للالتقاط
uniform sampler2D panorama : source_color, filter_linear;
uniform float pano_energy : hint_range(0.0, 8.0) = 1.18;
uniform float pano_yaw : hint_range(0.0, 6.2832) = 0.0;

uniform vec3 sun_color : source_color = vec3(1.0, 0.97, 0.92);
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.99, 0.975);
uniform vec3 cloud_dark : source_color = vec3(0.34, 0.40, 0.52);
uniform float cloud_amount : hint_range(0.0, 1.0) = 0.54;
uniform float cloud_sharp : hint_range(0.5, 8.0) = 4.2;
uniform float layer1_scale = 2.6;
uniform float layer2_scale = 6.2;
uniform vec2 layer1_wind = vec2(0.0085, 0.0032);
uniform vec2 layer2_wind = vec2(-0.0051, 0.0074);
uniform float layer2_mix : hint_range(0.0, 1.0) = 0.42;
uniform float horizon_hide : hint_range(0.0, 0.6) = 0.07;  // تحت هذا الارتفاع لا غيوم

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += vnoise(p) * a;
		p = p * 2.07 + vec2(13.1, 7.3);
		a *= 0.5;
	}
	return v;
}

// إسقاط القبّة: الاتجاه يُسقَط على مستوٍ أفقي على ارتفاع ثابت،
// فتتباعد الغيوم عند الأفق وتقترب فوق الرأس — منظور حقيقي.
vec2 dome_uv(vec3 dir, float height) {
	float y = max(dir.y, 0.045);
	return dir.xz / y * height;
}

float t_now() {
	return anim_time >= 0.0 ? anim_time : TIME;
}

void sky() {
	vec3 dir = EYEDIR;

	// الكرة المصوّرة بإحداثيات متساوية المستطيلات
	float yaw = atan(dir.x, dir.z) + pano_yaw;
	float pitch = asin(clamp(dir.y, -1.0, 1.0));
	vec2 puv = vec2(fract(yaw / (2.0 * PI) + 0.5), 0.5 - pitch / PI);
	vec3 base = texture(panorama, puv).rgb * pano_energy;

	if (dir.y <= horizon_hide) {
		COLOR = base;
	} else {
		// طبقتان بسرعتين واتجاهين مختلفين: الفرق يكسر التكرار
		vec2 u1 = dome_uv(dir, layer1_scale) + layer1_wind * t_now();
		vec2 u2 = dome_uv(dir, layer2_scale) + layer2_wind * t_now();
		float c1 = fbm(u1);
		float c2 = fbm(u2 + vec2(31.7, 11.3));
		float c = mix(c1, c2, layer2_mix);

		// كثافة تتغيّر ببطء شديد: الغيوم تتجمّع وتتفرّق
		float drift = fbm(dome_uv(dir, 0.7) + vec2(t_now() * 0.0016, t_now() * 0.0011));
		float amount = cloud_amount * (0.72 + drift * 0.56);

		float cov = smoothstep(1.0 - amount, 1.0 - amount + 0.42 / cloud_sharp, c);
		// الخفوت عند الأفق يمنع مدّ الغيوم إلى ما لا نهاية
		cov *= smoothstep(horizon_hide, horizon_hide + 0.16, dir.y);

		// الإضاءة: الوجه المقابل للشمس مضيء والقاع مظلم.
		// الفرق بين عيّنتين متجاورتين نحو الشمس يعطي ميل السطح.
		vec2 toward = normalize(LIGHT0_DIRECTION.xz + vec2(0.0001)) * 0.09;
		float c_up = fbm(u1 + toward);
		float lit = clamp((c1 - c_up) * 3.4 + 0.5, 0.0, 1.0);
		float sun_face = clamp(dot(normalize(dir), LIGHT0_DIRECTION) * 0.5 + 0.5, 0.0, 1.0);
		vec3 cl = mix(cloud_dark, cloud_lit, lit);
		cl = mix(cl, cl * sun_color * 1.18, sun_face * 0.55);

		COLOR = mix(base, cl, cov);
	}
}
