extends SceneTree
func _initialize() -> void:
	var n := Node.new()
	n.name = "Probe"
	n.set_script(load("res://tools/probe_layout.gd"))
	var p := PackedScene.new()
	p.pack(n)
	ResourceSaver.save(p, "res://tools/probe.tscn")
	n.free()
	quit(0)
