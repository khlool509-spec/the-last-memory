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

func _ready() -> void:
	build_world()
	_build_player()
	_build_camera()
	_build_ui()
	_wire()
	place_contents()
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
	player.position = spawn_point
	player.rotation.y = deg_to_rad(spawn_yaw_deg)

	var body := MeshInstance3D.new()
	body.name = "Body"
	var cap := CapsuleMesh.new()
	cap.radius = 0.33
	cap.height = 1.75
	body.mesh = cap
	body.material_override = ForestBuilder.mat(Color(0.173, 0.184, 0.212), 0.85)
	body.position = Vector3(0, 0.875, 0)
	player.add_child(body)

	var head := MeshInstance3D.new()
	head.name = "Head"
	var hm := SphereMesh.new()
	hm.radius = 0.19
	hm.height = 0.38
	hm.radial_segments = 10
	hm.rings = 6
	head.mesh = hm
	head.material_override = ForestBuilder.mat(Color(0.251, 0.235, 0.216), 0.8)
	head.position = Vector3(0, 1.72, 0)
	player.add_child(head)

	# وشاح أحمر: نفس لون هوية اللعبة، يميّز الشخصية في الظلام
	var scarf := MeshInstance3D.new()
	scarf.name = "Scarf"
	var sm := CylinderMesh.new()
	sm.top_radius = 0.22
	sm.bottom_radius = 0.26
	sm.height = 0.2
	sm.radial_segments = 10
	scarf.mesh = sm
	scarf.material_override = ForestBuilder.mat(Color(0.431, 0.055, 0.086), 0.75)
	scarf.position = Vector3(0, 1.46, 0)
	player.add_child(scarf)

	var shape := CollisionShape3D.new()
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

# ---------- التوصيل ----------
func _wire() -> void:
	hud.move_input.connect(func(d: Vector2) -> void: player.set_move_input(d))
	hud.look_input.connect(func(d: Vector2) -> void: cam.apply_look(d))
	hud.run_changed.connect(func(v: bool) -> void: player.set_run(v))
	hud.jump_pressed.connect(func() -> void: player.try_jump())
	hud.interact_pressed.connect(_on_interact)
	hud.inventory_pressed.connect(func() -> void: inventory_ui.open_panel())
	hud.pause_pressed.connect(func() -> void: pause_menu.toggle())

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

func _process(_delta: float) -> void:
	if player and cam:
		player.camera_basis_yaw = cam.get_yaw_radians()
