extends SceneTree
func _initialize() -> void:
	var d: WorldData = ResourceLoader.load("res://levels/ch01_forest/baked/world.res")
	var per := {}
	for key in d.scatter:
		var sp: String = str(key).split(":")[0]
		per[sp] = int(per.get(sp, 0)) + int((d.scatter[key] as PackedFloat32Array).size() / 12.0)
	var trees := ["pine","spruce","oak","birch","willow","dead"]
	var details := [1.0, 0.45, 0.18]
	print("%-8s %6s | %7s %7s %7s  (مثلث/نسخة لكل مستوى)" % ["النوع","عدد","L0","L1","L2"])
	var world_old := 0
	var world_new := 0
	for sp in trees:
		var row := []
		for dt in details:
			var r := RandomNumberGenerator.new()
			r.seed = hash(sp) + WorldProfile.SEED
			var m := PlantMeshes.build(sp, r, dt)
			var t := 0
			if m:
				for si in m.get_surface_count():
					t += m.surface_get_array_index_len(si) / 3
			row.append(t)
		print("%-8s %6d | %7d %7d %7d" % [sp, per.get(sp,0), row[0], row[1], row[2]])
		world_old += int(per.get(sp,0)) * int(row[0])
	# تقدير ما يدخل الكادر: مخروط رؤية 70° بثلاثة نطاقات
	var tree_density := 0.0
	for sp in trees:
		tree_density += float(per.get(sp,0))
	tree_density /= (400.0 * 400.0)
	var wedge := func(r0: float, r1: float) -> float:
		return (70.0 / 360.0) * PI * (r1 * r1 - r0 * r0)
	var bands := [[0.0, 34.0, 0], [34.0, 76.0, 1], [76.0, 128.0, 2]]
	var avg := [0.0, 0.0, 0.0]
	for li in 3:
		var sum := 0.0
		var n := 0.0
		for sp in trees:
			var r := RandomNumberGenerator.new()
			r.seed = hash(sp) + WorldProfile.SEED
			var m := PlantMeshes.build(sp, r, details[li])
			var t := 0
			if m:
				for si in m.get_surface_count():
					t += m.surface_get_array_index_len(si) / 3
			sum += float(t) * float(per.get(sp,0))
			n += float(per.get(sp,0))
		avg[li] = sum / maxf(n, 1.0)
	var vis := 0.0
	print("")
	for b in bands:
		var area: float = wedge.call(float(b[0]), float(b[1]))
		var cnt: float = area * tree_density
		var tris: float = cnt * avg[int(b[2])]
		vis += tris
		print("  نطاق %3d-%3d م: %5.0f شجرة × %4.0f مثلث = %7.0f" % [int(b[0]), int(b[1]), cnt, avg[int(b[2])], tris])
	print("")
	print("أشجار داخل الكادر: ~%d مثلث" % int(vis))
	print("بلا مستويات تفصيل لكان: ~%d مثلث" % int(vis * 0.0 + (wedge.call(0.0,128.0) * tree_density * avg[0])))
	print("إجمالي الأشجار في العالم بأعلى تفصيل: %d مثلث" % world_old)
	quit(0)
