extends SceneTree
## يفرّغ حقل الارتفاع إلى CSV لتحليل التموّج الدوري خارج المحرك.
func _initialize() -> void:
	var w := WorldRenderer.new()
	get_root().add_child(w)
	var n := 400
	var f := FileAccess.open("res://shots/height.csv", FileAccess.WRITE)
	for j in n:
		var row := PackedStringArray()
		for i in n:
			var x := -200.0 + float(i)
			var z := -200.0 + float(j)
			row.append("%.4f" % w.height_at(x, z))
		f.store_line(",".join(row))
	f.close()
	print("حقل الارتفاع: %dx%d" % [n, n])
	quit()
