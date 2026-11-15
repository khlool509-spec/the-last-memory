extends Node3D
func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.10, 0.11, 0.13)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.52, 0.56, 0.64)
	e.ambient_light_energy = 1.3
	env.environment = e
	add_child(env)
	var k := DirectionalLight3D.new()
	k.rotation_degrees = Vector3(-36, 38, 0); k.light_energy = 1.7
	add_child(k)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.0, 4.4); cam.fov = 48.0
	add_child(cam); cam.current = true
	var poses := [["مشي", 0.0, false], ["ركض", 6.0, false],
		["مشي", 2.0, true], ["قرفصاء", 1.5, false],
		["سباحة", 2.0, false], ["انبطاح", 0.5, false]]
	var i := 0
	for g in ["male", "female"]:
		for p in poses:
			var r := CharacterRig.create(g)
			r.position = Vector3(-2.3 + float(i % 6) * 0.92,
				0.0, -1.2 if g == "female" else 0.0)
			r.rotation_degrees.y = 15.0
			add_child(r)
			await get_tree().process_frame
			for _n in 14:
				r.pose(str(p[0]), float(p[1]), 0.05, bool(p[2]))
			i += 1
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://shots/char_preview.png")
	print("حُفظت المعاينة")
	get_tree().quit()
