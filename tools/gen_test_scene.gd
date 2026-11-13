extends SceneTree
## يولّد مشهد الاختبار ويحفظه بـ Godot نفسه.
## السبب: كتابة Transform3D يدوياً في .tscn خاطئة — ترتيب الأرقام
## صفوف لا أعمدة، وهذا سبب خطأ حقيقي ظهر على الجهاز.
## القاعدة من الآن: المشاهد تُولَّد بالمحرك، لا تُكتب بالنص.

const OUT := "res://levels/test/test_3d.tscn"

func _initialize() -> void:
	var r := Node3D.new()
	r.name = "Test3D"

	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 12)
	ground.mesh = pm
	r.add_child(ground)
	ground.owner = r

	var box := MeshInstance3D.new()
	box.name = "Box"
	box.mesh = BoxMesh.new()
	box.transform = Transform3D(Basis(), Vector3(0, 0.5, 0))
	r.add_child(box)
	box.owner = r

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.transform = Transform3D(Basis(), Vector3(4, 6, 3)).looking_at(Vector3.ZERO, Vector3.UP)
	sun.shadow_enabled = true
	r.add_child(sun)
	sun.owner = r

	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.transform = Transform3D(Basis(), Vector3(0, 1.8, 4.5)).looking_at(Vector3(0, 0.5, 0), Vector3.UP)
	r.add_child(cam)
	cam.owner = r

	# تحقق قبل الحفظ
	var fwd := -cam.transform.basis.z
	var want := (Vector3(0, 0.5, 0) - cam.transform.origin).normalized()
	var dot := fwd.dot(want)
	print("تحقق الكاميرا قبل الحفظ: dot=%.6f" % dot)
	if dot < 0.9999:
		push_error("الكاميرا لا تنظر إلى الهدف")
		quit(1)
		return

	var packed := PackedScene.new()
	if packed.pack(r) != OK:
		push_error("فشل التحزيم")
		quit(1)
		return
	var err := ResourceSaver.save(packed, OUT)
	if err != OK:
		push_error("فشل الحفظ: %d" % err)
		quit(1)
		return
	r.free()
	print("حُفظ: ", OUT)
	quit(0)
