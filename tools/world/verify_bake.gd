extends SceneTree
func _initialize() -> void:
	var d: WorldData = ResourceLoader.load("res://levels/ch01_forest/baked/world.res")
	if d == null:
		push_error("لم يُحمَّل"); quit(1); return
	print("مقاطع: ", d.chunk_meshes.size())
	var tris := 0
	var empty := 0
	for m in d.chunk_meshes:
		if m == null or m.get_surface_count() == 0:
			empty += 1
			continue
		tris += m.surface_get_array_index_len(0) / 3
	print("مثلثات محفوظة: %d  |  مقاطع فارغة: %d" % [tris, empty])
	print("خريطة الارتفاع: %d قيمة (المتوقع %d)" % [d.height_map.size(), d.height_res * d.height_res])
	var lo := INF; var hi := -INF
	for v in d.height_map:
		lo = minf(lo, v); hi = maxf(hi, v)
	print("مدى الارتفاع المحفوظ: %.2f .. %.2f" % [lo, hi])
	var total := 0
	var per := {}
	for key in d.scatter:
		var sp: String = str(key).split(":")[0]
		var n := int((d.scatter[key] as PackedFloat32Array).size() / 12.0)
		total += n
		per[sp] = int(per.get(sp, 0)) + n
	print("نسخ محفوظة: ", total)
	var keys := per.keys(); keys.sort()
	for k in keys:
		print("   %-10s %5d" % [k, per[k]])
	# تحقق: الاستيفاء من خريطة التصادم يطابق دالة الارتفاع
	var wp := WorldProfile.new()
	var worst := 0.0
	for i in 400:
		var x := randf_range(-190.0, 190.0)
		var z := randf_range(-190.0, 190.0)
		worst = maxf(worst, absf(d.sample_height(x, z) - wp.height(x, z)))
	print("أقصى فرق بين التصادم ودالة الارتفاع: %.3f متر" % worst)
	quit(0)
