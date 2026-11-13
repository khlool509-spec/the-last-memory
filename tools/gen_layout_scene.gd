extends SceneTree
func _initialize() -> void:
	var n := Node.new()
	n.name = "LayoutCheck"
	n.set_script(load("res://tools/layout_check.gd"))
	var p := PackedScene.new()
	p.pack(n)
	ResourceSaver.save(p, "res://tools/layout_check.tscn")
	n.free()
	quit(0)
