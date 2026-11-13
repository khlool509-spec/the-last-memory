extends Node3D
## ساحة اختبار قابلة للعب: أرضية وعوائق وإضاءة ليلية وضباب،
## مع لاعب وكاميرا وواجهة لعب موصولة بالكامل.
## تُبنى بالكود فلا توجد مصفوفات مكتوبة يدوياً.

var player: Player
var cam: FollowCamera
var hud: HUD
var pause_menu: PauseMenu

func _ready() -> void:
	name = "Playground"
	_build_environment()
	_build_world()
	_build_player()
	_build_camera()
	_build_ui()
	_wire()

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color("#070910")
	mat.sky_horizon_color = Color("#141a26")
	mat.ground_bottom_color = Color("#05060a")
	mat.ground_horizon_color = Color("#101520")
	mat.sun_angle_max = 24.0
	sky.sky_material = mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	# ضباب عمقي: مدعوم على Mobile renderer، بخلاف الضباب الحجمي
	env.fog_enabled = true
	env.fog_light_color = Color("#2a3242")
	env.fog_density = 0.016
	env.fog_sky_affect = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.12
	we.environment = env
	add_child(we)

	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color("#aec4e0")
	moon.light_energy = 0.85
	moon.shadow_enabled = true
	moon.transform = Transform3D(Basis(), Vector3(0, 12, 0)).looking_at(Vector3(6, 0, -6), Vector3.UP)
	add_child(moon)

func _build_world() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	var mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(90, 90)
	mesh.mesh = pm
	mesh.material_override = _mat(Color("#2b2d31"), 0.92)
	ground.add_child(mesh)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(90, 0.4, 90)
	col.shape = box
	col.position = Vector3(0, -0.2, 0)
	ground.add_child(col)
	add_child(ground)

	# أعمدة: تختبر التصادم واصطدام الكاميرا وإدراك العمق
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261114
	for i in 14:
		var ang := TAU * float(i) / 14.0
		var rad := rng.randf_range(9.0, 24.0)
		var h := rng.randf_range(2.4, 6.5)
		_pillar(Vector3(cos(ang) * rad, h * 0.5, sin(ang) * rad), h, rng.randf_range(0.7, 1.5))

	# منصّة مرتفعة لاختبار القفز
	_platform(Vector3(0, 0.6, -7.5), Vector3(5, 1.2, 5))
	_platform(Vector3(4.5, 1.5, -11.0), Vector3(4, 3.0, 4))

func _pillar(pos: Vector3, h: float, w: float) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, w)
	m.mesh = bm
	m.material_override = _mat(Color("#3a3d44"), 0.85)
	body.add_child(m)
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = bm.size
	c.shape = s
	body.add_child(c)
	add_child(body)

func _platform(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = _mat(Color("#33363d"), 0.8)
	body.add_child(m)
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	c.shape = s
	body.add_child(c)
	add_child(body)

func _mat(albedo: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = rough
	m.metallic = 0.0
	return m

func _build_player() -> void:
	player = Player.new()
	player.name = "Player"
	player.position = Vector3(0, 1.2, 6.0)

	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 1.75
	body.mesh = cap
	body.material_override = _mat(Color("#8a8f99"), 0.6)
	body.position = Vector3(0, 0.875, 0)
	player.add_child(body)

	# علامة أمامية: تُظهر اتجاه الشخصية بوضوح أثناء الاختبار
	var nose := MeshInstance3D.new()
	var nm := BoxMesh.new()
	nm.size = Vector3(0.16, 0.16, 0.34)
	nose.mesh = nm
	nose.material_override = _mat(Color("#c8303c"), 0.5)
	nose.position = Vector3(0, 1.35, -0.38)
	player.add_child(nose)

	var shape := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.35
	cs.height = 1.75
	shape.shape = cs
	shape.position = Vector3(0, 0.875, 0)
	player.add_child(shape)
	add_child(player)

func _build_camera() -> void:
	cam = FollowCamera.new()
	cam.name = "FollowCamera"
	add_child(cam)
	cam.set_target(player)
	cam.global_position = player.global_position + Vector3.UP * cam.height

func _build_ui() -> void:
	hud = HUD.new()
	hud.name = "HUD"
	add_child(hud)
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)

func _wire() -> void:
	hud.move_input.connect(func(d: Vector2): player.set_move_input(d))
	hud.look_input.connect(func(d: Vector2): cam.apply_look(d))
	hud.run_changed.connect(func(v: bool): player.set_run(v))
	hud.jump_pressed.connect(func(): player.try_jump())
	hud.interact_pressed.connect(func(): player.interact())
	hud.pause_pressed.connect(func(): pause_menu.toggle())
	player.stamina_changed.connect(func(r: float): hud.set_stamina(r))
	player.interacted.connect(func(): hud.set_objective("لا شيء هنا بعد… تابع البحث"))
	hud.set_objective("الهدف: تعرّف على التحكم — تحرّك، اركض، اقفز")

func _process(_delta: float) -> void:
	if player and cam:
		player.camera_basis_yaw = cam.get_yaw_radians()
