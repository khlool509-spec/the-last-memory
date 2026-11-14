extends Node3D
## سطح القمر — المستوى القابل للعب.
## يجمع: تضاريس مولَّدة، سماء فضاء، جاذبية قمرية، بدلة بأكسجين،
## ومتتالية مهام يقودها اللاعب بالمشي والتفاعل.

const WORLD_SEED := 20261114
const MOON_GRAVITY := 3.2          # م/ث² — واقع القمر 1.62، رُفعت للعبانية
const EARTH_GRAVITY := 9.8
const RESPAWN_FADE := 1.1

var terrain: MoonTerrain
var player: Player
var cam: FollowCamera
var hud: HUD
var pause_menu: PauseMenu
var life: LifeSupport
var missions: MissionSystem
var detector: InteractionDetector

var _rng := RandomNumberGenerator.new()
var _markers: Dictionary = {}        # id -> ObjectiveMarker
var _active_marker: ObjectiveMarker = null
var _lander_pos := Vector3.ZERO
var _spawn := Vector3.ZERO
var _dust: GPUParticles3D
var _puff_burst: GPUParticles3D
var _dead := false
var _samples_total := 3

func _ready() -> void:
	name = "MoonSurface"
	_rng.seed = WORLD_SEED
	_build_environment()
	_build_terrain()
	_build_player()
	_build_camera()
	_build_props()
	_build_ui()
	_build_missions()
	_wire()
	missions.start()

# ---------------------------------------------------------------- البيئة

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	we.name = "SpaceEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY

	var sky := Sky.new()
	var shader := load("res://assets/shaders/moon_sky.gdshader")
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("earth_dir", Vector3(0.35, 0.40, -0.85).normalized())
		mat.set_shader_parameter("sun_dir", Vector3(0.58, 0.46, 0.67).normalized())
		sky.sky_material = mat
	else:
		# احتياطي: سماء سوداء صلبة إن تعذّر تحميل الشيدر
		var pm := ProceduralSkyMaterial.new()
		pm.sky_top_color = Color("#000000")
		pm.sky_horizon_color = Color("#05050a")
		pm.ground_bottom_color = Color("#000000")
		pm.ground_horizon_color = Color("#05050a")
		sky.sky_material = pm
	env.sky = sky

	# في الفراغ لا يضيء الهواء شيئاً: الإضاءة المحيطة ضئيلة جداً،
	# وما يملأ الظلال هو ضوء الأرض المنعكس وحده.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#1b2436")
	env.ambient_light_energy = 0.34
	env.ambient_light_sky_contribution = 0.0

	# لا ضباب: لا غلاف جوي على القمر. البعيد يبقى حاداً.
	env.fog_enabled = false

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.92
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.25
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.14
	env.adjustment_saturation = 0.86
	we.environment = env
	add_child(we)

	# الشمس: قاسية، بيضاء، بلا تشتّت — تعطي ظلالاً سوداء حادّة
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color("#fff6e8")
	sun.light_energy = 1.9
	sun.light_specular = 0.9
	sun.shadow_enabled = true
	sun.shadow_bias = 0.045
	sun.shadow_normal_bias = 1.4
	sun.directional_shadow_max_distance = 180.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.rotation_degrees = Vector3(-26.0, -41.0, 0.0)
	add_child(sun)

	# ضوء الأرض: أزرق بارد خافت من الجهة المقابلة، يمنع سواد الظل التام
	var earthshine := DirectionalLight3D.new()
	earthshine.name = "Earthshine"
	earthshine.light_color = Color("#6f8fc4")
	earthshine.light_energy = 0.26
	earthshine.shadow_enabled = false
	earthshine.rotation_degrees = Vector3(-31.0, 148.0, 0.0)
	add_child(earthshine)

func _build_terrain() -> void:
	terrain = MoonTerrain.new(WORLD_SEED)
	add_child(terrain)

# ---------------------------------------------------------------- اللاعب

func _build_player() -> void:
	player = Player.new()
	player.name = "Astronaut"
	# فيزياء القمر: وثب عالٍ، هبوط بطيء، احتكاك ضعيف، تحكم جوي محدود
	player.set_gravity(MOON_GRAVITY)
	player.jump_velocity = 4.3
	player.walk_speed = 2.8
	player.run_speed = 5.4
	player.acceleration = 6.0
	player.deceleration = 5.0
	player.air_control = 0.32
	player.turn_speed = 7.5
	player.stamina_drain = 18.0
	player.stamina_regen = 13.0

	_lander_pos = terrain.find_flat_spot(Vector2.ZERO, 18.0, _rng)
	_spawn = _lander_pos + Vector3(0, 0.2, -5.0)
	_spawn.y = terrain.height_at(_spawn.x, _spawn.z) + 0.3
	player.position = _spawn

	_build_suit(player)

	var shape := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.38
	cs.height = 1.80
	shape.shape = cs
	shape.position = Vector3(0, 0.9, 0)
	player.add_child(shape)
	add_child(player)

	life = LifeSupport.new()
	life.name = "LifeSupport"
	player.add_child(life)

	detector = InteractionDetector.new()
	detector.name = "InteractionDetector"
	player.add_child(detector)
	detector.setup(player)

	_build_dust()

## بدلة فضاء مبنية بالأشكال الأوّلية: جذع أبيض، خوذة ذهبية، حقيبة دعم حياة
func _build_suit(root: Node3D) -> void:
	var suit := MoonProps.mat(Color("#dcd9d2"), 0.82)
	var joint := MoonProps.mat(Color("#b9b5ad"), 0.9)
	var pack := MoonProps.mat(Color("#8f9398"), 0.6, 0.35)

	var torso := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.33
	cap.height = 1.1
	torso.mesh = cap
	torso.material_override = suit
	torso.position = Vector3(0, 1.02, 0)
	root.add_child(torso)

	# الحوض والساقان
	var hips := MeshInstance3D.new()
	var hm := CapsuleMesh.new()
	hm.radius = 0.26
	hm.height = 0.72
	hips.mesh = hm
	hips.material_override = joint
	hips.position = Vector3(0, 0.42, 0)
	root.add_child(hips)

	# الخوذة: كرة بيضاء بزجاج ذهبي عاكس
	var helm := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.27
	hs.height = 0.54
	hs.radial_segments = 16
	hs.rings = 9
	helm.mesh = hs
	helm.material_override = suit
	helm.position = Vector3(0, 1.72, 0)
	root.add_child(helm)

	var visor := MeshInstance3D.new()
	var vs := SphereMesh.new()
	vs.radius = 0.235
	vs.height = 0.42
	vs.radial_segments = 14
	vs.rings = 8
	visor.mesh = vs
	var vmat := MoonProps.mat(Color("#c9a227"), 0.12, 1.0)
	vmat.emission_enabled = true
	vmat.emission = Color("#3a2d08")
	vmat.emission_energy_multiplier = 0.6
	visor.material_override = vmat
	visor.position = Vector3(0, 1.72, -0.11)
	visor.scale = Vector3(0.92, 0.86, 0.72)
	root.add_child(visor)

	# حقيبة دعم الحياة على الظهر
	var bp := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.46, 0.62, 0.24)
	bp.mesh = bm
	bp.material_override = pack
	bp.position = Vector3(0, 1.14, 0.33)
	root.add_child(bp)

	# كشّاف الخوذة: ضروري داخل الظل القمري الأسود تماماً
	var lamp := SpotLight3D.new()
	lamp.name = "HelmetLamp"
	lamp.light_color = Color("#eaf2ff")
	lamp.light_energy = 2.6
	lamp.spot_range = 24.0
	lamp.spot_angle = 38.0
	lamp.spot_angle_attenuation = 1.4
	lamp.shadow_enabled = false
	lamp.position = Vector3(0, 1.66, -0.26)
	lamp.rotation_degrees = Vector3(-6.0, 180.0, 0.0)
	root.add_child(lamp)

	# شريط عاكس أحمر: يميّز الشخصية في الظل كما في بدلات القيادة
	var stripe := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.1, 0.42, 0.02)
	stripe.mesh = sm
	stripe.material_override = MoonProps.mat(Color("#b2121f"), 0.7)
	stripe.position = Vector3(0.26, 1.05, -0.3)
	root.add_child(stripe)

## غبار الخطوات: على القمر لا هواء يحمله، فيتبع قوساً ويهبط فوراً
func _build_dust() -> void:
	_dust = GPUParticles3D.new()
	_dust.name = "FootDust"
	_dust.emitting = false
	_dust.amount = 16
	_dust.lifetime = 1.3
	_dust.one_shot = false
	_dust.explosiveness = 0.0
	_dust.local_coords = false

	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 42.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.6
	# الغبار يخضع لجاذبية القمر نفسها: يسقط ببطء بلا انجراف هوائي
	pm.gravity = Vector3(0, -MOON_GRAVITY, 0)
	pm.scale_min = 0.05
	pm.scale_max = 0.17
	pm.color = Color(0.68, 0.66, 0.63, 0.5)
	_dust.process_material = pm

	var qm := QuadMesh.new()
	qm.size = Vector2(0.3, 0.3)
	_dust.draw_pass_1 = qm
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color = Color(0.72, 0.70, 0.67, 0.42)
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.vertex_color_use_as_albedo = true
	_dust.material_override = dm
	add_child(_dust)

	# نفضة القفز والهبوط: طلقة واحدة مستقلة عن غبار المشي
	_puff_burst = GPUParticles3D.new()
	_puff_burst.name = "PuffBurst"
	_puff_burst.emitting = false
	_puff_burst.one_shot = true
	_puff_burst.explosiveness = 0.92
	_puff_burst.amount = 24
	_puff_burst.lifetime = 1.5
	_puff_burst.local_coords = false
	var pm2 := pm.duplicate() as ParticleProcessMaterial
	pm2.initial_velocity_min = 1.2
	pm2.initial_velocity_max = 3.0
	pm2.spread = 62.0
	_puff_burst.process_material = pm2
	_puff_burst.draw_pass_1 = qm
	_puff_burst.material_override = dm
	add_child(_puff_burst)

func _build_camera() -> void:
	cam = FollowCamera.new()
	cam.name = "FollowCamera"
	cam.distance = 4.8
	cam.height = 1.7
	add_child(cam)
	cam.set_target(player)
	cam.global_position = player.global_position + Vector3.UP * cam.height
	var c := cam.get_camera()
	if c:
		# لا ضباب يخفي البعيد، فمدى الرؤية يمتد إلى آخر الخريطة
		c.far = 900.0
		c.near = 0.08

# ---------------------------------------------------------------- المجسّمات

func _build_props() -> void:
	# المركبة في المنتصف: نقطة البداية والعودة
	var lander := MoonProps.make_lander()
	lander.position = _lander_pos
	add_child(lander)

	# محطة الأكسجين بجوار المركبة
	var station := MoonProps.make_oxygen_station("oxygen_station")
	var sp := terrain.find_flat_spot(Vector2(_lander_pos.x + 7.0, _lander_pos.z + 3.0), 4.0, _rng)
	station.position = sp
	station.used.connect(_on_interact_used)
	add_child(station)

	# صخور متناثرة
	for p in terrain.scatter_points(54, 14.0, 138.0, 7.0, _rng):
		var b := MoonProps.make_boulder(_rng)
		b.position = p
		b.rotation.y = _rng.randf() * TAU
		add_child(b)

	# عيّنات الثرى
	var sample_spots := terrain.scatter_points(_samples_total, 34.0, 78.0, 30.0, _rng)
	for i in sample_spots.size():
		var s := MoonProps.make_sample("sample")
		s.position = sample_spots[i]
		s.used.connect(_on_interact_used)
		add_child(s)

	# الهوائي بعيداً عن المركبة
	var ant_spot := terrain.find_flat_spot(Vector2(-92.0, 64.0), 22.0, _rng)
	var antenna := MoonProps.make_antenna("antenna")
	antenna.position = ant_spot
	antenna.used.connect(_on_interact_used)
	add_child(antenna)
	_make_marker("antenna", ant_spot, Color("#e4192b"))

	# العَلَم عند المركبة
	var flag := MoonProps.make_flag()
	var fp := terrain.find_flat_spot(Vector2(_lander_pos.x - 6.0, _lander_pos.z - 4.0), 4.0, _rng)
	flag.position = fp
	add_child(flag)

	# منارات المهام
	var walk_spot := terrain.find_flat_spot(Vector2(_lander_pos.x + 2.0, _lander_pos.z - 26.0), 10.0, _rng)
	_make_marker("first_steps", walk_spot, Color("#7d93ad"))

	var crater: Dictionary = terrain.largest_crater()
	if not crater.is_empty():
		var cpos: Vector2 = crater["pos"]
		var cp := Vector3(cpos.x, terrain.height_at(cpos.x, cpos.y), cpos.y)
		_make_marker("great_crater", cp, Color("#c9a227"))

	_make_marker("lander", _lander_pos, Color("#53d98a"))

	# العيّنات بلا منارة ثابتة: البوصلة تشير إلى أقربها تلقائياً

func _make_marker(id: String, pos: Vector3, col: Color) -> void:
	var m := ObjectiveMarker.new()
	m.marker_id = id
	m.color = col
	m.position = pos
	m.visible = false
	m.reached.connect(_on_marker_reached)
	add_child(m)
	_markers[id] = m

# ---------------------------------------------------------------- الواجهة

func _build_ui() -> void:
	hud = HUD.new()
	hud.name = "HUD"
	add_child(hud)
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)

func _build_missions() -> void:
	missions = MissionSystem.new()
	missions.name = "MissionSystem"
	add_child(missions)
	missions.load_missions([
		{"id": "first_steps", "kind": Mission.Kind.REACH, "target": "first_steps",
		 "title": "اخرج من المركبة وتفقّد المحيط",
		 "detail": "جاذبية القمر سدس جاذبية الأرض — خطوتك ستحملك أبعد مما تتوقع.",
		 "hint": "اتبع العمود الضوئي"},
		{"id": "samples", "kind": Mission.Kind.COLLECT, "target": "sample", "required": _samples_total,
		 "title": "اجمع عيّنات الثرى",
		 "detail": "ثلاث عيّنات متفرّقة على السطح.",
		 "hint": "العيّنات تتوهّج بالأزرق"},
		{"id": "antenna", "kind": Mission.Kind.INTERACT, "target": "antenna",
		 "title": "أصلح هوائي الاتصال",
		 "detail": "بلا هوائي لا بلاغ ولا إنقاذ.",
		 "hint": "الهوائي شمال غرب الموقع"},
		{"id": "great_crater", "kind": Mission.Kind.REACH, "target": "great_crater",
		 "title": "انزل إلى الفوّهة الكبرى",
		 "detail": "الهوائي التقط إشارة تأتي من داخلها.",
		 "hint": "احذر الانحدار — الهبوط بطيء هنا"},
		{"id": "lander", "kind": Mission.Kind.RETURN, "target": "lander",
		 "title": "عُد إلى المركبة",
		 "detail": "ما وجدته يجب أن يصل.",
		 "hint": "الضوء الأخضر يدلّك"},
	])

func _wire() -> void:
	hud.set_player_name("رائد — المجهول")
	hud.move_input.connect(func(d: Vector2): player.set_move_input(d))
	hud.look_input.connect(func(d: Vector2): cam.apply_look(d))
	hud.run_changed.connect(func(v: bool): player.set_run(v))
	hud.jump_pressed.connect(func(): player.try_jump())
	hud.interact_pressed.connect(_on_interact_pressed)
	hud.pause_pressed.connect(func(): pause_menu.toggle())

	player.stamina_changed.connect(func(r: float): hud.set_stamina(r))
	player.landed.connect(_on_landed)
	player.jumped.connect(func(): _puff(0.6))

	life.oxygen_changed.connect(func(r: float): hud.set_oxygen(r))
	life.entered_warning.connect(func(): hud.show_toast("تحذير: الأكسجين تحت ٣٥٪", 2.2))
	life.entered_critical.connect(func(): hud.show_toast("خطر: الأكسجين تحت ١٥٪ — عُد للمحطة", 2.8))
	life.depleted.connect(_on_oxygen_depleted)

	detector.focus_changed.connect(_on_focus_changed)

	missions.mission_started.connect(_on_mission_started)
	missions.progress_changed.connect(_on_mission_progress)
	missions.mission_completed.connect(_on_mission_completed)
	missions.all_completed.connect(_on_all_completed)

	hud.set_oxygen(1.0)

# ---------------------------------------------------------------- الأحداث

func _on_mission_started(m: Mission) -> void:
	hud.set_objective("الهدف: " + m.objective_text())
	_focus_marker(m.target_id if m.kind != Mission.Kind.COLLECT else "")
	if m.hint != "":
		hud.show_toast(m.hint, 2.0)

func _on_mission_progress(m: Mission) -> void:
	hud.set_objective("الهدف: " + m.objective_text())

func _on_mission_completed(m: Mission) -> void:
	hud.show_toast("أُنجزت: " + m.title, 2.2)
	if m.id == "antenna":
		_set_antenna_fixed()

func _on_all_completed() -> void:
	hud.set_objective("اكتملت كل المهام")
	hud.show_toast("اكتملت مهمة القمر", 4.0)
	hud.clear_compass()
	_focus_marker("")
	SaveSystem.data["moon_completed"] = true
	SaveSystem.save_game()

func _on_marker_reached(marker_id: String) -> void:
	var m := missions.current()
	if m == null:
		return
	if m.kind == Mission.Kind.REACH or m.kind == Mission.Kind.RETURN:
		missions.report(m.kind, marker_id)
	else:
		# المنارة ليست هدف هذه المهمة: أعد تسليحها لمرة قادمة
		var mk := _markers.get(marker_id) as ObjectiveMarker
		if mk:
			mk.rearm()

func _on_interact_pressed() -> void:
	player.interact()
	if not detector.use_focus():
		hud.show_toast("لا شيء في متناول يدك", 1.2)

func _on_interact_used(interact_id: String, node: Interactable) -> void:
	match interact_id:
		"sample":
			missions.report(Mission.Kind.COLLECT, "sample")
			_collect_effect(node)
		"antenna":
			missions.report(Mission.Kind.INTERACT, "antenna")
		"oxygen_station":
			life.refill()
			hud.show_toast("امتلأ خزان الأكسجين", 1.6)

func _collect_effect(node: Interactable) -> void:
	var vis := node.get_node_or_null("Visual")
	if vis:
		var tw := create_tween()
		tw.tween_property(vis, "scale", Vector3(0.05, 0.05, 0.05), 0.25)
		tw.tween_callback(func(): node.queue_free())
	else:
		node.queue_free()

func _set_antenna_fixed() -> void:
	for node in get_tree().get_nodes_in_group("interactables"):
		if node is Interactable and (node as Interactable).interact_id == "antenna":
			var bulb := node.get_node_or_null("StatusBulb") as MeshInstance3D
			if bulb:
				bulb.material_override = MoonProps.emissive(Color("#53d98a"), 3.0)

func _on_focus_changed(target: Interactable) -> void:
	if target == null:
		hud.hide_prompt()
	else:
		hud.show_prompt(target.prompt)

func _on_landed(impact: float) -> void:
	if impact > 1.2:
		_puff(clampf(impact / 7.0, 0.3, 1.0))

func _puff(strength: float) -> void:
	if _puff_burst == null or player == null:
		return
	_puff_burst.global_position = player.global_position + Vector3.UP * 0.1
	_puff_burst.amount = clampi(int(14.0 + strength * 26.0), 8, 48)
	_puff_burst.restart()
	_puff_burst.emitting = true

func _on_oxygen_depleted() -> void:
	if _dead:
		return
	_dead = true
	hud.show_toast("نفد الأكسجين", 2.0)
	hud.set_controls_visible(false)
	var tw := create_tween()
	tw.tween_interval(RESPAWN_FADE)
	tw.tween_callback(_respawn)

func _respawn() -> void:
	player.velocity = Vector3.ZERO
	player.position = _spawn
	life.refill()
	hud.set_controls_visible(true)
	hud.show_toast("أُنقذت عند المركبة", 2.0)
	_dead = false

# ---------------------------------------------------------------- المنارات

func _focus_marker(id: String) -> void:
	_active_marker = null
	for key in _markers.keys():
		var mk := _markers[key] as ObjectiveMarker
		if mk == null:
			continue
		var on: bool = (key == id)
		mk.visible = on
		# الإخفاء وحده لا يوقف Area3D: بلا هذا تُسجَّل منارة غير نشطة كهدف
		mk.set_monitoring(on)
		if on:
			mk.rearm()
			_active_marker = mk

## هدف البوصلة: المنارة النشطة، أو أقرب عيّنة في مهمة الجمع
func _compass_target() -> Vector3:
	if _active_marker != null and _active_marker.visible:
		return _active_marker.global_position
	var m := missions.current()
	if m != null and m.kind == Mission.Kind.COLLECT:
		var best := Vector3.ZERO
		var best_d := INF
		for node in get_tree().get_nodes_in_group("interactables"):
			var it := node as Interactable
			if it == null or it.interact_id != m.target_id or not it.can_use():
				continue
			var d := it.global_position.distance_to(player.global_position)
			if d < best_d:
				best_d = d
				best = it.global_position
		if best_d < INF:
			return best
	return Vector3.INF

# ---------------------------------------------------------------- الإطار

func _process(delta: float) -> void:
	if player == null or cam == null:
		return
	player.camera_basis_yaw = cam.get_yaw_radians()

	if not _dead:
		life.consume(delta, player.is_moving(), player.is_running())

	# غبار الخطوات يعمل فقط أثناء المشي على الأرض
	if _dust:
		var walking: bool = player.is_on_floor() and player.is_moving()
		if walking:
			_dust.global_position = player.global_position + Vector3.UP * 0.08
		_dust.emitting = walking

	_update_compass()

func _update_compass() -> void:
	var target := _compass_target()
	if target.x == INF:
		hud.clear_compass()
		return
	var to := target - player.global_position
	var dist := Vector2(to.x, to.z).length()
	# الزاوية نسبةً إلى اتجاه نظر الكاميرا
	var world_ang := atan2(to.x, to.z)
	var cam_ang := cam.get_yaw_radians()
	var rel := wrapf(world_ang - cam_ang + PI, -PI, PI)
	hud.set_compass(rel, dist)
