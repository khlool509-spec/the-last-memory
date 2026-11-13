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

	# مشهد ثلاثي بلا كاميرا = شاشة سوداء، وبلا إضاءة = أجسام سوداء
	var has_cam := false
	var has_light := false
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Camera3D:
			has_cam = true
		if n is DirectionalLight3D or n is OmniLight3D or n is SpotLight3D:
			has_light = true
		for c in n.get_children():
			stack.append(c)
	if has_cam:
		_ok("  يحتوي كاميرا")
	else:
		_no("  يحتوي كاميرا", "بلا كاميرا = شاشة سوداء على الجهاز")
	if has_light:
		_ok("  يحتوي مصدر إضاءة")
	else:
		_no("  يحتوي مصدر إضاءة", "بلا إضاءة = أجسام سوداء")
	root.free()

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
