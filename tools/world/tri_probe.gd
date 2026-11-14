extends SceneTree
func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	var d: WorldData = ResourceLoader.load("res://levels/ch01_forest/baked/world.res")
	var per := {}
	for key in d.scatter:
		var sp: String = str(key).split(":")[0]
		per[sp] = int(per.get(sp, 0)) + int((d.scatter[key] as PackedFloat32Array).size() / 12.0)
	var total_tris := 0
	print("%-10s %6s %8s %12s" % ["النوع", "عدد", "مثلث/نسخة", "الإجمالي"])
	var keys: Array = per.keys(); keys.sort()
	for sp in keys:
		rng.seed = hash(sp) + 20261114
		var m := PlantMeshes.build(str(sp), rng)
		var t := 0
		if m:
			for s in m.get_surface_count():
				t += m.surface_get_array_index_len(s) / 3
				if m.surface_get_array_index_len(s) == 0:
					t += m.surface_get_array_len(s) / 3
		var tot: int = t * int(per[sp])
		total_tris += tot
		print("%-10s %6d %8d %12d" % [sp, per[sp], t, tot])
	print("مجموع مثلثات النبات في العالم: %d" % total_tris)
	quit(0)
