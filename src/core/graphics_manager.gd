extends Node
## مدير الرسومات: يحوّل كل إعداد إلى تغيير حقيقي في المصيّر.
## مسجَّل autoload باسم Graphics.
##
## لا شيء هنا تزييني: كل مفتاح يمسّ قياس التصيير أو خريطة الظل أو
## معدّل الإطارات أو تدرّج الألوان فعلاً. والقياس التكيّفي يقرأ زمن
## الإطار الحقيقي ويضبط القياس ليبلغ الهدف.

## مستويات الجودة: من الأخفّ إلى الأثقل
const QUALITY := {
	"ultra_smooth": {"scale": 0.60, "shadow": 1024, "ssao": false, "ssil": false,
		"aniso": 1, "lod": 6.0, "label": "سلاسة فائقة"},
	"smooth":       {"scale": 0.72, "shadow": 2048, "ssao": false, "ssil": false,
		"aniso": 2, "lod": 5.0, "label": "سلسة"},
	"balanced":     {"scale": 0.85, "shadow": 2048, "ssao": true,  "ssil": false,
		"aniso": 3, "lod": 4.0, "label": "متوازنة"},
	"hd":           {"scale": 1.00, "shadow": 4096, "ssao": true,  "ssil": false,
		"aniso": 4, "lod": 3.0, "label": "عالية الدقة"},
	"hdr":          {"scale": 1.00, "shadow": 4096, "ssao": true,  "ssil": true,
		"aniso": 4, "lod": 2.5, "label": "HDR"},
	"ultra_hdr":    {"scale": 1.15, "shadow": 4096, "ssao": true,  "ssil": true,
		"aniso": 4, "lod": 2.0, "label": "فائق HDR"},
	"high_hdr":     {"scale": 1.30, "shadow": 8192, "ssao": true,  "ssil": true,
		"aniso": 4, "lod": 1.5, "label": "عالي HDR"},
}
const QUALITY_ORDER := ["ultra_smooth", "smooth", "balanced", "hd", "hdr",
	"ultra_hdr", "high_hdr"]

## طبقات معدّل الإطارات
const FPS_TIER := {
	"power_save":    {"fps": 24,  "label": "توفير الطاقة"},
	"medium":        {"fps": 30,  "label": "متوسطة"},
	"high":          {"fps": 40,  "label": "مرتفع"},
	"ultra":         {"fps": 50,  "label": "فائقة"},
	"strong":        {"fps": 60,  "label": "قوية"},
	"extreme_plus":  {"fps": 90,  "label": "إكستريم+"},
	"ultra_extreme": {"fps": 120, "label": "ألترا إكستريم"},
}
const FPS_ORDER := ["power_save", "medium", "high", "ultra", "strong",
	"extreme_plus", "ultra_extreme"]

## أنماط الرسوم: تدرّج لوني حقيقي لا ترشيح سطحي
const STYLE := {
	"classic":   {"sat": 1.00, "con": 1.00, "exp": 1.00, "tone": 3, "label": "كلاسيكي"},
	"vivid":     {"sat": 1.34, "con": 1.12, "exp": 1.06, "tone": 3, "label": "زاه"},
	"realistic": {"sat": 0.96, "con": 1.04, "exp": 0.98, "tone": 3, "label": "واقعي"},
	"soft":      {"sat": 0.88, "con": 0.92, "exp": 1.04, "tone": 1, "label": "ناعم"},
	"cinematic": {"sat": 0.82, "con": 1.18, "exp": 0.94, "tone": 2, "label": "سينمائي"},
}
const STYLE_ORDER := ["classic", "vivid", "realistic", "soft", "cinematic"]

## أنماط عمى الألوان — تصحيح حقيقي (daltonization) لا تلوين
const CB_ORDER := ["none", "deuteranopia", "protanopia", "tritanopia"]
const CB_LABEL := {"none": "عادية", "deuteranopia": "عمى اللون الأخضر",
	"protanopia": "عمى اللون الأحمر", "tritanopia": "عمى اللون الأزرق"}

## الإعدادات الجاهزة
const PRESETS := {
	"fps":      {"gfx_quality": "smooth", "gfx_fps_tier": "extreme_plus",
		"gfx_shadows": false, "gfx_antialiasing": false, "gfx_adaptive": true},
	"balanced": {"gfx_quality": "balanced", "gfx_fps_tier": "strong",
		"gfx_shadows": true, "gfx_antialiasing": true, "gfx_adaptive": true},
	"quality":  {"gfx_quality": "ultra_hdr", "gfx_fps_tier": "high",
		"gfx_shadows": true, "gfx_antialiasing": true, "gfx_adaptive": false},
}

signal applied(summary: String)

var _vp: Viewport = null
var _env: Environment = null
var _sun: DirectionalLight3D = null
var _cb_layer: CanvasLayer = null
var _cb_rect: ColorRect = null

# القياس التكيّفي
var _adaptive_scale := 1.0
var _frame_acc := 0.0
var _frame_n := 0
var _measured_fps := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_vp = get_viewport()
	_build_colorblind_layer()
	Settings.changed.connect(_on_setting)
	call_deferred("apply_all")

## يُستدعى من الفصل بعد بناء البيئة والشمس
func bind_world(env: Environment, sun: DirectionalLight3D) -> void:
	_env = env
	_sun = sun
	apply_all()

func quality_label(k: String) -> String:
	return str(QUALITY.get(k, {}).get("label", k))

func fps_label(k: String) -> String:
	return str(FPS_TIER.get(k, {}).get("label", k))

func style_label(k: String) -> String:
	return str(STYLE.get(k, {}).get("label", k))

func measured_fps() -> float:
	return _measured_fps

var _applying_preset := false

func _on_setting(key: String, _v: Variant) -> void:
	if not (key.begins_with("gfx_") or key == "ui_safe_area"):
		return
	if key == "gfx_preset":
		_applying_preset = true
		_apply_preset(str(Settings.get_value("gfx_preset")))
		_applying_preset = false
	elif not _applying_preset and key != "gfx_fps_cap":
		# تعديل يدوي لأي مفتاح يعني أن الإعداد لم يعد جاهزاً
		if str(Settings.get_value("gfx_preset")) != "custom":
			_applying_preset = true
			Settings.set_value("gfx_preset", "custom")
			_applying_preset = false
	apply_all()

func _apply_preset(name: String) -> void:
	if not PRESETS.has(name):
		return                       # "custom" لا يغيّر شيئاً
	for k in PRESETS[name]:
		Settings.set_value(k, PRESETS[name][k])

func apply_all() -> void:
	var q := str(Settings.get_value("gfx_quality"))
	if not QUALITY.has(q):
		q = "balanced"
	var spec: Dictionary = QUALITY[q]
	var power := bool(Settings.get_value("gfx_power_save"))

	# 1) قياس التصيير — أقوى رافعة أداء على الجوال
	var scale := float(spec["scale"])
	if power:
		scale = minf(scale, 0.70)
	scale *= _adaptive_scale
	if _vp:
		_vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		_vp.scaling_3d_scale = clampf(scale, 0.45, 2.0)
		# 2) إزالة التسنّن
		var aa := bool(Settings.get_value("gfx_antialiasing")) and not power
		_vp.msaa_3d = Viewport.MSAA_4X if aa else Viewport.MSAA_DISABLED
		_vp.mesh_lod_threshold = float(spec["lod"])

	# 3) الظلال: خريطة الظل وحجمها
	var shadows := bool(Settings.get_value("gfx_shadows")) and not power
	RenderingServer.directional_shadow_atlas_set_size(int(spec["shadow"]), true)
	if _sun:
		_sun.shadow_enabled = shadows

	# 4) الحجب والارتداد
	if _env:
		_env.ssao_enabled = bool(spec["ssao"]) and not power
		_env.ssil_enabled = bool(spec["ssil"]) and not power
		# 5) نمط الرسوم: تدرّج لوني حقيقي
		var st := str(Settings.get_value("gfx_style"))
		if not STYLE.has(st):
			st = "classic"
		var s: Dictionary = STYLE[st]
		_env.adjustment_enabled = true
		_env.adjustment_saturation = float(s["sat"])
		_env.adjustment_contrast = float(s["con"])
		_env.tonemap_mode = int(s["tone"]) as Environment.ToneMapper
		_env.set_meta("style_exposure", float(s["exp"]))

	# 6) ترشيح تباين الاتجاه
	ProjectSettings.set_setting(
		"rendering/textures/default_filters/anisotropic_filtering_level", int(spec["aniso"]))

	# 7) سقف معدّل الإطارات
	var tier := str(Settings.get_value("gfx_fps_tier"))
	var cap := int(FPS_TIER.get(tier, {}).get("fps", 60))
	if bool(Settings.get_value("gfx_fps_manual")):
		cap = int(Settings.get_value("gfx_fps_cap"))
	if power:
		cap = mini(cap, 30)
	Engine.max_fps = clampi(cap, 20, 144)

	# 8) إزاحة الشاشات غير القياسية: هامش علوي حقيقي للواجهة
	_apply_safe_area()

	# 9) عمى الألوان
	_update_colorblind()
	applied.emit("%s · %d إطاراً · قياس %.0f%%" % [
		quality_label(q), Engine.max_fps, (_vp.scaling_3d_scale if _vp else 1.0) * 100.0])

func _process(delta: float) -> void:
	# قياس زمن الإطار الحقيقي ثم الضبط التكيّفي نحو الهدف
	_frame_acc += delta
	_frame_n += 1
	if _frame_acc < 1.0:
		return
	_measured_fps = float(_frame_n) / _frame_acc
	_frame_acc = 0.0
	_frame_n = 0
	if not bool(Settings.get_value("gfx_adaptive")):
		if not is_equal_approx(_adaptive_scale, 1.0):
			_adaptive_scale = 1.0
			apply_all()
		return
	var target := float(Engine.max_fps) * 0.92
	var before := _adaptive_scale
	if _measured_fps < target * 0.82:
		_adaptive_scale = maxf(_adaptive_scale - 0.06, 0.62)
	elif _measured_fps > target * 1.06:
		_adaptive_scale = minf(_adaptive_scale + 0.03, 1.0)
	if not is_equal_approx(before, _adaptive_scale):
		apply_all()

## الهامش يُطبَّق على كل Control جذري في طبقات الواجهة، فيبتعد
## المحتوى عن القصّة العلوية في الشاشات المقوّسة.
func _apply_safe_area() -> void:
	var frac := clampf(float(Settings.get_value("ui_safe_area")), 0.0, 1.0)
	var px := frac * 110.0
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	for cl in tree.current_scene.find_children("*", "CanvasLayer", true, false):
		for c in cl.get_children():
			if c is Control and (c as Control).anchors_preset == Control.PRESET_FULL_RECT:
				(c as Control).offset_top = px

# ---------------- عمى الألوان ----------------
func _build_colorblind_layer() -> void:
	_cb_layer = CanvasLayer.new()
	_cb_layer.name = "ColorBlindLayer"
	_cb_layer.layer = 128            # فوق كل شيء بما فيه الواجهة
	_cb_rect = ColorRect.new()
	_cb_rect.name = "ColorBlindRect"
	_cb_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cb_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh: Shader = ResourceLoader.load("res://assets/shaders/colorblind.gdshader")
	if sh:
		var m := ShaderMaterial.new()
		m.shader = sh
		_cb_rect.material = m
	_cb_rect.visible = false
	_cb_layer.add_child(_cb_rect)
	add_child(_cb_layer)

func _update_colorblind() -> void:
	if _cb_rect == null:
		return
	var mode := str(Settings.get_value("gfx_colorblind"))
	var idx := CB_ORDER.find(mode)
	if idx <= 0:
		_cb_rect.visible = false
		return
	_cb_rect.visible = true
	var m := _cb_rect.material as ShaderMaterial
	if m:
		m.set_shader_parameter("mode", idx)
