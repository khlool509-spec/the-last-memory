class_name HUD
extends CanvasLayer
## واجهة اللعب. تُركّب بالكود وتُبثّ منها إشارات نظيفة يستهلكها اللاعب،
## فلا يعرف اللاعب شيئاً عن اللمس ولا تعرف الواجهة شيئاً عن الفيزياء.

signal move_input(dir: Vector2)
signal look_input(delta: Vector2)
signal run_changed(active: bool)
signal jump_pressed()
signal interact_pressed()
signal inventory_pressed()
signal pause_pressed()
signal fire_changed(active: bool)
signal aim_changed(active: bool)
signal crouch_pressed()
signal prone_pressed()
signal reload_pressed()
signal autorun_toggled(active: bool)
signal swim_vertical(dir: int)          # ‎+1 صعود، ‎-1 غوص
signal weapon_selected(index: int)

var joystick: TouchJoystick
var look_area: TouchLookArea
var btn_run: ActionButton
var btn_jump: ActionButton
var btn_interact: ActionButton
var btn_inventory: ActionButton

var _prompt: InteractPrompt
var _toasts: Control
var _objective: Label
var _fps: Label
var _health_fill: ColorRect
var _stamina_fill: ColorRect
var _root: Control
var btn_fire: ActionButton
var btn_aim: ActionButton
var btn_crouch: ActionButton
var btn_prone: ActionButton
var btn_reload: ActionButton
var btn_autorun: ActionButton
var btn_swim_up: ActionButton
var btn_swim_down: ActionButton
var compass: CompassStrip
var minimap: MiniMap
var coords: CoordBar
var weapons: WeaponSlots
var _swim_box: Control
var _autorun_on := false

func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.name = "HUDRoot"
	_root.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UITheme.build()
	add_child(_root)

	_build_look_area()
	_build_joystick()
	_build_actions()
	_build_combat()
	_build_compass()
	_build_minimap()
	_build_coords()
	_build_weapons()
	_apply_saved_layout()
	_build_status()
	_build_objective()
	_build_prompt()
	_build_toasts()
	_build_pause()
	_build_fps()
	_fade_in()

# ---------- الإدخال ----------
func _build_look_area() -> void:
	look_area = TouchLookArea.new()
	look_area.name = "LookArea"
	look_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	look_area.anchor_left = 0.42
	look_area.offset_top = 110
	look_area.offset_bottom = -40
	look_area.look_delta.connect(func(d): look_input.emit(d))
	_root.add_child(look_area)

func _build_joystick() -> void:
	joystick = TouchJoystick.new()
	joystick.name = "Joystick"
	joystick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.anchor_right = 0.4
	joystick.anchor_top = 0.35
	joystick.anchor_bottom = 1.0
	joystick.offset_left = 10
	joystick.offset_bottom = -10
	joystick.direction_changed.connect(func(d): move_input.emit(d))
	_root.add_child(joystick)

func _build_actions() -> void:
	var holder := Control.new()
	holder.name = "Actions"
	holder.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.offset_left = -330
	holder.offset_top = -270
	holder.offset_right = -24
	holder.offset_bottom = -24
	_root.add_child(holder)

	btn_interact = ActionButton.new()
	btn_interact.glyph = "✋"
	btn_interact.label_text = "تفاعل"
	btn_interact.radius = 62.0
	btn_interact.accent = Palette.MOON_DIM
	btn_interact.position = Vector2(8, 24)
	btn_interact.tapped.connect(func(): interact_pressed.emit())
	holder.add_child(btn_interact)

	btn_jump = ActionButton.new()
	btn_jump.glyph = "⤒"
	btn_jump.label_text = "قفز"
	btn_jump.radius = 52.0
	btn_jump.position = Vector2(168, 128)
	btn_jump.tapped.connect(func(): jump_pressed.emit())
	holder.add_child(btn_jump)

	btn_run = ActionButton.new()
	btn_run.glyph = "»"
	btn_run.label_text = "ركض"
	btn_run.radius = 52.0
	btn_run.hold_mode = true
	btn_run.position = Vector2(168, 6)
	btn_run.pressed_changed.connect(func(v): run_changed.emit(v))
	holder.add_child(btn_run)

	btn_inventory = ActionButton.new()
	btn_inventory.glyph = "▤"
	btn_inventory.label_text = "الحقيبة"
	btn_inventory.radius = 42.0
	btn_inventory.accent = Palette.DUST
	btn_inventory.position = Vector2(-96, 86)
	btn_inventory.tapped.connect(func(): inventory_pressed.emit())
	holder.add_child(btn_inventory)


# ---------- عنقود القتال (ترتيب ببجي) ----------
## الترتيب مأخوذ من مرجع اللاعب: الإطلاق كبير أسفل يمين تحت الإبهام،
## والتصويب فوقه، وأوضاع الجسم (انبطاح/قرفصاء/قفز) عموداً يمينه،
## والتعبئة بجواره. كل زر موصول بإشارة حقيقية لا شكل فارغ.
func _build_combat() -> void:
	var box := Control.new()
	box.name = "Combat"
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.offset_left = -300
	box.offset_top = -430
	box.offset_right = -18
	box.offset_bottom = -150
	_root.add_child(box)

	btn_fire = ActionButton.new()
	btn_fire.glyph = "◎"
	btn_fire.label_text = "إطلاق"
	btn_fire.radius = 64.0
	btn_fire.hold_mode = true
	btn_fire.accent = Palette.BLOOD
	btn_fire.position = Vector2(14, 150)
	btn_fire.pressed_changed.connect(func(v): fire_changed.emit(v))
	box.add_child(btn_fire)

	btn_aim = ActionButton.new()
	btn_aim.glyph = "⊕"
	btn_aim.label_text = "تصويب"
	btn_aim.radius = 46.0
	btn_aim.hold_mode = true
	btn_aim.accent = Palette.MOON_DIM
	btn_aim.position = Vector2(42, 24)
	btn_aim.pressed_changed.connect(func(v): aim_changed.emit(v))
	box.add_child(btn_aim)

	btn_reload = ActionButton.new()
	btn_reload.glyph = "⟳"
	btn_reload.label_text = "تعبئة"
	btn_reload.radius = 42.0
	btn_reload.accent = Palette.DUST
	btn_reload.position = Vector2(-78, 150)
	btn_reload.tapped.connect(func(): reload_pressed.emit())
	box.add_child(btn_reload)

	btn_crouch = ActionButton.new()
	btn_crouch.glyph = "⌄"
	btn_crouch.label_text = "قرفصاء"
	btn_crouch.radius = 40.0
	btn_crouch.position = Vector2(178, 96)
	btn_crouch.tapped.connect(func(): crouch_pressed.emit())
	box.add_child(btn_crouch)

	btn_prone = ActionButton.new()
	btn_prone.glyph = "▁"
	btn_prone.label_text = "انبطاح"
	btn_prone.radius = 40.0
	btn_prone.position = Vector2(178, 10)
	btn_prone.tapped.connect(func(): prone_pressed.emit())
	box.add_child(btn_prone)

	# الركض التلقائي: مفتاح لا ضغطة مستمرّة، كما في ببجي تماماً —
	# يُفعَّل مرّة فيستمرّ حتى يُلمس ثانية أو يتوقّف اللاعب.
	btn_autorun = ActionButton.new()
	btn_autorun.glyph = "⇈"
	btn_autorun.label_text = "ركض تلقائي"
	btn_autorun.radius = 42.0
	btn_autorun.accent = Palette.MOON_DIM
	btn_autorun.position = Vector2(-86, 46)
	btn_autorun.tapped.connect(_toggle_autorun)
	box.add_child(btn_autorun)

	# أزرار السباحة: تظهر فقط داخل الماء، كما يفعل ببجي
	_swim_box = Control.new()
	_swim_box.name = "Swim"
	_swim_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_swim_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_swim_box.offset_left = -130
	_swim_box.offset_top = -110
	_swim_box.offset_right = -14
	_swim_box.offset_bottom = 110
	_swim_box.visible = false
	_root.add_child(_swim_box)

	btn_swim_up = ActionButton.new()
	btn_swim_up.glyph = "▲"
	btn_swim_up.label_text = "أعلى"
	btn_swim_up.radius = 44.0
	btn_swim_up.hold_mode = true
	btn_swim_up.position = Vector2(10, 4)
	btn_swim_up.pressed_changed.connect(
		func(v): swim_vertical.emit(1 if v else 0))
	_swim_box.add_child(btn_swim_up)

	btn_swim_down = ActionButton.new()
	btn_swim_down.glyph = "▼"
	btn_swim_down.label_text = "غوص"
	btn_swim_down.radius = 44.0
	btn_swim_down.hold_mode = true
	btn_swim_down.position = Vector2(10, 118)
	btn_swim_down.pressed_changed.connect(
		func(v): swim_vertical.emit(-1 if v else 0))
	_swim_box.add_child(btn_swim_down)

func _toggle_autorun() -> void:
	_autorun_on = not _autorun_on
	btn_autorun.accent = Palette.BLOOD if _autorun_on else Palette.MOON_DIM
	btn_autorun.queue_redraw()
	autorun_toggled.emit(_autorun_on)

## يُستدعى من اللاعب حين يدخل الماء أو يخرج منه
func set_swimming(on: bool) -> void:
	if _swim_box:
		_swim_box.visible = on

func set_autorun(on: bool) -> void:
	if _autorun_on == on:
		return
	_autorun_on = on
	if btn_autorun:
		btn_autorun.accent = Palette.BLOOD if on else Palette.MOON_DIM
		btn_autorun.queue_redraw()

# ---------- البوصلة والخريطة والإحداثيات ----------
func _build_compass() -> void:
	compass = CompassStrip.new()
	compass.name = "Compass"
	compass.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	# الشريط يمتدّ على كامل عرض الشاشة: كان محصوراً بين هامشين
	# 230 بكسل فيظهر منه قوس ضيّق لا يكفي للاهتداء.
	compass.offset_left = 8
	compass.offset_right = -8
	compass.offset_top = 6
	compass.offset_bottom = 52
	_root.add_child(compass)

func _build_minimap() -> void:
	minimap = MiniMap.new()
	minimap.name = "MiniMap"
	minimap.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	minimap.offset_left = -202
	minimap.offset_top = 14
	minimap.offset_right = -16
	minimap.offset_bottom = 200
	_root.add_child(minimap)

func _build_coords() -> void:
	coords = CoordBar.new()
	coords.name = "Coords"
	coords.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	coords.offset_left = 14
	coords.offset_top = -30
	coords.offset_right = 760
	coords.offset_bottom = -4
	_root.add_child(coords)

func _build_weapons() -> void:
	weapons = WeaponSlots.new()
	weapons.name = "Weapons"
	weapons.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	weapons.offset_left = -156
	weapons.offset_right = 156
	weapons.offset_top = -96
	weapons.offset_bottom = -44
	weapons.anchor_left = 0.5
	weapons.anchor_right = 0.5
	weapons.slot_selected.connect(func(i): weapon_selected.emit(i))
	_root.add_child(weapons)

## يُغذّيها اللاعب كل إطار: اتجاه، موقع، سرعة، حالة
func feed(pos: Vector3, yaw_deg: float, speed: float, state: String) -> void:
	if compass:
		compass.set_heading(yaw_deg)
		compass.set_player(Vector2(pos.x, pos.z))
	if minimap:
		minimap.set_player(Vector2(pos.x, pos.z), deg_to_rad(yaw_deg))
	if coords:
		coords.set_state(pos, yaw_deg, speed, state)


## ══════════ تطبيق مخطّط الأزرار المحفوظ ══════════
## هذه هي الحلقة الناقصة التي جعلت المحرّر يبدو معطّلاً: كان يحفظ
## المواضع فعلاً، لكن لا أحد يقرؤها عند بناء الواجهة فتعود الأزرار
## إلى أماكنها المبرمَجة في كل تشغيل.
##
## الأزرار تُنتزع من حاوياتها وتُعلَّق على الجذر مباشرة، لأن العقدة
## داخل حاوية موضعها تحسبه الحاوية لا نحن.
const LAYOUT_NODES := {
	"fire": "btn_fire", "aim": "btn_aim", "reload": "btn_reload",
	"crouch": "btn_crouch", "prone": "btn_prone", "autorun": "btn_autorun",
	"jump": "btn_jump", "interact": "btn_interact",
}

func _apply_saved_layout() -> void:
	var raw = Settings.get_value("hud_layout")
	if not (raw is Dictionary) or (raw as Dictionary).is_empty():
		return                      # لا مخطّط محفوظ: تبقى المواضع الأصلية
	var screen := _root.size
	if screen.x < 1.0:
		screen = get_viewport().get_visible_rect().size
	var lay := HudLayoutEditor.layout()
	for key in LAYOUT_NODES:
		if not (raw as Dictionary).has(key):
			continue
		var btn: Control = get(str(LAYOUT_NODES[key]))
		if btn == null:
			continue
		_reparent_free(btn)
		var c := HudLayoutEditor.to_pixels(lay[key], screen)
		btn.position = c - btn.size * 0.5
	if (raw as Dictionary).has("stick") and joystick:
		_reparent_free(joystick)
		var c := HudLayoutEditor.to_pixels(lay["stick"], screen)
		joystick.position = c - joystick.size * 0.5

## ينقل العقدة إلى الجذر محافظاً على حجمها، فيصير موضعها لنا
func _reparent_free(n: Control) -> void:
	var sz := n.size
	var parent := n.get_parent()
	if parent == _root:
		return
	parent.remove_child(n)
	_root.add_child(n)
	n.set_anchors_preset(Control.PRESET_TOP_LEFT)
	n.size = sz

## يُستدعى بعد حفظ مخطّط جديد: يعيد بناء المواضع بلا إعادة تحميل
func refresh_layout() -> void:
	_apply_saved_layout()

# ---------- الحالة ----------
func _build_status() -> void:
	var box := VBoxContainer.new()
	box.name = "Status"
	box.layout_direction = Control.LAYOUT_DIRECTION_LTR
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	box.offset_left = -330
	box.offset_right = -22
	box.offset_top = 20
	box.add_theme_constant_override("separation", 7)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)

	var name_row := Label.new()
	name_row.text = "المجهول"
	name_row.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL)
	name_row.add_theme_color_override("font_color", Palette.DUST)
	name_row.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	box.add_child(name_row)

	_health_fill = _bar(box, Palette.BLOOD_HOT, 1.0)
	_stamina_fill = _bar(box, Palette.MOON_DIM, 1.0)

func _bar(parent: Node, col: Color, ratio: float) -> ColorRect:
	var back := PanelContainer.new()
	back.custom_minimum_size = Vector2(300, 16)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.with_alpha(Palette.VOID, 0.75)
	sb.border_color = Palette.with_alpha(Palette.SMOKE, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(2)
	back.add_theme_stylebox_override("panel", sb)
	parent.add_child(back)

	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 12)
	back.add_child(holder)

	var fill := ColorRect.new()
	fill.color = col
	fill.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	fill.anchor_right = ratio
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(fill)
	return fill

func set_health(ratio: float) -> void:
	if _health_fill:
		create_tween().tween_property(_health_fill, "anchor_right", clampf(ratio, 0.0, 1.0), 0.25)

func set_stamina(ratio: float) -> void:
	if _stamina_fill:
		_stamina_fill.anchor_right = clampf(ratio, 0.0, 1.0)

# ---------- الهدف ----------
func _build_objective() -> void:
	var p := PanelContainer.new()
	p.name = "ObjectiveBox"
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	p.offset_top = 18
	p.offset_left = -300
	p.offset_right = 300
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.with_alpha(Palette.VOID, 0.6)
	sb.border_color = Palette.with_alpha(Palette.BLOOD, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", sb)
	_root.add_child(p)

	_objective = Label.new()
	_objective.text = "الهدف: استكشف المكان"
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL + 2)
	_objective.add_theme_color_override("font_color", Palette.BONE)
	p.add_child(_objective)

func set_objective(txt: String) -> void:
	if _objective == null:
		return
	_objective.text = txt
	var tw := create_tween()
	tw.tween_property(_objective, "modulate:a", 0.0, 0.12)
	tw.tween_property(_objective, "modulate:a", 1.0, 0.3)

# ---------- التفاعل والإشعارات ----------
func _build_prompt() -> void:
	_prompt = InteractPrompt.new()
	_prompt.name = "InteractPrompt"
	_root.add_child(_prompt)

func _build_toasts() -> void:
	_toasts = Control.new()
	_toasts.name = "Toasts"
	_toasts.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toasts)

func set_interact_prompt(text: String) -> void:
	if _prompt == null:
		return
	if text.strip_edges() == "":
		_prompt.hide_prompt()
	else:
		_prompt.show_prompt(text)
	if btn_interact:
		btn_interact.accent = Palette.BLOOD_HOT if text.strip_edges() != "" else Palette.MOON_DIM
		btn_interact.queue_redraw()

func toast(text: String, glyph: String = "", accent: Color = Palette.BLOOD) -> void:
	if _toasts == null:
		return
	for c in _toasts.get_children():
		if c is Toast:
			(c as Toast).modulate.a = 0.0
			c.queue_free()
	Toast.show_on(_toasts, text, glyph, accent)

# ---------- التحكم العلوي ----------
func _build_pause() -> void:
	var b := ActionButton.new()
	b.name = "PauseButton"
	b.glyph = "‖"
	b.radius = 34.0
	b.accent = Palette.SMOKE
	b.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	b.offset_left = 20
	b.offset_top = 20
	b.tapped.connect(func(): pause_pressed.emit())
	_root.add_child(b)

func _build_fps() -> void:
	_fps = Label.new()
	_fps.name = "FPS"
	_fps.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_fps.offset_left = 18
	_fps.offset_top = -34
	_fps.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL)
	_fps.add_theme_color_override("font_color", Palette.MOON_DIM)
	_fps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps.visible = bool(Settings.get_value("show_fps"))
	_root.add_child(_fps)
	Settings.changed.connect(func(k, v):
		if k == "show_fps":
			_fps.visible = bool(v))

func _process(_delta: float) -> void:
	if _fps and _fps.visible:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()

func _fade_in() -> void:
	_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.45).set_delay(0.15)

func set_controls_visible(v: bool) -> void:
	if joystick:
		joystick.visible = v
	if look_area:
		look_area.visible = v
	for b in [btn_run, btn_jump, btn_interact, btn_inventory]:
		if b:
			b.visible = v
	if _prompt and not v:
		_prompt.hide_prompt()
