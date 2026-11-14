class_name WorldMaterials
extends RefCounted
## خامات العالم. كلها StandardMaterial3D مضبوطة لمصيّر الجوال:
## لا شفافية مرتّبة، ولا شيدرات مخصّصة في المسار الحرج.

const TEX := "res://assets/textures/world/"

static func _tex(name: String) -> Texture2D:
	var p := TEX + name
	if ResourceLoader.exists(p):
		return ResourceLoader.load(p)
	return null

## أرض الغابة: خامة مبلّطة بإحداثيات عالمية × لون الرأس (المنطقة الحيوية)
static func ground() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 1.0, 1.0)
	m.albedo_texture = _tex("ground_albedo.png")
	m.normal_enabled = true
	m.normal_texture = _tex("ground_normal.png")
	m.normal_scale = 1.25
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.roughness_texture = _tex("ground_rough.png")
	m.ao_enabled = true
	m.ao_texture = _tex("ground_ao.png")
	m.ao_light_affect = 0.55
	m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.uv1_scale = Vector3(2.2, 2.2, 1.0)
	m.metallic = 0.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

## نبات وحطام: لون الرأس وحده، فنوع واحد = نداء رسم واحد
## صبغة النبات تتغيّر مع وقت اليوم: ألوان الرؤوس مؤلَّفة للنهار،
## والليل يبرّدها ويخفضها بدل إعادة خبز العالم.
static var foliage_tint: Color = Color.WHITE
static var _foliage_mats: Array[StandardMaterial3D] = []

static func set_foliage_tint(c: Color) -> void:
	foliage_tint = c
	for m in _foliage_mats:
		if is_instance_valid(m):
			m.albedo_color = c

static func foliage(species: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = foliage_tint
	_foliage_mats.append(m)
	m.roughness = 0.94
	m.metallic = 0.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	# الأوراق تُرى من الوجهين؛ الجذوع والصخور لا تحتاج
	if species in ["fern", "grass", "willow", "bush"]:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

## الماء: شفافية بسيطة + خريطة نتوء متحرّكة. لا انعكاس شاشة (غير مدعوم هنا)
static func water() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.129, 0.231, 0.267, 0.78)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.normal_enabled = true
	m.normal_texture = _tex("water_normal.png")
	m.normal_scale = 0.55
	m.uv1_scale = Vector3(2.0, 1.0, 1.0)
	m.roughness = 0.08
	m.metallic = 0.35
	m.metallic_specular = 0.75
	m.rim_enabled = true
	m.rim = 0.65
	m.rim_tint = 0.25
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	return m

## لحاء الأشجار: خامة حقيقية بإحداثيات تتبع الجذع
static var _bark_mat: StandardMaterial3D = null
static func bark() -> StandardMaterial3D:
	if _bark_mat != null:
		return _bark_mat
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex("bark_albedo.png")
	m.normal_enabled = true
	m.normal_texture = _tex("bark_normal.png")
	m.normal_scale = 1.1
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.93
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_bark_mat = m
	return m

## أوراق على بطاقات: قصّ ألفا لا شفافية مرتّبة — أرخص ولا يحتاج ترتيباً.
## الإضاءة من الوجهين لأن البطاقة سطح رقيق يُرى من الجهتين.
static var _leaf_mats: Dictionary = {}
static func leaf(kind: String) -> StandardMaterial3D:
	if _leaf_mats.has(kind):
		return _leaf_mats[kind]
	var files := {"needle": "leaf_needle.png", "broad": "leaf_broad.png", "grass": "grass_card.png"}
	var file: String = str(files.get(kind, "leaf_broad.png"))
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex(file)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.35
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = foliage_tint
	m.roughness = 0.88
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	# ضوء يتخلّل الورقة: يمنع الأوراق الخلفية من أن تصير صمّاء سوداء
	m.backlight_enabled = true
	m.backlight = Color(0.42, 0.52, 0.30)
	_leaf_mats[kind] = m
	_foliage_mats.append(m)
	return m

## خشب المباني والجسور
static func timber(tint: Color = Color(0.302, 0.235, 0.173)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.albedo_texture = _tex("bark_albedo.png")
	m.uv1_scale = Vector3(1.6, 1.6, 1.6)
	m.roughness = 0.92
	m.metallic = 0.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

static func stone(tint: Color = Color(0.46, 0.46, 0.47)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.albedo_texture = _tex("rock_albedo.png")
	m.normal_enabled = true
	m.normal_texture = _tex("rock_normal.png")
	m.normal_scale = 0.7
	m.uv1_scale = Vector3(0.9, 0.9, 0.9)
	m.roughness = 0.95
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

static func plain(col: Color, rough: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = 0.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

static func emissive(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	m.roughness = 0.5
	return m
