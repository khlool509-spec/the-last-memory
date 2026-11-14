class_name HUD
extends CanvasLayer
## واجهة اللعب. تُركّب بالكود وتُبثّ منها إشارات نظيفة يستهلكها اللاعب،
## فلا يعرف اللاعب شيئاً عن اللمس ولا تعرف الواجهة شيئاً عن الفيزياء.

signal move_input(dir: Vector2)
signal look_input(delta: Vector2)
signal run_changed(active: bool)
signal jump_pressed()
signal interact_pressed()
signal pause_pressed()

var joystick: TouchJoystick
var look_area: TouchLookArea
var btn_run: ActionButton
var btn_jump: ActionButton
var btn_interact: ActionButton

var _objective: Label
var _fps: Label
var _health_fill: ColorRect
var _stamina_fill: ColorRect
var _root: Control
var _name_label: Label
var _prompt: PanelContainer
var _prompt_label: Label
var _compass: Control
var _compass_angle: float = 0.0
var _compass_distance: float = -1.0
var _toast: PanelContainer
var _toast_label: Label

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
	_build_status()
	_build_objective()
	_build_pause()
	_build_fps()
	_build_prompt()
	_build_compass()
	_build_toast()
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
	_name_label = name_row

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
	for b in [btn_run, btn_jump, btn_interact]:
		if b:
			b.visible = v

# ---------- الأكسجين ----------
## نفس الشريط الأول، لكن بدلالة الأكسجين ولونه يتدرّج مع الخطر
func set_oxygen(ratio: float) -> void:
	if _health_fill == null:
		return
	var r := clampf(ratio, 0.0, 1.0)
	_health_fill.anchor_right = r
	var col := Palette.MOON
	if r <= 0.15:
		col = Palette.BLOOD_HOT
	elif r <= 0.35:
		col = Palette.EMBER
	_health_fill.color = col

func set_player_name(txt: String) -> void:
	if _name_label:
		_name_label.text = txt

# ---------- نداء التفاعل ----------
func _build_prompt() -> void:
	_prompt = PanelContainer.new()
	_prompt.name = "InteractPrompt"
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_prompt.offset_left = -430
	_prompt.offset_right = -210
	_prompt.offset_top = -322
	_prompt.offset_bottom = -282
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.with_alpha(Palette.VOID, 0.78)
	sb.border_color = Palette.with_alpha(Palette.MOON_DIM, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(8)
	_prompt.add_theme_stylebox_override("panel", sb)
	_prompt.modulate.a = 0.0
	_root.add_child(_prompt)

	_prompt_label = Label.new()
	_prompt_label.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL)
	_prompt_label.add_theme_color_override("font_color", Palette.BONE)
	_prompt.add_child(_prompt_label)

func show_prompt(txt: String) -> void:
	if _prompt == null:
		return
	_prompt_label.text = txt
	create_tween().tween_property(_prompt, "modulate:a", 1.0, 0.15)

func hide_prompt() -> void:
	if _prompt == null:
		return
	create_tween().tween_property(_prompt, "modulate:a", 0.0, 0.15)

# ---------- بوصلة الهدف ----------
func _build_compass() -> void:
	_compass = Control.new()
	_compass.name = "Compass"
	_compass.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_compass.offset_top = 86
	_compass.offset_left = -60
	_compass.offset_right = 60
	_compass.offset_bottom = 60
	_compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compass.draw.connect(_draw_compass)
	_root.add_child(_compass)

## الزاوية بالراديان نسبةً إلى اتجاه الكاميرا: 0 = أمام اللاعب مباشرة
func set_compass(angle: float, distance: float) -> void:
	_compass_angle = angle
	_compass_distance = distance
	if _compass:
		_compass.visible = distance >= 0.0
		_compass.queue_redraw()

func clear_compass() -> void:
	set_compass(0.0, -1.0)

func _draw_compass() -> void:
	if _compass_distance < 0.0:
		return
	var c := Vector2(60, 26)
	var dir := Vector2(sin(_compass_angle), -cos(_compass_angle))
	var tip := c + dir * 20.0
	var left := c + dir.rotated(2.5) * 11.0
	var right := c + dir.rotated(-2.5) * 11.0
	var col := Palette.with_alpha(Palette.EMBER, 0.92)
	_compass.draw_colored_polygon(PackedVector2Array([tip, left, c, right]), col)
	var txt := "%d م" % int(round(_compass_distance))
	var font := _compass.get_theme_default_font()
	if font:
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		_compass.draw_string(font, Vector2(60 - w * 0.5, 54), txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.with_alpha(Palette.DUST, 0.95))

# ---------- إشعار ----------
func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.name = "Toast"
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_toast.offset_left = -330
	_toast.offset_right = 330
	_toast.offset_top = -120
	_toast.offset_bottom = -52
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.with_alpha(Palette.VOID, 0.84)
	sb.border_color = Palette.with_alpha(Palette.EMBER, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(14)
	_toast.add_theme_stylebox_override("panel", sb)
	_toast.modulate.a = 0.0
	_root.add_child(_toast)

	_toast_label = Label.new()
	_toast_label.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL + 6)
	_toast_label.add_theme_color_override("font_color", Palette.BONE)
	_toast.add_child(_toast_label)

func show_toast(txt: String, seconds: float = 2.4) -> void:
	if _toast == null:
		return
	_toast_label.text = txt
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.25)
	tw.tween_interval(seconds)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)
