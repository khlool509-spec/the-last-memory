class_name GameLevel
extends Node3D
## أساس كل مرحلة لعب: لاعب + كاميرا + واجهة + حقيبة + تفاعل + إيقاف،
## كلها موصولة مرة واحدة هنا. المراحل ترث وتبني المحتوى فقط.

@export var chapter_index: int = 1
@export var spawn_point: Vector3 = Vector3(0, 1.2, 0)
@export var spawn_yaw_deg: float = 0.0
@export var ambient_key: String = "forest"

var player: Player
var cam: FollowCamera
var hud: HUD
var pause_menu: PauseMenu
var interactor: Interactor
var inventory_ui: InventoryPanel
var note_reader: NoteReader
var mod_menu: ModMenu

func _ready() -> void:
	build_world()
	_build_player()
	_build_camera()
	_build_ui()
	_wire()
	place_contents()
	# موسيقى القائمة منفصلة عن اللعب: لا يعاد استخدام مسار القائمة داخل العالم.
	Audio.stop_music()
	if ambient_key != "":
		Audio.play_ambient(ambient_key)
	Goals.start_chapter(chapter_index)
	hud.set_objective(Goals.current_text)
	_mark_chapter_reached()

## للتجاوز: البيئة والأرض والأشجار
func build_world() -> void:
	pass

## للتجاوز: الأغراض والأوراق والأبواب والمحفزات
func place_contents() -> void:
	pass

# ---------- اللاعب ----------
func _build_player() -> void:
	player = Player.new()
	player.name = "Player"
	# Terrain3D uses physics layer 3 (bit 4); retain layer 1 for regular bodies.
	player.collision_layer = 1
	player.collision_mask = 1 | (1 << 2)
	player.position = spawn_point
	player.rotation.y = deg_to_rad(spawn_yaw_deg)

	# شخصية بشرية مفصليّة بدل الكبسولة. الجنس يُقرأ من الإعدادات،
	# ويُختار من شاشة ما قبل اللعب.
	# أولوية المجسّم المرخّص إن وُجد، والمفصلي احتياطاً. هكذا يكفي
	# إسقاط ملف ‎.glb في المجلّد ليحلّ محلّ الشخصية بلا تعديل كود.
	var gender := str(Settings.get_value("character_gender"))
	var model := CharacterModel.new()
	model.name = "Model"
	player.add_child(model)
	# ‎.glb أو ‎.fbx: Godot 4 يستورد الاثنين، ومصادر الأصول تختلف
	var want := 1.80 if gender == "male" else 1.68
	var found := ""
	for ext in [".glb", ".fbx", ".gltf"]:
		var cand := "res://assets/models/characters/%s%s" % [gender, ext]
		if ResourceLoader.exists(cand):
			found = cand
			break
	if found != "" and model.load_model(found, want):
		player.set("model", model)
	else:
		model.queue_free()
		var rig := CharacterRig.create(gender)
		player.add_child(rig)
		player.set("rig", rig)

	var shape := CollisionShape3D.new()
	shape.name = "Collider"        # باسمه يجده تبديل الوضع ليغيّر الارتفاع
	var cs := CapsuleShape3D.new()
	cs.radius = 0.33
	cs.height = 1.75
	shape.shape = cs
	shape.position = Vector3(0, 0.875, 0)
	player.add_child(shape)

	# فانوس محمول: مصدر الضوء القريب الذي يجعل الليل قابلاً للعب
	var hand := OmniLight3D.new()
	hand.name = "HandLight"
	hand.light_color = Color(1.0, 0.78, 0.52)
	hand.light_energy = 1.5
	hand.omni_range = 7.5
	hand.omni_attenuation = 1.6
	hand.shadow_enabled = false
	hand.position = Vector3(0.3, 1.15, -0.25)
	player.add_child(hand)

	interactor = Interactor.new()
	interactor.name = "Interactor"
	interactor.position = Vector3(0, 1.1, 0)
	player.add_child(interactor)

	add_child(player)

func _build_camera() -> void:
	cam = FollowCamera.new()
	cam.name = "FollowCamera"
	add_child(cam)
	cam.set_target(player)
	cam.yaw = deg_to_rad(spawn_yaw_deg)
	cam.global_position = player.global_position + Vector3.UP * cam.height

func _build_ui() -> void:
	hud = HUD.new()
	hud.name = "HUD"
	add_child(hud)

	var overlays := CanvasLayer.new()
	overlays.name = "Overlays"
	overlays.layer = 20
	add_child(overlays)

	inventory_ui = InventoryPanel.new()
	inventory_ui.name = "InventoryPanel"
	overlays.add_child(inventory_ui)

	note_reader = NoteReader.new()
	note_reader.name = "NoteReader"
	overlays.add_child(note_reader)

	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)

	mod_menu = ModMenu.new()
	mod_menu.name = "ModMenu"
	add_child(mod_menu)
	mod_menu.setup(player)

# ---------- التوصيل ----------
func _wire() -> void:
	hud.move_input.connect(func(d: Vector2) -> void: player.set_move_input(d))
	hud.look_input.connect(func(d: Vector2) -> void: cam.apply_look(d))
	hud.run_changed.connect(func(v: bool) -> void: player.set_run(v))
	hud.jump_pressed.connect(func() -> void: player.try_jump())
	hud.interact_pressed.connect(_on_interact)
	hud.inventory_pressed.connect(func() -> void: inventory_ui.open_panel())
	hud.pause_pressed.connect(func() -> void: pause_menu.toggle())

	# أزرار ببجي موصولة بسلوك حقيقي لا بشكل فارغ
	hud.fire_changed.connect(func(v: bool) -> void: player.set_fire(v))
	hud.aim_changed.connect(func(v: bool) -> void: player.set_aim(v))
	hud.crouch_pressed.connect(func() -> void: player.toggle_crouch())
	hud.prone_pressed.connect(func() -> void: player.toggle_prone())
	hud.reload_pressed.connect(func() -> void: hud.toast("تعبئة", "⟳", Palette.DUST))
	hud.autorun_toggled.connect(func(v: bool) -> void: player.set_auto_run(v))
	hud.swim_vertical.connect(func(d: int) -> void: player.set_swim_vertical(d))
	# دخول الماء يُظهر أزرار السباحة والغوص ويخفيها عند الخروج
	player.swim_changed.connect(func(v: bool) -> void: hud.set_swimming(v))
	player.stance_changed.connect(func(_st: String) -> void: pass)
	player.set_water_level(WorldProfile.WATER_LEVEL)

	# مدنيّون يسكنون العالم: المكان المأهول يُقرأ غير الخالي
	var civ := Civilians.new()
	civ.name = "Civilians"
	add_child(civ)
	civ.setup(WorldProfile.new(), player)

	# تعليمات التحكّم: تُعرض مرّة واحدة لمن لم يُتمّها بعد. كل خطوة
	# تنتظر أن يفعلها اللاعب فعلاً لا أن يقرأها، فمن يعرف اللعب
	# يتجاوزها في ثوانٍ ومن لا يعرف تبقى أمامه حتى يفهم.
	if not Tutorial.already_done():
		var tut := Tutorial.new()
		tut.setup(player)
		add_child(tut)

	# خبز الخريطة المصغّرة مرّة واحدة من بيانات العالم نفسها.
	# البديل — كاميرا ثانية تصوّر من فوق كل إطار — يكلّف ثلث معدّل
	# الإطارات على معالج جوال، وهو ثمن لا يستحقّه مربّع صغير.
	# معالم الشريط: المباني والبوابة والنهر. الشريط يصير خريطة
	# اتجاهات لا مجرّد درجات — تلتفت حتى يتوسّط المعلم ثم تمشي.
	if hud.compass:
		var lms: Array = []
		for nm in ["AncientGate", "OldHouse", "Hut", "Bridge", "Camp"]:
			var n := _find_named(self, nm)
			if n is Node3D:
				lms.append({
					"pos": Vector2((n as Node3D).global_position.x,
						(n as Node3D).global_position.z),
					"name": {"AncientGate": "البوابة", "OldHouse": "البيت",
						"Hut": "الكوخ", "Bridge": "الجسر",
						"Camp": "المخيّم"}.get(nm, nm),
					"color": Color(1.0, 0.86, 0.45),
				})
		hud.compass.set_landmarks(lms)

	if hud.minimap:
		var wp := WorldProfile.new()
		hud.minimap.world_half = WorldProfile.HALF
		var river := PackedVector2Array()
		var wr := get_node_or_null("WorldRenderer")
		if wr and wr.get("data") != null and wr.data.get("river_points") != null:
			river = wr.data.river_points
		hud.minimap.bake(wp, river)

	player.stamina_changed.connect(func(r: float) -> void: hud.set_stamina(r))
	interactor.target_changed.connect(func(_t: Interactable, txt: String) -> void:
		hud.set_interact_prompt(txt))

	inventory_ui.closed.connect(func() -> void: hud.set_controls_visible(true))
	inventory_ui.note_opened.connect(func(id: String) -> void: note_reader.open(id))
	note_reader.closed.connect(func() -> void: hud.set_controls_visible(true))

	Inv.item_added.connect(_on_item_added)
	Inv.note_added.connect(_on_note_added)
	Goals.objective_changed.connect(func(txt: String) -> void: hud.set_objective(txt))

func _on_interact() -> void:
	if not interactor.try_use():
		hud.toast("لا شيء هنا", "", Palette.SMOKE)

func _on_item_added(id: String) -> void:
	hud.toast("حصلت على: " + ItemDB.display_name(id), ItemDB.glyph(id), Palette.BLOOD)

func _on_note_added(id: String) -> void:
	hud.toast("ورقة جديدة: " + ItemDB.display_name(id), "✉", Palette.MOON_DIM)

func read_note(id: String) -> void:
	hud.set_controls_visible(false)
	note_reader.open(id)

func _mark_chapter_reached() -> void:
	SaveSystem.data["chapter"] = chapter_index
	SaveSystem.unlock_chapter(chapter_index)
	SaveSystem.data["player_position"] = [player.position.x, player.position.y, player.position.z]
	SaveSystem.save_game()

## بحث بالاسم في الشجرة — تحتاجه معالم البوصلة
func _find_named(root: Node, nm: String) -> Node:
	if root.name == nm:
		return root
	for c in root.get_children():
		var r := _find_named(c, nm)
		if r != null:
			return r
	return null

func _feed_hud() -> void:
	if player == null or hud == null:
		return
	var yaw := fposmod(rad_to_deg(-cam.rotation.y if cam else -player.rotation.y),
		360.0)
	var spd := Vector2(player.velocity.x, player.velocity.z).length()
	hud.feed(player.global_position, yaw, spd, player.state_label())

func _process(_delta: float) -> void:
	if player and cam:
		player.camera_basis_yaw = cam.get_yaw_radians()
