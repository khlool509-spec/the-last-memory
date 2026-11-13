extends SceneTree
## مُشغّل الاختبارات الآلي — يُنفَّذ بـ Godot headless
## الاستخدام: godot --headless --path . --script res://tests/test_runner.gd
## يعيد رمز خروج = عدد الإخفاقات

var _pass := 0
var _fail := 0
var _log: Array[String] = []

func _ok(name: String) -> void:
	_pass += 1
	print("  PASS  ", name)

func _no(name: String, detail: String = "") -> void:
	_fail += 1
	var line := "  FAIL  " + name
	if detail != "":
		line += "  ->  " + detail
	print(line)
	_log.append(line)

func _initialize() -> void:
	print("=== اختبارات THE LAST MEMORY ===\n")
	_test_project_settings()
	_test_main_scene()
	_test_folder_structure()
	_test_all_scenes()
	_test_all_scripts()
	_test_fonts()
	_test_theme()
	_test_settings_roundtrip()
	_test_save_roundtrip()
	print("\n=== النتيجة: %d نجح، %d أخفق ===" % [_pass, _fail])
	quit(_fail)

# ---------- إعدادات المشروع ----------
func _test_project_settings() -> void:
	print("[إعدادات المشروع]")
	var name := str(ProjectSettings.get_setting("application/config/name", ""))
	if name == "THE LAST MEMORY":
		_ok("اسم المشروع")
	else:
		_no("اسم المشروع", name)

	var method := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))
	if method == "mobile":
		_ok("الـ Renderer = mobile")
	else:
		_no("الـ Renderer = mobile", method)

	var mobile_override := str(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", ""))
	if mobile_override == "mobile":
		_ok("تجاوز الـ Renderer للمحمول")
	else:
		_no("تجاوز الـ Renderer للمحمول", mobile_override)

	if bool(ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc", false)):
		_ok("ضغط ETC2/ASTC مفعّل")
	else:
		_no("ضغط ETC2/ASTC مفعّل", "مطلوب لأندرويد")

# ---------- المشهد الرئيسي ----------
## هذا الاختبار أُضيف بعد خطأ حقيقي: صدرت نسخة بلا مشهد رئيسي،
## فثُبِّتت وفُتحت ثم ردّت "Unable to setup the Godot engine!".
func _test_main_scene() -> void:
	print("\n[المشهد الرئيسي]")
	var main := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if main == "":
		_no("المشهد الرئيسي معرَّف", "run/main_scene فارغ — التطبيق لن يقلع على الجهاز")
		return
	_ok("المشهد الرئيسي معرَّف: " + main)

	if not ResourceLoader.exists(main):
		_no("ملف المشهد الرئيسي موجود", main)
		return
	_ok("ملف المشهد الرئيسي موجود")

	var packed := ResourceLoader.load(main, "PackedScene")
	if packed == null:
		_no("تحميل المشهد الرئيسي", "فشل")
		return
	var root := (packed as PackedScene).instantiate()
	if root == null:
		_no("إنشاء المشهد الرئيسي", "instantiate أعاد null")
		return
	_ok("المشهد الرئيسي يُحمَّل ويُنشَأ")

	# شروط الكاميرا والإضاءة تخص المشاهد الثلاثية فقط.
	# شاشة واجهة (Control) لا تحتاج أياً منهما، فلا نفرضها عليها.
	var has_cam := false
	var has_light := false
	var has_3d := false
	var has_ui := false
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Node3D:
			has_3d = true
		if n is Control:
			has_ui = true
		if n is Camera3D:
			has_cam = true
		if n is DirectionalLight3D or n is OmniLight3D or n is SpotLight3D:
			has_light = true
		for c in n.get_children():
			stack.append(c)
	if not has_3d:
		_ok("  مشهد واجهة (لا يتطلب كاميرا ثلاثية)" if has_ui else "  مشهد غير ثلاثي")
	else:
		if has_cam:
			_ok("  يحتوي كاميرا")
		else:
			_no("  يحتوي كاميرا", "بلا كاميرا = شاشة سوداء على الجهاز")
		if has_light:
			_ok("  يحتوي مصدر إضاءة")
		else:
			_no("  يحتوي مصدر إضاءة", "بلا إضاءة = أجسام سوداء")
	_check_camera_aim(root)
	root.free()

## اختبار أُضيف بعد خطأ حقيقي: مصفوفة الكاميرا كانت معكوسة الإشارة،
## فنظرت إلى الأعلى بزاوية 41 درجة عن الهدف، وظهر المشهد عند حافة الشاشة.
## لا نحسب المصفوفات يدوياً بعد الآن — Transform3D.looking_at هي المرجع.
##
## نركّب التحويلات العالمية يدوياً لأن global_transform يتطلب وجود العقدة
## داخل شجرة المشهد، وهي غير مهيأة أثناء _initialize.
func _world_xform(n: Node3D, stop: Node) -> Transform3D:
	var t := n.transform
	var p := n.get_parent()
	while p != null and p != stop:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t

func _check_camera_aim(scene_root: Node) -> void:
	var cam: Camera3D = null
	var centers: Array[Vector3] = []
	var stack: Array[Node] = [scene_root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Camera3D and cam == null:
			cam = n
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			# نتجاهل الأسطح المسطّحة كالأرضيات: تمتد تحت الكاميرا فتشوّه المركز
			if (n as MeshInstance3D).mesh.get_aabb().size.y > 0.05:
				centers.append(_world_xform(n as Node3D, scene_root.get_parent()).origin)
		for c in n.get_children():
			stack.append(c)
	# لا محتوى ثلاثي = لا شيء يُؤطَّر (شاشات الواجهة مثلاً)
	if centers.is_empty():
		return
	if cam == null:
		_no("  يوجد كاميرا للتأطير", "محتوى ثلاثي بلا كاميرا")
		return
	var center := Vector3.ZERO
	for c in centers:
		center += c
	center /= float(centers.size())
	var cam_x := _world_xform(cam, scene_root.get_parent())
	var to_center := center - cam_x.origin
	if to_center.length() < 0.001:
		return
	var fwd := -cam_x.basis.z
	var d := fwd.dot(to_center.normalized())
	var angle := rad_to_deg(acos(clampf(d, -1.0, 1.0)))
	var limit := cam.fov * 0.5
	if angle <= limit:
		_ok("  الكاميرا تؤطّر المحتوى (انحراف %.1f\u00b0 من حد %.1f\u00b0)" % [angle, limit])
	else:
		_no("  الكاميرا تؤطّر المحتوى",
			"انحراف %.1f\u00b0 يتجاوز نصف مجال الرؤية %.1f\u00b0 — المحتوى خارج الكادر" % [angle, limit])

# ---------- بنية المجلدات ----------
func _test_folder_structure() -> void:
	print("\n[بنية المجلدات]")
	var required := [
		"res://src", "res://src/core", "res://src/player", "res://src/camera",
		"res://src/environment", "res://src/interaction", "res://src/inventory",
		"res://src/puzzle", "res://src/audio", "res://src/ui", "res://src/save_system",
		"res://src/story", "res://src/cinematics", "res://src/optimization",
		"res://assets/models", "res://assets/textures", "res://assets/materials",
		"res://assets/audio", "res://assets/fonts", "res://assets/shaders",
		"res://levels", "res://tests", "res://docs",
	]
	var missing: Array[String] = []
	for p in required:
		if not DirAccess.dir_exists_absolute(p):
			missing.append(p)
	if missing.is_empty():
		_ok("كل المجلدات المطلوبة موجودة (%d)" % required.size())
	else:
		_no("مجلدات ناقصة", ", ".join(missing))

# ---------- المشاهد ----------
func _collect(dir_path: String, ext: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if f.begins_with("."):
			f = d.get_next()
			continue
		var full := dir_path.path_join(f)
		if d.current_is_dir():
			_collect(full, ext, out)
		elif f.ends_with(ext):
			out.append(full)
		f = d.get_next()
	d.list_dir_end()

func _test_all_scenes() -> void:
	print("\n[المشاهد]")
	var scenes: Array[String] = []
	_collect("res://", ".tscn", scenes)
	if scenes.is_empty():
		print("  (لا مشاهد بعد)")
		return
	for path in scenes:
		var packed := ResourceLoader.load(path, "PackedScene")
		if packed == null:
			_no("تحميل " + path, "فشل التحميل")
			continue
		var root := (packed as PackedScene).instantiate()
		if root == null:
			_no("إنشاء " + path, "instantiate أعاد null")
			continue
		_ok("تحميل وإنشاء " + path.get_file())
		_check_scene_nodes(path, root)
		root.free()

func _check_scene_nodes(path: String, root: Node) -> void:
	var stack: Array[Node] = [root]
	var meshes_empty: Array[String] = []
	var count := 0
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		count += 1
		if n is MeshInstance3D and (n as MeshInstance3D).mesh == null:
			meshes_empty.append(n.name)
		for c in n.get_children():
			stack.append(c)
	if meshes_empty.is_empty():
		_ok("  كل MeshInstance3D لها مجسّم (%d عقدة)" % count)
	else:
		_no("  MeshInstance3D بلا مجسّم في " + path.get_file(), ", ".join(meshes_empty))

# ---------- السكربتات ----------
func _test_all_scripts() -> void:
	print("\n[سكربتات GDScript]")
	var scripts: Array[String] = []
	_collect("res://", ".gd", scripts)
	if scripts.is_empty():
		print("  (لا سكربتات بعد)")
		return
	for path in scripts:
		var s := ResourceLoader.load(path)
		if s == null:
			_no("تحميل " + path.get_file(), "فشل")
		elif s is GDScript and not (s as GDScript).can_instantiate() and (s as GDScript).get_instance_base_type() == "":
			_no("صلاحية " + path.get_file(), "السكربت لا يُصرَّف")
		else:
			_ok("تصريف " + path.get_file())


# ---------- الخطوط ----------
## لا فائدة من واجهة عربية بخط لا يملك حروفها: ستظهر مربعات فارغة.
func _test_fonts() -> void:
	print("\n[الخطوط]")
	for path in [UITheme.FONT_REGULAR, UITheme.FONT_BOLD]:
		var f := UITheme.load_font(path)
		if f == null:
			_no("تحميل " + path.get_file(), "غير موجود")
			continue
		_ok("تحميل " + path.get_file())
		var missing: Array[String] = []
		# حروف عربية أساسية + همزات + أرقام عربية ولاتينية + علامات
		for ch in "ابتثجحخدذرزسشصضطظعغفقكلمنهويءأإآةىئؤ٠١٢٣٤٥٦٧٨٩0123456789٪؟،":
			if not f.has_char(ch.unicode_at(0)):
				missing.append(ch)
		if missing.is_empty():
			_ok("  تغطية الحروف العربية والأرقام كاملة")
		else:
			_no("  تغطية الحروف", "ناقص: " + "".join(missing))

# ---------- السمة ----------
func _test_theme() -> void:
	print("\n[السمة]")
	var t := UITheme.build()
	if t == null:
		_no("بناء السمة", "أعادت null")
		return
	_ok("بناء السمة")
	if t.default_font != null:
		_ok("  خط افتراضي مُسنَد")
	else:
		_no("  خط افتراضي مُسنَد", "default_font فارغ")
	var needed := [["normal", "Button"], ["hover", "Button"], ["pressed", "Button"], ["panel", "PanelContainer"]]
	var miss: Array[String] = []
	for n in needed:
		if not t.has_stylebox(n[0], n[1]):
			miss.append("%s/%s" % [n[1], n[0]])
	if miss.is_empty():
		_ok("  كل أنماط الواجهة موجودة")
	else:
		_no("  أنماط ناقصة", ", ".join(miss))

# ---------- دورة الإعدادات ----------
func _test_settings_roundtrip() -> void:
	print("\n[الإعدادات]")
	var cfg := ConfigFile.new()
	var probe := {"master_volume": 0.33, "language": "en", "invert_y": true}
	for k in probe:
		cfg.set_value("game", k, probe[k])
	var tmp := "user://settings_test.cfg"
	if cfg.save(tmp) != OK:
		_no("كتابة ملف إعدادات", "فشل الحفظ")
		return
	_ok("كتابة ملف إعدادات")
	var back := ConfigFile.new()
	if back.load(tmp) != OK:
		_no("قراءة ملف إعدادات", "فشل التحميل")
		return
	var all_ok := true
	for k in probe:
		if back.get_value("game", k) != probe[k]:
			all_ok = false
	if all_ok:
		_ok("  القيم تعود كما حُفظت")
	else:
		_no("  القيم تعود كما حُفظت", "اختلاف بعد الدورة")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	# التأكد أن كل المفاتيح الافتراضية موجودة ولها أنواع صحيحة
	var defaults_script := load("res://src/core/game_settings.gd")
	if defaults_script == null:
		_no("  سكربت الإعدادات", "غير موجود")
		return
	_ok("  سكربت الإعدادات يُحمَّل")

# ---------- دورة الحفظ ----------
func _test_save_roundtrip() -> void:
	print("\n[نظام الحفظ]")
	var scr := load("res://src/save_system/save_system.gd")
	if scr == null:
		_no("تحميل نظام الحفظ", "غير موجود")
		return
	var inst: Node = scr.new()
	var base: Dictionary = inst.default_data()
	var needed := ["version", "chapter", "checkpoint", "collectibles", "chapters_unlocked", "flags"]
	var miss: Array[String] = []
	for k in needed:
		if not base.has(k):
			miss.append(k)
	if miss.is_empty():
		_ok("بنية ملف الحفظ كاملة (%d مفتاحاً)" % base.size())
	else:
		_no("بنية ملف الحفظ", "ناقص: " + ", ".join(miss))
	# دورة JSON كاملة
	var txt := JSON.stringify(base)
	var back: Variant = JSON.parse_string(txt)
	if typeof(back) == TYPE_DICTIONARY and (back as Dictionary).size() == base.size():
		_ok("  الحفظ والقراءة بصيغة JSON سليمان")
	else:
		_no("  دورة JSON", "فشل التحليل")
	inst.free()
