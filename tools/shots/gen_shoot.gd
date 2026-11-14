extends SceneTree
func _initialize() -> void:
	var n := Node.new(); n.name = "Shoot"
	n.set_script(ResourceLoader.load("res://tools/shots/shoot.gd"))
	var p := PackedScene.new(); p.pack(n)
	ResourceSaver.save(p, "res://tools/shots/shoot.tscn"); n.free(); quit(0)
