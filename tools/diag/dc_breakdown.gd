extends Node
## يفكّك مصدر استدعاءات الرسم: كم عقدة مرئية من كل نوع.
func _ready() -> void:
	var lvl: Node3D = load("res://levels/ch01_forest/chapter_one.tscn").instantiate()
	add_child(lvl)
	await get_tree().process_frame
	await get_tree().process_frame
	var w = lvl.world
	var counts := {}
	var tris := {}
	for n in lvl.find_children("*", "GeometryInstance3D", true, false):
		var cat := "أخرى"
		var p := n.get_parent()
		var pn := str(p.name) if p else ""
		if n is MultiMeshInstance3D:
			cat = "توزيع: " + str(n.name).split("_")[0]
		elif pn == "Terrain":
			cat = "مقاطع الأرض"
		elif pn == "Water":
			cat = "الماء"
		else:
			cat = "بناء/معالم"
		counts[cat] = int(counts.get(cat, 0)) + 1
		var t := 0
		if n is MultiMeshInstance3D and n.multimesh and n.multimesh.mesh:
			t = _tris(n.multimesh.mesh) * n.multimesh.instance_count
		elif n is MeshInstance3D and n.mesh:
			t = _tris(n.mesh)
		tris[cat] = int(tris.get(cat, 0)) + t
	var keys: Array = counts.keys()
	keys.sort()
	var tot := 0
	for k in keys:
		tot += int(counts[k])
		print("  %-26s عقد=%5d  مثلثات=%9d" % [k, counts[k], tris[k]])
	print("  المجموع: %d عقدة قابلة للرسم" % tot)
	get_tree().quit()

func _tris(m: Mesh) -> int:
	var n := 0
	for s in m.get_surface_count():
		var a := m.surface_get_arrays(s)
		var idx = a[Mesh.ARRAY_INDEX]
		if idx != null:
			n += idx.size() / 3
		else:
			n += (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n
