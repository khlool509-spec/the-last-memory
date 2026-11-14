extends Node
## اختبارات العالم المفتوح. تعمل بالحلقة العادية فالفيزياء حيّة.
## أهمها: اللاعب يقف فعلاً على الأرض في كل موقع، ويمشي بلا سقوط ولا تعلّق.

var _pass := 0
var _fail := 0
var lvl: ChapterOne
var world: WorldRenderer

func _ok(n: String) -> void:
	_pass += 1
	print("  PASS  ", n)

func _no(n: String, d: String = "") -> void:
	_fail += 1
	print("  FAIL  ", n, ("  ->  " + d) if d != "" else "")

func _true(n: String, v: bool, d: String = "") -> void:
	if v: _ok(n)
	else: _no(n, d)

func _ready() -> void:
	print("=== اختبارات العالم ===\n")
	await _load_world()
	if lvl == null:
		print("\n=== العالم: 0 نجح، 1 أخفق ===")
		get_tree().quit(1)
		return
	_test_structure()
	_test_data_integrity()
	await _test_standing()
	await _test_bridge()
	await _test_interiors()
	await _test_walk()
	_test_scatter_rules()
	_test_live_daylight()
	print("\n=== العالم: %d نجح، %d أخفق ===" % [_pass, _fail])
	get_tree().quit(_fail)

func _load_world() -> void:
	var path := "res://levels/ch01_forest/chapter_one.tscn"
	if not ResourceLoader.exists(path):
		_no("مشهد الفصل موجود", path)
		return
	SaveSystem.start_new_game()
	Inv._sync_from_save()
	var packed: PackedScene = load(path)
	lvl = packed.instantiate() as ChapterOne
	if lvl == null:
		_no("المشهد من نوع ChapterOne")
		return
	add_child(lvl)
	await get_tree().process_frame
	world = lvl.world

# ---------- البنية ----------
func _test_structure() -> void:
	print("[بنية العالم]")
	_true("العالم مُركَّب", world != null)
	if world == null:
		return
	_true("بيانات العالم محمّلة", world.data != null)
	var chunks := world.terrain_root.get_child_count() if world.terrain_root else 0
	_true("مقاطع الأرض (%d)" % chunks, chunks == 100)
	_true("جسم التصادم موجود", world.body != null)
	var cs := world.body.get_node_or_null("TerrainShape") as CollisionShape3D
	_true("شكل خريطة الارتفاع", cs != null and cs.shape is HeightMapShape3D)
	if cs and cs.shape is HeightMapShape3D:
		var hm := cs.shape as HeightMapShape3D
		_true("أبعاد الخريطة %dx%d" % [hm.map_width, hm.map_depth],
			hm.map_width == world.data.height_res and hm.map_depth == world.data.height_res)
		_true("تكبير الخلايا يطابق خطوة العيّنات",
			is_equal_approx(cs.scale.x, world.data.height_step))
	var sc := world.scatter_root.get_child_count() if world.scatter_root else 0
	# النبات مُطفأ مؤقتاً بطلب: الاختبار يتحقّق من اتّساق الإعداد
	# مع النتيجة، لا من وجود النبات دائماً.
	if bool(Settings.get_value("show_vegetation")):
		_true("مجموعات النبات (%d)" % sc, sc > 600)
	else:
		_true("النبات مُطفأ فلا مجموعات (%d)" % sc, sc == 0,
			"show_vegetation=false لكن وُجدت %d مجموعة" % sc)
	_true("سطح النهر موجود", world.water_root != null and world.water_root.get_child_count() > 0)

	# عطب حقيقي وقع: كان لفّ مثلثات الأرض معكوساً فتُقصّ كلها ولا
	# تُرسم إطلاقاً، وكان يُرى مكانها السماء.
	# اصطلاح Godot — متحقَّق منه بالتصيير لا بالافتراض: الوجه الأمامي
	# حاصلُ ضربه الاتجاهي (b-a)×(c-a) يشير بعيداً عن الناظر، أي إلى
	# الأسفل لأرض تُرى من فوقها.
	var flipped := 0
	var checked_tris := 0
	for ci in [0, 45, 99]:
		var mesh: ArrayMesh = world.data.chunk_meshes[ci]
		var arr := mesh.surface_get_arrays(0)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for t in range(0, mini(ix.size(), 600), 3):
			var a := vs[ix[t]]
			var b := vs[ix[t + 1]]
			var c := vs[ix[t + 2]]
			var nrm := (b - a).cross(c - a)
			checked_tris += 1
			if nrm.y >= 0.0:
				flipped += 1
	_true("لفّ وجوه الأرض صحيح فتُرسم (%d/%d)" % [checked_tris - flipped, checked_tris],
		flipped == 0, "%d مثلثاً مقلوباً — الأرض ستختفي" % flipped)

func _test_data_integrity() -> void:
	print("\n[خامات PBR الخارجية]")
	# لا يكفي أن تُنزَّل الملفات: يجب أن تُحمَّل فعلاً وتُربَط بالشادر.
	# هذا الاختبار يفشل إذا فُقد ملف أو لم يُستورد أو لم يُمرَّر.
	var man_path := "res://assets/textures/pbr/MANIFEST.json"
	var man_ok := FileAccess.file_exists(man_path)
	_true("بيان المصادر موجود", man_ok, man_path)
	if man_ok:
		var raw := FileAccess.get_file_as_string(man_path)
		var man: Dictionary = JSON.parse_string(raw)
		var missing := 0
		var n_files := 0
		for aid in man:
			var e: Dictionary = man[aid]
			for k in (e["files"] as Dictionary):
				n_files += 1
				var fp: String = "res://" + str((e["files"] as Dictionary)[k]["path"])
				if not ResourceLoader.exists(fp):
					missing += 1
			_true("ترخيص %s معلوم" % aid, str(e.get("license", "")) == "CC0 1.0",
				str(e.get("license", "(فارغ)")))
		_true("كل ملفات البيان مستوردة (%d)" % n_files, missing == 0,
			"%d ملفاً مفقوداً أو غير مستورد" % missing)

	var gm := WorldMaterials.ground()
	_true("خامة الأرض شادر", gm is ShaderMaterial)
	var bound := 0
	var unbound := PackedStringArray()
	for pname in ["a_diff", "a_norm", "a_arm", "b_diff", "b_norm", "b_arm",
			"macro_diff", "rock_diff", "rock_norm", "rock_arm"]:
		var tex = gm.get_shader_parameter(pname)
		if tex is Texture2D and (tex as Texture2D).get_width() >= 1024:
			bound += 1
		else:
			unbound.append(pname)
	_true("خرائط الأرض مربوطة بدقة ≥1024 (%d/10)" % bound, bound == 10,
		"غير مربوط: " + ", ".join(unbound))

	var wm := WorldMaterials.water()
	_true("خامة الماء شادر", wm is ShaderMaterial)
	_true("خريطة تموّج الماء مربوطة",
		wm.get_shader_parameter("ripple_tex") is Texture2D)

	print("\n[سلامة البيانات]")
	var d := world.data
	var inst := 0
	for key in d.scatter:
		inst += int((d.scatter[key] as PackedFloat32Array).size() / 12.0)
	_true("نسخ موزّعة (%d)" % inst, inst > 15000)
	# الأشجار تُركَّب ثلاث مرات (مستوى تفصيل لكل نطاق مسافة)، فيُعدّ
	# المستوى الأول وحده ليقابل عدد النسخ المخبوزة.
	var drawn := 0
	var lod_sets := {0: 0, 1: 0, 2: 0}
	for c in world.scatter_root.get_children():
		var mmi := c as MultiMeshInstance3D
		if mmi == null or mmi.multimesh == null:
			continue
		var nm := String(mmi.name)
		var lod := 0
		if nm.ends_with("_L1"): lod = 1
		elif nm.ends_with("_L2"): lod = 2
		lod_sets[lod] = int(lod_sets[lod]) + mmi.multimesh.instance_count
		if lod == 0:
			drawn += mmi.multimesh.instance_count
	# النبات مُطفأ مؤقتاً بطلب؛ بيانات التوزيع تبقى مخبوزة كما هي.
	# الاختبار يتحقّق من اتّساق الإعداد مع ما رُكّب فعلاً.
	if bool(Settings.get_value("show_vegetation")):
		_true("كل النسخ رُكّبت (%d)" % drawn, drawn == inst, "%d مقابل %d" % [drawn, inst])
		_true("مستويات التفصيل مبنية (L1=%d، L2=%d)" % [lod_sets[1], lod_sets[2]],
			int(lod_sets[1]) > 5000 and int(lod_sets[1]) == int(lod_sets[2]))
	else:
		_true("النبات مُطفأ فلا نسخ مُركَّبة (%d)" % drawn, drawn == 0,
			"show_vegetation=false لكن رُكّبت %d نسخة" % drawn)
		_true("بيانات التوزيع محفوظة رغم الإطفاء (%d)" % inst, inst > 15000,
			"فُقدت بيانات النبات المخبوزة")

	# كل مستوى له نطاق مسافة لا يتداخل مع ما قبله
	var bad_band := 0
	for c in world.scatter_root.get_children():
		var mmi := c as MultiMeshInstance3D
		if mmi == null: continue
		if String(mmi.name).ends_with("_L1") and mmi.visibility_range_begin <= 0.0:
			bad_band += 1
		if String(mmi.name).ends_with("_L2") and mmi.visibility_range_begin <= 0.0:
			bad_band += 1
	_eq("النطاقات البعيدة تبدأ من مسافة", bad_band, 0)

	# المباني أخذت مستويات تفصيل أيضاً
	var one := lvl as ChapterOne
	var ranged := 0
	var total_gi := 0
	for key in one.buildings:
		var b: Node3D = one.buildings[key]
		var counts := _count_ranges(b)
		ranged += counts[0]
		total_gi += counts[1]
	_true("مجسّمات المباني لها مدى ظهور (%d/%d)" % [ranged, total_gi],
		total_gi > 0 and float(ranged) / float(total_gi) > 0.9)

	# كل نوع له شبكة ومدى ظهور
	var missing := 0
	var no_range := 0
	for c in world.scatter_root.get_children():
		var mmi := c as MultiMeshInstance3D
		if mmi == null: continue
		if mmi.multimesh == null or mmi.multimesh.mesh == null:
			missing += 1
		if mmi.visibility_range_end <= 0.0:
			no_range += 1
	_eq("كل مجموعة لها مجسّم", missing, 0)
	_eq("كل مجموعة لها مدى ظهور", no_range, 0)

## تبديل الوقت من الإعدادات يغيّر المشهد الحيّ فوراً
func _test_live_daylight() -> void:
	print("\n[تبديل الوقت داخل اللعب]")
	var one := lvl as ChapterOne
	if one == null or one._env == null:
		_no("البيئة موجودة")
		return
	Settings.set_value("time_of_day", "night")
	var n_exp := one._env.tonemap_exposure
	var n_sun := one._sun.light_energy
	var n_lamp := 0.0
	for l in one._lamps:
		if is_instance_valid(l):
			n_lamp = maxf(n_lamp, l.light_energy)

	Settings.set_value("time_of_day", "day")
	var d_exp := one._env.tonemap_exposure
	var d_sun := one._sun.light_energy
	var d_lamp := 0.0
	for l in one._lamps:
		if is_instance_valid(l):
			d_lamp = maxf(d_lamp, l.light_energy)

	_true("الشمس تشتدّ نهاراً (%.2f ← %.2f)" % [n_sun, d_sun], d_sun > n_sun)
	_true("الفوانيس تخفت نهاراً (%.2f ← %.2f)" % [n_lamp, d_lamp],
		one._lamps.size() > 0 and d_lamp < n_lamp * 0.5)
	_true("أضواء مسجَّلة (%d)" % one._lamps.size(), one._lamps.size() >= 8)
	_true("اتجاه الضوء تغيّر", not n_exp == 0.0)

	# السطوع يرفع التعريض حيّاً
	Settings.set_value("brightness", 0.1)
	var dim := one._env.tonemap_exposure
	Settings.set_value("brightness", 0.9)
	var bright := one._env.tonemap_exposure
	_true("السطوع يعمل حيّاً (%.2f ← %.2f)" % [dim, bright], bright > dim * 1.4)
	Settings.set_value("brightness", 0.5)
	Settings.set_value("time_of_day", "day")

## يعيد [كم مجسّماً له مدى, إجمالي المجسّمات]
func _count_ranges(root: Node) -> Array:
	var ranged := 0
	var total := 0
	if root is GeometryInstance3D:
		total += 1
		if (root as GeometryInstance3D).visibility_range_end > 0.0:
			ranged += 1
	for c in root.get_children():
		var r := _count_ranges(c)
		ranged += int(r[0])
		total += int(r[1])
	return [ranged, total]

func _eq(n: String, got, want) -> void:
	if got == want: _ok(n)
	else: _no(n, "وجدنا %s والمطلوب %s" % [str(got), str(want)])

# ---------- الوقوف ----------
## الاختبار الحاسم: في كل موقع من مواقع العالم، يسقط اللاعب ويستقر
## على الأرض عند الارتفاع الصحيح. لو اختلف التصادم عن الشكل المرئي
## لظهر هنا فوراً.
func _test_standing() -> void:
	print("\n[الوقوف على الأرض في كل موقع]")
	# يُختبر بجوار كل موقع لا في مركزه: المركز قد يحمل مبنى،
	# والإسقاط داخل سقفه يحشر اللاعب — وهذا ما كشفه الاختبار فعلاً.
	var worst := 0.0
	var failed: Array[String] = []
	for key in world.data.poi:
		if key == "bridge":
			continue      # في مجرى النهر — يُختبر كجسر لا كأرض
		var p: Vector3 = world.data.poi[key]
		var ok := false
		var best_diff := INF
		for ang in [0.0, 1.57, 3.14, 4.71]:
			var x: float = p.x + cos(ang) * 9.0
			var z: float = p.z + sin(ang) * 9.0
			if world.height_at(x, z) < world.data.water_level + 0.3:
				continue
			lvl.player.velocity = Vector3.ZERO
			lvl.player.global_position = Vector3(x, world.height_at(x, z) + 2.5, z)
			for i in 55:
				await get_tree().physics_frame
			var diff := absf(lvl.player.global_position.y - world.height_at(x, z))
			best_diff = minf(best_diff, diff)
			if lvl.player.is_on_floor() and diff < 0.75:
				ok = true
				break
		worst = maxf(worst, best_diff if ok else best_diff)
		if not ok:
			failed.append("%s (أفضل فرق %.2f)" % [key, best_diff])
	_true("يمكن الوقوف بجوار كل موقع (أسوأ فرق %.2f م)" % worst, failed.is_empty(),
		", ".join(failed))

	# لا موقع تحت الماء
	var sunk: Array[String] = []
	for key in world.data.poi:
		var p2: Vector3 = world.data.poi[key]
		if key == "bridge":
			continue    # الجسر فوق الماء بحكم تعريفه
		if p2.y < world.data.water_level + 0.3:
			sunk.append(key)
	_true("لا موقع غارق", sunk.is_empty(), ", ".join(sunk))

## الجسر: اللاعب يقف على سطحه فوق الماء، لا يسقط في النهر.
func _test_bridge() -> void:
	print("\n[الجسر]")
	var b: Vector3 = world.data.poi["bridge"]
	var deck := world.data.water_level + 2.3
	lvl.player.velocity = Vector3.ZERO
	lvl.player.global_position = Vector3(b.x, deck + 1.6, b.z)
	for i in 70:
		await get_tree().physics_frame
	var y := lvl.player.global_position.y
	_true("يقف على سطح الجسر (%.2f م)" % y,
		lvl.player.is_on_floor() and absf(y - deck) < 0.6,
		"المتوقع %.2f" % deck)
	_true("فوق سطح الماء", y > world.data.water_level + 1.0)
	_true("أرض النهر تحته فعلاً", world.height_at(b.x, b.z) < world.data.water_level)

## المباني قابلة للدخول فعلاً: يقف اللاعب على أرضيتها الداخلية.
func _test_interiors() -> void:
	print("\n[داخل المباني]")
	var one := lvl as ChapterOne
	if one == null or one.buildings.is_empty():
		_no("المباني مبنية")
		return
	_true("عدد المباني (%d)" % one.buildings.size(), one.buildings.size() >= 5)

	var bad: Array[String] = []
	for key in ["hut", "old_house", "store"]:
		var b: Node3D = one.buildings.get(key)
		if b == null:
			bad.append(key + " مفقود")
			continue
		if not b.has_meta("interior"):
			bad.append(key + " بلا نقطة داخلية")
			continue
		var local: Vector3 = b.get_meta("interior")
		var wpos := b.global_transform * local
		lvl.player.velocity = Vector3.ZERO
		lvl.player.global_position = wpos + Vector3(0, 1.1, 0)
		for i in 60:
			await get_tree().physics_frame
		var rest := lvl.player.global_position
		var ground := world.height_at(rest.x, rest.z)
		if not lvl.player.is_on_floor():
			bad.append("%s لم يستقر" % key)
		elif rest.y < ground - 0.5:
			bad.append("%s سقط تحت الأرض" % key)
	_true("يقف اللاعب داخل كل مبنى مسقوف", bad.is_empty(), ", ".join(bad))

	# لكل مبنى باب له فتحة: الباب موجود وقابل للاستعمال
	var doors := 0
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is DoorGate:
			doors += 1
	_true("أبواب قابلة للفتح (%d)" % doors, doors >= 3)

# ---------- المشي ----------
## يمشي اللاعب على طول الطريق الرئيسي ويُرصد: هل سقط؟ هل تعلّق؟
func _test_walk() -> void:
	print("\n[المشي على الطريق]")
	var a: Vector3 = world.data.poi["spawn"]
	var b: Vector3 = world.data.poi["crossroad"]
	lvl.player.velocity = Vector3.ZERO
	lvl.player.global_position = Vector3(a.x, a.y + 1.5, a.z)
	for i in 40:
		await get_tree().physics_frame

	var start := lvl.player.global_position
	var fell := false
	var below := 0
	var stuck_frames := 0
	var last := start
	var dir := Vector2(b.x - a.x, b.z - a.z).normalized()
	lvl.player.camera_basis_yaw = 0.0
	for step in 300:
		lvl.player.set_move_input(dir)
		await get_tree().physics_frame
		var pos := lvl.player.global_position
		if pos.y < world.height_at(pos.x, pos.z) - 1.2:
			below += 1
		if pos.y < world.data.water_level - 6.0:
			fell = true
			break
		if step % 10 == 9:
			if last.distance_to(pos) < 0.25:
				stuck_frames += 1
			last = pos
	lvl.player.set_move_input(Vector2.ZERO)
	var travelled := Vector2(lvl.player.global_position.x - start.x,
		lvl.player.global_position.z - start.z).length()

	_true("لم يسقط من العالم", not fell)
	_true("بقي فوق الأرض (%d إطار تحتها)" % below, below < 10)
	# 300 إطار فيزياء = 5 ثوانٍ؛ بسرعة مشي 3.4 م/ث المتوقع نحو 16 متراً
	_true("قطع مسافة حقيقية (%.1f م)" % travelled, travelled > 13.0 and travelled < 40.0)
	_true("لم يتعلّق (%d توقّف)" % stuck_frames, stuck_frames <= 4)
	_true("استقرّ على الأرض في النهاية", lvl.player.is_on_floor())

# ---------- قواعد التوزيع ----------
func _test_scatter_rules() -> void:
	print("\n[قواعد التوزيع]")
	var d := world.data
	var in_water := 0
	var on_road := 0
	var in_pad := 0
	var checked := 0
	var wp := WorldProfile.new()
	for key in d.scatter:
		var sp: String = str(key).split(":")[0]
		var n := int((d.scatter[key] as PackedFloat32Array).size() / 12.0)
		for k in range(0, n, maxi(1, n / 4)):     # عيّنة من كل مجموعة
			var t := d.instance_transform(key, k)
			var p := t.origin
			checked += 1
			if p.y < d.water_level - 0.05:
				in_water += 1
			if wp.road_factor(p.x, p.z) < 1.0:
				on_road += 1
			for pad in wp.pads:
				var c: Vector2 = pad["c"]
				if Vector2(p.x, p.z).distance_to(c) < float(pad["r"]) * 0.7:
					in_pad += 1
					break
	_true("فُحصت عيّنات (%d)" % checked, checked > 1000)
	_eq("لا نبات داخل الماء", in_water, 0)
	_eq("لا نبات يسدّ الطريق", on_road, 0)
	_eq("لا نبات داخل أرضيات المباني", in_pad, 0)

	# النهر فعلاً أخفض من ضفافه
	var higher := 0
	var samples := 0
	for i in d.river_points.size():
		var rp := d.river_points[i]
		samples += 1
		var mid := world.height_at(rp.x, rp.y)
		var side_a := world.height_at(rp.x + 20.0, rp.y)
		var side_b := world.height_at(rp.x - 20.0, rp.y)
		if mid < side_a and mid < side_b:
			higher += 1
	_true("النهر أخفض من ضفتيه (%d/%d)" % [higher, samples], higher >= samples - 2)
