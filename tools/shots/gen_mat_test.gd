extends SceneTree
func _initialize() -> void:
	var n := Node.new(); n.name = "MatTest"
	n.set_script(ResourceLoader.load("res://tools/shots/mat_test.gd"))
	var p := PackedScene.new(); p.pack(n)
	ResourceSaver.save(p, "res://tools/shots/mat_test.tscn"); n.free(); quit(0)
