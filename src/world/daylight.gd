class_name Daylight
extends RefCounted
## أوقات اليوم. كل وقت يغيّر الشمس والسماء والضباب والمحيط معاً،
## فلا يكفي رفع سطوع ضوء واحد — الإحساس بالنهار يأتي من اتساقها.

const KEYS := ["golden", "day", "dusk", "night"]
const LABELS := ["ساعة ذهبية", "نهار", "غروب", "ليل"]

const PRESETS := {
	"golden": {
		"sky_top": Color(0.235, 0.361, 0.569),
		"sky_horizon": Color(0.886, 0.741, 0.561),
		"ground_horizon": Color(0.329, 0.278, 0.224),
		"ground_bottom": Color(0.153, 0.133, 0.114),
		"sun_dir": Vector3(0.86, 0.26, -0.44),
		"sun_color": Color(1.0, 0.804, 0.541),
		"sun_energy": 2.30,
		"ambient_color": Color(0.482, 0.522, 0.596),
		"ambient_energy": 1.15,
		"fog_color": Color(0.702, 0.624, 0.525),
		"fog_near": 0.0022,
		"fog_far": 0.0062,
		"fog_begin": 48.0,
		"fog_end": 340.0,
		"sky_affect": 0.14,
		"exposure": 1.05,
		"saturation": 1.12,
		"lamp_scale": 0.35,
		"shadow_dist": 150.0,
		"foliage_tint": Color(1.0, 0.957, 0.886),
		"volumetric": 0.016,
		"vol_albedo": Color(1.0, 0.890, 0.741),
		"vol_emission": Color(0.251, 0.173, 0.090),
	},
	"day": {
		"sky_top": Color(0.247, 0.400, 0.620),
		"sky_horizon": Color(0.639, 0.718, 0.776),
		"ground_horizon": Color(0.333, 0.333, 0.306),
		"ground_bottom": Color(0.188, 0.196, 0.180),
		"sun_dir": Vector3(0.42, 0.80, 0.43),
		"sun_color": Color(1.0, 0.953, 0.871),
		"sun_energy": 1.30,
		"ambient_color": Color(0.396, 0.467, 0.569),
		"ambient_energy": 0.42,
		"fog_color": Color(0.596, 0.655, 0.714),
		"fog_near": 0.0016,       # كثافة الضباب على المرتفعات
		"fog_far": 0.0048,        # في بطن الوادي
		"fog_begin": 42.0,
		"fog_end": 320.0,
		"sky_affect": 0.12,
		"exposure": 0.86,
		"saturation": 1.06,
		"lamp_scale": 0.10,       # الفوانيس تخفت في وضح النهار
		"shadow_dist": 150.0,
		"foliage_tint": Color(1.0, 1.0, 1.0),
		"volumetric": 0.010,
		"vol_albedo": Color(0.941, 0.961, 1.0),
		"vol_emission": Color(0.090, 0.110, 0.149),
	},
	"dusk": {
		"sky_top": Color(0.133, 0.141, 0.251),
		"sky_horizon": Color(0.561, 0.361, 0.267),
		"ground_horizon": Color(0.192, 0.165, 0.153),
		"ground_bottom": Color(0.090, 0.082, 0.082),
		"sun_dir": Vector3(0.88, 0.16, -0.44),
		"sun_color": Color(1.0, 0.655, 0.408),
		"sun_energy": 0.90,
		"ambient_color": Color(0.329, 0.294, 0.322),
		"ambient_energy": 0.34,
		"fog_color": Color(0.392, 0.310, 0.290),
		"fog_near": 0.0075,
		"fog_far": 0.0190,
		"fog_begin": 24.0,
		"fog_end": 210.0,
		"sky_affect": 0.30,
		"exposure": 1.06,
		"saturation": 0.98,
		"lamp_scale": 0.65,
		"shadow_dist": 110.0,
		"foliage_tint": Color(0.82, 0.74, 0.70),
		"volumetric": 0.028,
		"vol_albedo": Color(1.0, 0.839, 0.714),
		"vol_emission": Color(0.192, 0.133, 0.102),
	},
	"night": {
		"sky_top": Color(0.027, 0.035, 0.063),
		"sky_horizon": Color(0.098, 0.118, 0.161),
		"ground_horizon": Color(0.067, 0.078, 0.102),
		"ground_bottom": Color(0.016, 0.020, 0.031),
		"sun_dir": Vector3(0.52, 0.72, 0.46),
		"sun_color": Color(0.639, 0.725, 0.886),
		"sun_energy": 0.70,
		"ambient_color": Color(0.153, 0.184, 0.247),
		"ambient_energy": 0.30,
		"fog_color": Color(0.094, 0.122, 0.165),
		"fog_near": 0.0085,
		"fog_far": 0.0300,
		"fog_begin": 16.0,
		"fog_end": 142.0,
		"sky_affect": 0.45,
		"exposure": 1.12,
		"saturation": 0.90,
		"lamp_scale": 1.0,
		"shadow_dist": 80.0,
		"foliage_tint": Color(0.40, 0.46, 0.60),
		"volumetric": 0.038,
		"vol_albedo": Color(0.741, 0.824, 1.0),
		"vol_emission": Color(0.035, 0.047, 0.078),
	},
}

static func preset(key: String) -> Dictionary:
	return PRESETS.get(key, PRESETS["night"])

## سطوع المستخدم 0..1 يُحوَّل إلى مضاعف تعريض 0.72..1.75.
## 0.5 = الوضع الطبيعي للوقت المختار.
static func exposure_multiplier(brightness01: float) -> float:
	var b := clampf(brightness01, 0.0, 1.0)
	return lerpf(0.72, 1.75, b)

## يطبّق الوقت والسطوع على البيئة والشمس دفعة واحدة
static func apply(env: Environment, sun: DirectionalLight3D, key: String, brightness01: float) -> void:
	var p := preset(key)
	if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
		var sm := env.sky.sky_material as ProceduralSkyMaterial
		sm.sky_top_color = p["sky_top"]
		sm.sky_horizon_color = p["sky_horizon"]
		sm.ground_horizon_color = p["ground_horizon"]
		sm.ground_bottom_color = p["ground_bottom"]
	env.ambient_light_color = p["ambient_color"]
	env.ambient_light_energy = float(p["ambient_energy"])
	env.fog_light_color = p["fog_color"]
	env.fog_depth_begin = float(p["fog_begin"])
	env.fog_depth_end = float(p["fog_end"])
	env.fog_sky_affect = float(p["sky_affect"])
	env.tonemap_exposure = float(p["exposure"]) * exposure_multiplier(brightness01)
	env.adjustment_saturation = float(p["saturation"])

	# الضباب الحجمي: هو مصدر أعمدة الضوء بين الأشجار. غير مدعوم في
	# مصيّر الجوال، ومتاح هنا لأن المشروع انتقل إلى Forward+.
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = float(p.get("volumetric", 0.03))
	env.volumetric_fog_albedo = p.get("vol_albedo", Color.WHITE)
	env.volumetric_fog_emission = p.get("vol_emission", Color.BLACK)
	env.volumetric_fog_emission_energy = 1.0
	env.volumetric_fog_gi_inject = 0.6
	env.volumetric_fog_anisotropy = 0.35
	env.volumetric_fog_length = 128.0
	env.volumetric_fog_detail_spread = 2.0

	if sun:
		sun.light_color = p["sun_color"]
		sun.light_energy = float(p["sun_energy"])
		sun.directional_shadow_max_distance = float(p["shadow_dist"])
		var d: Vector3 = p["sun_dir"]
		sun.transform = Transform3D(Basis(), d.normalized() * 120.0).looking_at(Vector3.ZERO, Vector3.UP)
