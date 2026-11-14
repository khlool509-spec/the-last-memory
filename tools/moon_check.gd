extends Node
## فحص مستوى القمر داخل شجرة حيّة.
## يفصل عن مُشغّل الاختبارات لأن `_ready` لا يعمل على عقد تُضاف
## داخل `_initialize`، فتبدو العناصر المبنية فيه كأنها لم تُبنَ.

var _fail := 0
var _pass := 0

func _ok(t: String) -> void:
	_pass += 1
	print("  PASS  ", t)

func _no(t: String, d: String = "") -> void:
	_fail += 1
	print("  FAIL  ", t, ("  ->  " + d) if d != "" else "")

func _ready() -> void:
	print("=== فحص مستوى القمر ===")
	await _check_terrain_build()
	await _check_level()
	print("\n=== القمر: %s (%d نجح، %d أخفق) ===" % [
		"سليم" if _fail == 0 else "%d مشكلة" % _fail, _pass, _fail])
	get_tree().quit(_fail)

# ---------------------------------------------------------------- التضاريس

func _check_terrain_build() -> void:
	print("\n[شبكة السطح والتصادم]")
	var t := MoonTerrain.new(20261114)
	add_child(t)
	await get_tree().process_frame

	var mi := t.get_mesh_instance()
	if mi != null and mi.mesh != null and mi.mesh.get_surface_count() == 1:
		_ok("الشبكة مبنية (%d مثلث)" % t.triangle_count())
	else:
		_no("بناء الشبكة")
		t.queue_free()
		return

	# رؤوس الشبكة يجب أن تطابق دالة الارتفاع بالضبط، وإلا طفا اللاعب أو غاص
	var arrays := mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var worst := 0.0
	for i in range(0, verts.size(), 97):
		var v := verts[i]
		worst = maxf(worst, absf(v.y - t.height_at(v.x, v.z)))
	if worst < 0.001:
		_ok("كل رأس مطابق لدالة الارتفاع")
	else:
		_no("انحراف الرؤوس", "%.4f م" % worst)

	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bad_n := 0
	for i in range(0, normals.size(), 53):
		if absf(normals[i].length() - 1.0) > 0.01 or normals[i].y <= 0.0:
			bad_n += 1
	if bad_n == 0:
		_ok("النواظم مطبّعة ومتجهة للأعلى")
	else:
		_no("نواظم خاطئة", str(bad_n))

	var col: CollisionShape3D = t.get_node_or_null("SurfaceCollision")
	if col != null and col.shape is ConcavePolygonShape3D:
		var faces: PackedVector3Array = (col.shape as ConcavePolygonShape3D).get_faces()
		if faces.size() == t.triangle_count() * 3:
			_ok("التصادم مطابق للشبكة (%d رأس)" % faces.size())
		else:
			_no("حجم التصادم", "%d رأساً" % faces.size())
	else:
		_no("شكل التصادم")
	t.queue_free()

# ---------------------------------------------------------------- المستوى

func _check_level() -> void:
	print("\n[ربط المستوى]")
	var packed: PackedScene = ResourceLoader.load("res://levels/moon/moon_surface.tscn")
	if packed == null:
		_no("تحميل مشهد القمر")
		return
	var lvl := packed.instantiate()
	add_child(lvl)
	await get_tree().process_frame

	if lvl.terrain != null and lvl.player != null and lvl.cam != null and lvl.hud != null:
		_ok("التضاريس واللاعب والكاميرا والواجهة مبنية")
	else:
		_no("بناء العناصر الأساسية")
		lvl.queue_free()
		return

	var gy: float = lvl.terrain.height_at(lvl.player.position.x, lvl.player.position.z)
	var dy: float = lvl.player.position.y - gy
	if dy >= 0.0 and dy < 2.0:
		_ok("اللاعب يبدأ على السطح (%.2f م فوقه)" % dy)
	else:
		_no("موضع البداية", "%.2f م" % dy)

	if is_equal_approx(lvl.player.get_gravity_value(), 3.2):
		_ok("جاذبية المستوى قمرية (%.2f م/ث²)" % lvl.player.get_gravity_value())
	else:
		_no("جاذبية المستوى", str(lvl.player.get_gravity_value()))

	if lvl.life != null and lvl.missions != null and lvl.detector != null:
		_ok("دعم الحياة والمهام وكاشف التفاعل موصولة")
	else:
		_no("ربط الأنظمة")

	if lvl.missions.missions.size() == 5:
		_ok("خمس مهام محمّلة")
	else:
		_no("عدد المهام", str(lvl.missions.missions.size()))
	var cur: Mission = lvl.missions.current()
	if cur != null and cur.state == Mission.State.ACTIVE:
		_ok("المهمة النشطة: %s" % cur.title)
	else:
		_no("المهمة النشطة")

	# كل هدف مهمة يجب أن يقابله شيء في العالم، وإلا صارت المهمة مستحيلة
	var ids := {}
	for node in get_tree().get_nodes_in_group("interactables"):
		ids[(node as Interactable).interact_id] = true
	var markers := {}
	for ch in lvl.get_children():
		if ch is ObjectiveMarker:
			markers[(ch as ObjectiveMarker).marker_id] = true
	var missing: Array[String] = []
	for m in lvl.missions.missions:
		var tid: String = m.target_id
		if not ids.has(tid) and not markers.has(tid):
			missing.append(m.id)
	if missing.is_empty():
		_ok("كل مهمة لها هدف موجود في العالم")
	else:
		_no("أهداف بلا وجود", ", ".join(missing))

	var samples := 0
	for node in get_tree().get_nodes_in_group("interactables"):
		if (node as Interactable).interact_id == "sample":
			samples += 1
	var need := 0
	for m in lvl.missions.missions:
		if m.id == "samples":
			need = m.required
	if need > 0 and samples >= need:
		_ok("العيّنات في العالم %d والمطلوب %d" % [samples, need])
	else:
		_no("نقص العيّنات", "%d موجودة و %d مطلوبة" % [samples, need])

	var station_ok := false
	for node in get_tree().get_nodes_in_group("interactables"):
		var it := node as Interactable
		if it.interact_id == "oxygen_station":
			station_ok = not it.once
	if station_ok:
		_ok("محطة الأكسجين قابلة للتكرار")
	else:
		_no("محطة الأكسجين")

	# المنارة النشطة يجب أن تكون مرئية والبقية مخفية
	var visible_markers := 0
	for ch in lvl.get_children():
		if ch is ObjectiveMarker and (ch as ObjectiveMarker).visible:
			visible_markers += 1
	if visible_markers == 1:
		_ok("منارة واحدة ظاهرة فقط")
	else:
		_no("عدد المنارات الظاهرة", str(visible_markers))

	# تسلسل كامل: إنهاء المهام الخمس برمجياً يجب أن يصل إلى النهاية
	var ms: MissionSystem = lvl.missions
	ms.report(Mission.Kind.REACH, "first_steps")
	for i in need:
		ms.report(Mission.Kind.COLLECT, "sample")
	ms.report(Mission.Kind.INTERACT, "antenna")
	ms.report(Mission.Kind.REACH, "great_crater")
	ms.report(Mission.Kind.RETURN, "lander")
	if ms.is_finished() and ms.completed_count() == 5:
		_ok("المتتالية كاملة قابلة للإنهاء من البداية للنهاية")
	else:
		_no("إنهاء المتتالية", "%d من 5 عند الفهرس %d" % [ms.completed_count(), ms.current_index()])

	# الشيدر يُحمَّل فعلاً: السقوط للاحتياطي يعني سماء ميتة بلا نجوم
	var sh := ResourceLoader.load("res://assets/shaders/moon_sky.gdshader")
	if sh != null and sh is Shader:
		_ok("شيدر سماء القمر يُحمَّل")
	else:
		_no("تحميل شيدر السماء")

	lvl.queue_free()
