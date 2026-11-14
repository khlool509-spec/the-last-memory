extends SceneTree
## يفرّغ مواضع كل ما وُضع في العالم لمعاينته علوياً.
func _initialize() -> void:
	var d: WorldData = ResourceLoader.load("res://levels/ch01_forest/baked/world.res")
	var out := {"species": {}, "poi": {}}
	for key in d.scatter:
		var sp: String = str(key).split(":")[0]
		var n := int((d.scatter[key] as PackedFloat32Array).size() / 12.0)
		if not out["species"].has(sp):
			out["species"][sp] = []
		for k in n:
			var t := d.instance_transform(key, k)
			out["species"][sp].append([t.origin.x, t.origin.z, t.basis.get_scale().y])
	for k in d.poi:
		var p: Vector3 = d.poi[k]
		out["poi"][k] = [p.x, p.z, p.y]
	var f := FileAccess.open("user://content_dump.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("DUMP ", ProjectSettings.globalize_path("user://content_dump.json"))
	quit(0)
