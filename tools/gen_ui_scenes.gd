extends SceneTree
## يولّد مشاهد الواجهة ومسارات الصوت بالمحرك.
## كل مشهد جذر واحد بسكربت: المنطق في .gd والبنية تُبنى وقت التشغيل.

const SCENES := [
	{"out": "res://src/ui/screens/main_menu.tscn", "script": "res://src/ui/screens/main_menu.gd", "type": "Control", "name": "MainMenu"},
	{"out": "res://src/ui/screens/settings_menu.tscn", "script": "res://src/ui/screens/settings_menu.gd", "type": "Control", "name": "SettingsMenu"},
	{"out": "res://src/ui/screens/chapters_menu.tscn", "script": "res://src/ui/screens/chapters_menu.gd", "type": "Control", "name": "ChaptersMenu"},
	{"out": "res://src/ui/screens/collectibles_menu.tscn", "script": "res://src/ui/screens/collectibles_menu.gd", "type": "Control", "name": "CollectiblesMenu"},
	{"out": "res://levels/test/playground.tscn", "script": "res://src/environment/playground.gd", "type": "Node3D", "name": "Playground"},
]

func _initialize() -> void:
	var fails := 0
	for s in SCENES:
		if not _gen(s):
			fails += 1
	if not _gen_buses():
		fails += 1
	quit(fails)

func _gen(spec: Dictionary) -> bool:
	var scr: Script = ResourceLoader.load(str(spec["script"]))
	if scr == null:
		push_error("سكربت مفقود: " + str(spec["script"]))
		return false
	var node: Node
	match str(spec["type"]):
		"Control":
			node = Control.new()
			(node as Control).set_anchors_preset(Control.PRESET_FULL_RECT)
		"Node3D":
			node = Node3D.new()
		_:
			node = Node.new()
	node.name = str(spec["name"])
	node.set_script(scr)

	var packed := PackedScene.new()
	if packed.pack(node) != OK:
		push_error("فشل تحزيم " + str(spec["out"]))
		node.free()
		return false
	var err := ResourceSaver.save(packed, str(spec["out"]))
	node.free()
	if err != OK:
		push_error("فشل حفظ %s (%d)" % [str(spec["out"]), err])
		return false
	print("وُلِّد: ", spec["out"])
	return true

func _gen_buses() -> bool:
	# Master موجود افتراضياً؛ نضيف Music و SFX ونوجّههما إليه
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, "Master")
	var layout := AudioServer.generate_bus_layout()
	var err := ResourceSaver.save(layout, "res://default_bus_layout.tres")
	if err != OK:
		push_error("فشل حفظ مسارات الصوت: %d" % err)
		return false
	print("مسارات الصوت: ", AudioServer.bus_count, " مسارات")
	return true
