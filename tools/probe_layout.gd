extends Node
func _ready() -> void:
	var ps: PackedScene = load("res://src/ui/screens/main_menu.tscn")
	var m := ps.instantiate()
	add_child(m)
	await get_tree().process_frame
	await get_tree().process_frame
	var root := m as Control
	print("نافذة العرض      : ", get_viewport().get_visible_rect().size)
	print("جذر القائمة size : ", root.size, "  pos: ", root.position)
	print("اتجاه التخطيط    : ", root.layout_direction, " (0=inherit 1=locale 2=LTR 3=RTL)")
	for c in root.get_children():
		if c is Control:
			var cc := c as Control
			print("  %-14s size=%s pos=%s anchors=[%.2f,%.2f,%.2f,%.2f] vis=%s" % [
				cc.name, str(cc.size), str(cc.position),
				cc.anchor_left, cc.anchor_top, cc.anchor_right, cc.anchor_bottom,
				str(cc.visible)])
	get_tree().quit(0)
