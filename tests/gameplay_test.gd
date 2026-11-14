extends Node
## اختبارات اللعب الفعلية. تعمل بالحلقة الرئيسية العادية (لا --script)
## حتى تكون الـ autoloads حيّة ويكون كل شيء داخل الشجرة فعلاً.
## الخروج = عدد الإخفاقات.

var _pass := 0
var _fail := 0

func _ok(n: String) -> void:
	_pass += 1
	print("  PASS  ", n)

func _no(n: String, d: String = "") -> void:
	_fail += 1
	print("  FAIL  ", n, ("  ->  " + d) if d != "" else "")

func _eq(n: String, got, want) -> void:
	if got == want:
		_ok(n)
	else:
		_no(n, "وجدنا %s والمطلوب %s" % [str(got), str(want)])

func _true(n: String, v: bool, d: String = "") -> void:
	if v: _ok(n)
	else: _no(n, d)

func _ready() -> void:
	print("=== اختبارات اللعب ===\n")
	_test_itemdb()
	_test_inventory()
	_test_persistence()
	_test_objectives()
	_test_chapter_unlock()
	_test_audio()
	_test_interactor()
	_test_pickup()
	_test_door()
	await _test_chapter_one()
	await _test_level_layout()
	print("\n=== اللعب: %d نجح، %d أخفق ===" % [_pass, _fail])
	get_tree().quit(_fail)

# ---------- قاعدة الأغراض ----------
func _test_itemdb() -> void:
	print("[قاعدة الأغراض]")
	var ids := ItemDB.all_ids()
	_true("توجد أغراض معرّفة (%d)" % ids.size(), ids.size() >= 5)
	var bad := 0
	var notes_without_body := 0
	for id in ids:
		var d: Dictionary = ItemDB.get_item(id)
		if str(d.get("name", "")).strip_edges() == "" \
		or str(d.get("glyph", "")).strip_edges() == "" \
		or not d.has("kind"):
			bad += 1
			print("    ناقص: ", id)
		if ItemDB.is_note(id) and str(d.get("body", "")).strip_edges() == "":
			notes_without_body += 1
	_eq("كل غرض له اسم ورمز ونوع", bad, 0)
	_eq("كل ورقة لها نص يُقرأ", notes_without_body, 0)
	_true("غرض غير موجود يُرفض", not ItemDB.exists("no_such_item"))

# ---------- الحقيبة ----------
func _test_inventory() -> void:
	print("\n[الحقيبة]")
	SaveSystem.start_new_game()
	Inv._sync_from_save()
	_eq("تبدأ فارغة", Inv.total_collected(), 0)

	_true("إضافة غرض", Inv.add("old_key"))
	_true("الغرض موجود", Inv.has("old_key"))
	_true("تكرار الإضافة مرفوض", not Inv.add("old_key"))
	_eq("عدد الأغراض", Inv.items.size(), 1)

	_true("إضافة ورقة", Inv.add("note_awakening"))
	_eq("الورقة تذهب للمذكرات لا الأغراض", Inv.notes.size(), 1)
	_eq("الأغراض لم تتغير", Inv.items.size(), 1)
	_eq("المجموع", Inv.total_collected(), 2)

	_true("غرض مجهول يُرفض", not Inv.add("ghost_item"))
	_true("الحذف يعمل", Inv.remove("old_key"))
	_true("لم يعد موجوداً", not Inv.has("old_key"))
	_true("حذف غير موجود يُرفض", not Inv.remove("old_key"))

# ---------- الحفظ ----------
func _test_persistence() -> void:
	print("\n[حفظ المقتنيات]")
	SaveSystem.start_new_game()
	Inv._sync_from_save()
	Inv.add("lantern")
	Inv.add("pendant")
	Inv.add("note_lantern")
	var before := Inv.total_collected()

	_true("الحفظ نجح", SaveSystem.save_game())
	Inv.items.clear()
	Inv.notes.clear()
	_eq("أُفرغت الذاكرة", Inv.total_collected(), 0)

	_true("التحميل نجح", SaveSystem.load_game())
	Inv._sync_from_save()
	_eq("عاد كل شيء بعد التحميل", Inv.total_collected(), before)
	_true("الفانوس عاد", Inv.has("lantern"))
	_true("الورقة عادت كمذكرة", Inv.notes.has("note_lantern"))
	_true("القلادة في الأغراض", Inv.items.has("pendant"))

# ---------- الأهداف ----------
func _test_objectives() -> void:
	print("\n[الأهداف]")
	SaveSystem.start_new_game()
	Goals.start_chapter(1)
	_eq("الهدف الأول", Goals.current_id, "wake")
	_true("نصه عربي غير فارغ", Goals.current_text.strip_edges() != "")

	Goals.complete("wrong_id")
	_eq("هدف خاطئ لا يُقدّم شيئاً", Goals.current_id, "wake")

	var chain := ["find_note", "follow_lanterns", "reach_gate"]
	var prev := "wake"
	for want in chain:
		Goals.complete(prev)
		_eq("بعد %s ← %s" % [prev, want], Goals.current_id, want)
		prev = want
	Goals.complete("reach_gate")
	_eq("نهاية السلسلة", Goals.current_id, "done")
	_eq("نقطة الحفظ تتبع الهدف", str(SaveSystem.data.get("checkpoint", "")), "done")

# ---------- فتح الفصول ----------
## chapters_unlocked مصفوفة أرقام. عوملت مرة كعدّاد فوقع خطأ تشغيل حقيقي.
func _test_chapter_unlock() -> void:
	print("\n[فتح الفصول]")
	SaveSystem.start_new_game()
	_true("النوع مصفوفة", SaveSystem.data.get("chapters_unlocked") is Array)
	_true("الفصل 1 مفتوح", SaveSystem.is_chapter_unlocked(1))
	_true("الفصل 2 مقفل", not SaveSystem.is_chapter_unlocked(2))
	_eq("الأعلى = 1", SaveSystem.highest_unlocked(), 1)

	_true("فتح الفصل 2", SaveSystem.unlock_chapter(2))
	_true("صار مفتوحاً", SaveSystem.is_chapter_unlocked(2))
	_true("فتحه مرة ثانية يُرفض", not SaveSystem.unlock_chapter(2))
	_eq("الأعلى = 2", SaveSystem.highest_unlocked(), 2)

	SaveSystem.load_game()
	_true("يبقى مفتوحاً بعد التحميل", SaveSystem.is_chapter_unlocked(2))
	# JSON يعيد الأعداد كـ float: [1,2] تصير [1.0,2.0] فتُقرأ الفصول مقفلة.
	# خطأ حقيقي كُشف هنا، فصار النوع نفسه مُختبَراً.
	var arr: Array = SaveSystem.data.get("chapters_unlocked", [])
	var all_int := true
	for v in arr:
		if typeof(v) != TYPE_INT:
			all_int = false
	_true("الأرقام أعداد صحيحة بعد JSON", all_int, str(arr))
	_eq("الأعلى بعد التحميل = 2", SaveSystem.highest_unlocked(), 2)
	_true("الفصل 3 ما زال مقفلاً", not SaveSystem.is_chapter_unlocked(3))
	_eq("مسار الفصل 1 مبني", Chapters.scene_path(1), "res://levels/ch01_forest/chapter_one.tscn")
	_true("الفصل 1 قابل للعب", Chapters.is_playable(1))
	_true("الفصل 3 ليس مبنياً بعد", not Chapters.is_playable(3))
	_eq("أول فصل مبني", Chapters.first_playable(), "res://levels/ch01_forest/chapter_one.tscn")

# ---------- الصوت ----------
## كل الأصوات مولَّدة داخل المشروع. الاختبار يتحقق من وجودها وتحميلها
## وتكرارها، لا من سماعها — السماع لا يُختبر بلا جهاز.
func _test_audio() -> void:
	print("\n[الصوت]")
	for bus in ["Master", "Music", "SFX"]:
		_true("مسار الصوت %s موجود" % bus, AudioServer.get_bus_index(bus) >= 0)

	var missing := 0
	var not_wav := 0
	var total := 0
	for group in [Audio.MUSIC, Audio.AMBIENT, Audio.SFX]:
		for key in group:
			total += 1
			var path := str(group[key])
			if not ResourceLoader.exists(path):
				missing += 1
				print("    مفقود: ", path)
				continue
			var st: AudioStream = ResourceLoader.load(path)
			if not (st is AudioStreamWAV):
				not_wav += 1
			elif st.get_length() <= 0.0:
				not_wav += 1
	_true("كل الملفات معرّفة (%d)" % total, total >= 12)
	_eq("لا ملف مفقود", missing, 0)
	_eq("كلها WAV بطول صالح", not_wav, 0)

	Audio.play_ambient("forest")
	var amb: AudioStreamWAV = Audio._ambient.stream as AudioStreamWAV
	_true("الأجواء محمّلة", amb != null)
	if amb != null:
		_eq("الأجواء تتكرر", amb.loop_mode, AudioStreamWAV.LOOP_FORWARD)
		_true("نهاية التكرار محسوبة", amb.loop_end > 1000, str(amb.loop_end))
		_true("طول الأجواء كافٍ (%.1f ث)" % amb.get_length(), amb.get_length() > 10.0)

	Audio.play_music("menu")
	var mus: AudioStreamWAV = Audio._music.stream as AudioStreamWAV
	_true("الموسيقى محمّلة", mus != null)
	if mus != null:
		_eq("الموسيقى تتكرر", mus.loop_mode, AudioStreamWAV.LOOP_FORWARD)
		_true("طول الموسيقى كافٍ (%.1f ث)" % mus.get_length(), mus.get_length() > 20.0)

	# أصوات متعددة متتابعة: تتوزّع على أصوات مختلفة فلا تقطع بعضها
	for i in 6:
		Audio.play_footstep(i % 2 == 0)
	var used := 0
	for v in Audio._voices:
		if v.stream != null:
			used += 1
	_true("تعدد الأصوات يعمل (%d/%d)" % [used, Audio._voices.size()], used >= 4)

	Audio.play("لا_يوجد_هذا")
	_ok("مفتاح صوت مجهول لا يُسقط اللعبة")
	Audio.stop_all()
	_true("الإيقاف يعمل", not Audio._music.playing and not Audio._ambient.playing)

# ---------- كاشف التفاعل ----------
func _test_interactor() -> void:
	print("\n[كاشف التفاعل]")
	var holder := Node3D.new()
	add_child(holder)

	var it := Interactor.new()
	it.set_process(false)
	holder.add_child(it)
	it.global_position = Vector3.ZERO

	var front := Interactable.new()
	front.prompt = "أمامك"
	holder.add_child(front)
	front.global_position = Vector3(0, 0, -2.0)   # -Z هو الأمام

	var behind := Interactable.new()
	behind.prompt = "خلفك"
	holder.add_child(behind)
	behind.global_position = Vector3(0, 0, 2.0)

	var far := Interactable.new()
	far.prompt = "بعيد"
	holder.add_child(far)
	far.global_position = Vector3(0, 0, -40.0)

	it._scan()
	_true("يلتقط الهدف الأمامي", it.current == front,
		"التقط: %s" % (it.current.prompt if it.current else "لا شيء"))

	front.enabled = false
	it._scan()
	_true("يتجاهل المعطّل والخلفي والبعيد", it.current == null,
		"التقط: %s" % (it.current.prompt if it.current else "لا شيء"))

	front.enabled = true
	it._scan()
	_true("يعود عند التفعيل", it.current == front)
	holder.queue_free()

# ---------- الالتقاط ----------
func _test_pickup() -> void:
	print("\n[الالتقاط]")
	SaveSystem.start_new_game()
	Inv._sync_from_save()

	var p := Pickup.new()
	p.item_id = "pendant"
	add_child(p)
	_true("النص يذكر اسم الغرض", p.get_prompt().contains("قلادة"), p.get_prompt())
	_true("قابل للاستعمال", p.can_use())

	p.use(null)
	_true("دخل الحقيبة", Inv.has("pendant"))
	_true("لا يُستعمل مرتين", not p.can_use())
	_true("سُجّل العلم في الحفظ",
		bool(SaveSystem.data.get("flags", {}).get("picked_pendant", false)))

	var before := Inv.total_collected()
	p.use(null)
	_eq("الاستعمال الثاني لا يضيف شيئاً", Inv.total_collected(), before)
	p.queue_free()

# ---------- الأبواب ----------
func _test_door() -> void:
	print("\n[البوابة المقفلة]")
	SaveSystem.start_new_game()
	Inv._sync_from_save()

	var d := DoorGate.new()
	d.required_item = "old_key"
	d.locked_prompt = "مقفل"
	var leaf := Node3D.new()
	leaf.name = "Leaf"
	d.add_child(leaf)
	add_child(d)

	_eq("بلا مفتاح: النص مقفل", d.get_prompt(), "مقفل")
	var refused := [false]
	d.refused.connect(func(_r: String) -> void: refused[0] = true)
	d.use(null)
	_true("بلا مفتاح: لا تُفتح", refused[0])
	_true("ما زالت قابلة للاستعمال", d.can_use())

	Inv.add("old_key")
	_eq("بالمفتاح: النص افتح", d.get_prompt(), "افتح")
	var opened := [false]
	d.opened.connect(func() -> void: opened[0] = true)
	d.use(null)
	_true("بالمفتاح: تُفتح", opened[0])
	_true("لا تُفتح مرتين", not d.can_use())
	d.queue_free()

# ---------- الفصل الأول ----------
func _test_chapter_one() -> void:
	print("\n[الفصل الأول: الغابة المنسية]")
	var path := "res://levels/ch01_forest/chapter_one.tscn"
	if not ResourceLoader.exists(path):
		_no("مشهد الفصل موجود", path)
		return
	SaveSystem.start_new_game()
	Inv._sync_from_save()

	var packed: PackedScene = load(path)
	var lvl := packed.instantiate() as GameLevel
	if lvl == null:
		_no("المشهد من نوع GameLevel")
		return
	add_child(lvl)
	await get_tree().process_frame

	_true("اللاعب موجود", lvl.player != null)
	_true("الكاميرا موجودة", lvl.cam != null)
	_true("الواجهة موجودة", lvl.hud != null)
	_true("كاشف التفاعل مركّب", lvl.interactor != null)
	_true("الحقيبة متصلة بالواجهة", lvl.inventory_ui != null)

	var cam3d := lvl.cam.get_camera() if lvl.cam else null
	_true("كاميرا 3D فعلية", cam3d is Camera3D)

	var lights := _count_of(lvl, "Light3D")
	_true("إضاءة كافية (%d مصدر)" % lights, lights >= 5)

	var inter := get_tree().get_nodes_in_group("interactable")
	_true("عناصر تفاعل موزّعة (%d)" % inter.size(), inter.size() >= 5)

	var trees := _find_named(lvl, "NearTrees")
	_true("أشجار قريبة بتصادم (%d)" % (trees.get_child_count() if trees else 0),
		trees != null and trees.get_child_count() >= 30)

	var gate := _find_named(lvl, "AncientGate")
	_true("البوابة الأثرية موجودة", gate != null)

	_true("نقطة البداية فوق الأرض", lvl.player.position.y > 0.5)
	_true("الفصل سُجّل في الحفظ", int(SaveSystem.data.get("chapter", 0)) == 1)
	_true("الفصل 1 بقي مفتوحاً", SaveSystem.is_chapter_unlocked(1))
	_true("نص الهدف ظاهر", Goals.current_text.strip_edges() != "")

	# فيزياء حقيقية: اللاعب يسقط ويستقر على الأرض
	var y0: float = lvl.player.global_position.y
	for i in 40:
		await get_tree().physics_frame
	var y1: float = lvl.player.global_position.y
	_true("اللاعب يستقر على الأرض (%.2f ← %.2f)" % [y0, y1],
		lvl.player.is_on_floor() and y1 > -1.0 and y1 < y0 + 0.6)

	# حركة حقيقية: إدخال للأمام يغيّر الموقع
	var p0: Vector3 = lvl.player.global_position
	lvl.player.set_move_input(Vector2(0, -1))
	for i in 30:
		await get_tree().physics_frame
	lvl.player.set_move_input(Vector2.ZERO)
	var moved: float = Vector2(lvl.player.global_position.x - p0.x,
		lvl.player.global_position.z - p0.z).length()
	_true("الإدخال يحرّك اللاعب (%.2f م)" % moved, moved > 0.8)

	lvl.queue_free()

# ---------- توزيع المرحلة ----------
## خادم العرض الوهمي يُهمل بيانات MultiMesh فلا تُقرأ مواضع الأشجار منه.
## لذلك يحفظها الباني كبيانات وصفية، وهنا يُختبر التوزيع نفسه:
## الممر سالك، والأشجار كثيفة، والفوانيس والأغراض على الطريق.
func _test_level_layout() -> void:
	print("\n[توزيع الغابة]")
	var packed: PackedScene = load("res://levels/ch01_forest/chapter_one.tscn")
	var lvl := packed.instantiate() as ChapterOne
	add_child(lvl)
	await get_tree().process_frame

	var pts := lvl._path_points()
	_true("للممر نقاط كافية (%d)" % pts.size(), pts.size() >= 5)

	var field := _find_named(lvl, "TreeField")
	_true("حقل الأشجار موجود", field != null)
	var spots: Array = field.get_meta("spots", []) if field else []
	_true("غابة كثيفة (%d شجرة بصرية)" % spots.size(), spots.size() >= 380)

	var near := _find_named(lvl, "NearTrees")
	var solid := near.get_child_count() if near else 0
	_true("أشجار صلبة على الطريق (%d)" % solid, solid >= 40)

	# لا شجرة تسدّ الممر
	var blocking := 0
	var closest := INF
	for v in spots:
		var d := lvl._dist_to_path(v)
		closest = minf(closest, d)
		if d < 2.6:
			blocking += 1
	if near:
		for c in near.get_children():
			var d := lvl._dist_to_path((c as Node3D).position)
			closest = minf(closest, d)
			if d < 2.6:
				blocking += 1
	_eq("لا شجرة تسدّ الممر", blocking, 0)
	_true("أقرب شجرة %.1f م عن المحور" % closest, closest >= 2.6)

	# الأشجار الصلبة موزّعة على طول الممر لا متكدّسة عند البداية
	if near and solid > 0:
		var zmin := INF
		var zmax := -INF
		for c in near.get_children():
			var z: float = (c as Node3D).position.z
			zmin = minf(zmin, z)
			zmax = maxf(zmax, z)
		var span := zmax - zmin
		_true("موزّعة على طول الممر (%.0f م)" % span, span >= 40.0)

	# الفوانيس ترشد: كلها قريبة من الممر
	var lanterns := _find_named(lvl, "Lanterns")
	var far_lantern := 0
	if lanterns:
		for c in lanterns.get_children():
			if lvl._dist_to_path((c as Node3D).position) > 4.0:
				far_lantern += 1
	_eq("كل الفوانيس على الطريق", far_lantern, 0)

	# كل عنصر تفاعل في متناول الماشي على الممر
	var stray := 0
	for n in get_tree().get_nodes_in_group("interactable"):
		if lvl._dist_to_path((n as Node3D).position) > 8.0:
			stray += 1
			print("    بعيد: ", n.name)
	_eq("كل الأغراض قرب الممر", stray, 0)

	var bounds := _find_named(lvl, "Bounds")
	_true("حدود المرحلة موجودة", bounds != null)
	_eq("أربعة جدران", bounds.get_child_count() if bounds else 0, 4)

	lvl.queue_free()

func _count_of(root: Node, cls: String) -> int:
	var n := 0
	if root.is_class(cls):
		n += 1
	for c in root.get_children():
		n += _count_of(c, cls)
	return n

func _find_named(root: Node, nm: String) -> Node:
	if root.name == nm:
		return root
	for c in root.get_children():
		var f := _find_named(c, nm)
		if f != null:
			return f
	return null
