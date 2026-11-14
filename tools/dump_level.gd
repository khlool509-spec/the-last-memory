extends Node
## يفرّغ إحداثيات كل عناصر الفصل إلى JSON ليُرسم مخطط علوي للتحقق
## من التوزيع: لا شجرة فوق الممر، والفوانيس تحاذيه، والبوابة في مكانها.

func _ready() -> void:
	var packed: PackedScene = load("res://levels/ch01_forest/chapter_one.tscn")
	var lvl := packed.instantiate()
	add_child(lvl)
	await get_tree().process_frame

	var out := {"trees": [], "rocks": [], "lanterns": [], "items": [],
		"gate": [], "walls": [], "player": [], "path": [], "field": []}

	var trees := _find(lvl, "NearTrees")
	if trees:
		for c in trees.get_children():
			out["trees"].append([c.position.x, c.position.z])
	var field := _find(lvl, "TreeField")
	if field and field.has_meta("spots"):
		for v in field.get_meta("spots"):
			out["field"].append([v.x, v.z])
	var rocks := _find(lvl, "Rocks")
	if rocks:
		for c in rocks.get_children():
			out["rocks"].append([c.position.x, c.position.z])
	var lanterns := _find(lvl, "Lanterns")
	if lanterns:
		for c in lanterns.get_children():
			out["lanterns"].append([c.position.x, c.position.z])
	for n in get_tree().get_nodes_in_group("interactable"):
		var it := n as Node3D
		out["items"].append([it.position.x, it.position.z, it.name])
	var gate := _find(lvl, "AncientGate")
	if gate:
		out["gate"].append([gate.position.x, gate.position.z])
	for c in lvl.get_children():
		if c is StaticBody3D and c.name.begins_with("@StaticBody3D"):
			out["walls"].append([c.position.x, c.position.z])
	out["player"].append([lvl.player.position.x, lvl.player.position.z])
	for p in (lvl as ChapterOne)._path_points():
		out["path"].append([p.x, p.z])

	var f := FileAccess.open("user://level_dump.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("DUMP:", ProjectSettings.globalize_path("user://level_dump.json"))
	print("تصادم=%d بصرية=%d صخور=%d فوانيس=%d تفاعل=%d"
		% [out["trees"].size(), out["field"].size(), out["rocks"].size(),
		   out["lanterns"].size(), out["items"].size()])
	get_tree().quit(0)

func _find(root: Node, nm: String) -> Node:
	if root.name == nm: return root
	for c in root.get_children():
		var f := _find(c, nm)
		if f: return f
	return null
