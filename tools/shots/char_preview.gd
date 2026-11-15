extends Node3D
func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.10, 0.11, 0.13)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.59, 0.66)
	e.ambient_light_energy = 1.5
	env.environment = e
	add_child(env)
	var k := DirectionalLight3D.new()
	k.rotation_degrees = Vector3(-34, 40, 0); k.light_energy = 1.8
	add_child(k)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.05, 4.6); cam.fov = 46.0
	add_child(cam); cam.current = true
	var states := ["مشي", "ركض", "قرفصاء", "سباحة", "انبطاح"]
	var i := 0
	for g in ["male", "female"]:
		for st in states:
			var cm := CharacterModel.new()
			add_child(cm)
			cm.load_model("res://assets/models/characters/%s.fbx" % g,
				1.80 if g == "male" else 1.68)
			cm.position = Vector3(-2.2 + float(i % 5) * 1.05, 0.0,
				-1.3 if g == "female" else 0.25)
			cm.rotation_degrees.y = 18.0
			for _n in 20:
				cm.play_state(st, 3.0, false)
			i += 1
	await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://shots/char_preview.png")
	print("حُفظت المعاينة")
	get_tree().quit()
