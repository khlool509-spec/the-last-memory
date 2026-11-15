shader_type canvas_item;

// تصحيح عمى الألوان (daltonization) — لا ترشيح لوني سطحي.
//
// الطريقة: تُحوَّل الصورة إلى فضاء LMS (استجابة مخاريط العين
// الثلاثة)، ثم يُحاكى نوع العمى بإسقاط القناة المعطوبة على ما
// يستطيع الشخص رؤيته. الفرق بين الأصل والمحاكاة هو المعلومة
// الضائعة، فتُعاد توزيعها على القنوات السليمة. النتيجة: ما كان
// يختفي يصير مميَّزاً — وهو غرض الوضع، لا تلوين الشاشة.
//
// مصفوفات LMS من Hunt-Pointer-Estevez، ومصفوفات المحاكاة من
// Viénot, Brettel & Mollon (1999).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform int mode = 0;   // 1 أخضر (deuteranopia) · 2 أحمر (protanopia) · 3 أزرق (tritanopia)
uniform float strength : hint_range(0.0, 1.0) = 1.0;

const mat3 RGB_TO_LMS = mat3(
	vec3(0.31399022, 0.15537241, 0.01775239),
	vec3(0.63951294, 0.75789446, 0.10944209),
	vec3(0.04649755, 0.08670142, 0.87256922));

const mat3 LMS_TO_RGB = mat3(
	vec3( 5.47221206, -1.12524190,  0.02980165),
	vec3(-4.64196010,  2.29317094, -0.19318073),
	vec3( 0.16963708, -0.16789520,  1.16364789));

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	if (mode == 0) {
		COLOR = vec4(c, 0.0);
	} else {
		vec3 lms = RGB_TO_LMS * c;
		vec3 sim = lms;
		if (mode == 1) {
			// العجز في المخروط M: يُستعاد من L و S
			sim.y = 0.49421 * lms.x + 0.00000 * lms.y + 1.24827 * lms.z;
		} else if (mode == 2) {
			// العجز في المخروط L
			sim.x = 0.00000 * lms.x + 2.02344 * lms.y - 2.52581 * lms.z;
		} else {
			// العجز في المخروط S
			sim.z = -0.39591 * lms.x + 0.80168 * lms.y + 0.00000 * lms.z;
		}
		vec3 sim_rgb = LMS_TO_RGB * sim;
		// المعلومة الضائعة تُعاد توزيعها على القنوات السليمة
		vec3 err = c - sim_rgb;
		vec3 fix = vec3(
			0.0,
			err.r * 0.7 + err.g * 1.0,
			err.r * 0.7 + err.b * 1.0);
		vec3 outc = clamp(c + fix * strength, vec3(0.0), vec3(1.0));
		COLOR = vec4(outc, 1.0);
	}
}
