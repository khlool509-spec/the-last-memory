extends SceneTree
## يفحص النماذج المنزّلة: أبعادها الحقيقية وعدد مثلثاتها
func _initialize() -> void:
	var dir := DirAccess.open("res://assets/models")
	if dir == null:
		print("لا مجلد نماذج"); quit(); return
	for name in dir.get_directories():
		var p := "res://assets/models/%s/%s.gltf" % [name, name]
		if not ResourceLoader.exists(p):
			print("  %-22s غير مستورد" % name); continue
		var ps: PackedScene = ResourceLoader.load(p)
		var inst := ps.instantiate()
		var tri := 0
		var aabb := AABB()
		var first := true
		for n in inst.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null: continue
			for s in mi.mesh.get_surface_count():
				var a := mi.mesh.surface_get_arrays(s)
				var idx = a[Mesh.ARRAY_INDEX]
				tri += (idx.size() / 3) if idx != null else ((a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3)
			var b := mi.get_aabb()
			if first: aabb = b; first = false
			else: aabb = aabb.merge(b)
		print("  %-22s %6d مثلث   أبعاد %.1f×%.1f×%.1f م" % [
			name, tri, aabb.size.x, aabb.size.y, aabb.size.z])
		inst.free()
	quit()
