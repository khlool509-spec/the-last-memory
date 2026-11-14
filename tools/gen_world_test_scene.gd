extends SceneTree
func _initialize() -> void:
	var n := Node.new(); n.name = "WorldTest"
	n.set_script(ResourceLoader.load("res://tests/world_test.gd"))
	var p := PackedScene.new(); p.pack(n)
	ResourceSaver.save(p, "res://tests/world_test.tscn"); n.free(); quit(0)
