extends SceneTree
func _initialize() -> void:
	var n := Node.new(); n.name = "DumpLevel"
	n.set_script(ResourceLoader.load("res://tools/dump_level.gd"))
	var p := PackedScene.new(); p.pack(n)
	ResourceSaver.save(p, "res://tools/dump_level.tscn"); n.free(); quit(0)
