extends SceneTree
func _initialize() -> void:
	var scr: Script = ResourceLoader.load("res://tests/gameplay_test.gd")
	if scr == null:
		push_error("سكربت مفقود")
		quit(1); return
	var n := Node.new()
	n.name = "GameplayTest"
	n.set_script(scr)
	var packed := PackedScene.new()
	if packed.pack(n) != OK:
		push_error("فشل التحزيم"); n.free(); quit(1); return
	var err := ResourceSaver.save(packed, "res://tests/gameplay_test.tscn")
	n.free()
	if err != OK:
		push_error("فشل الحفظ %d" % err); quit(1); return
	print("وُلِّد: res://tests/gameplay_test.tscn")
	quit(0)
