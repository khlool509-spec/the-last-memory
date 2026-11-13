extends Control
## شاشة الإعدادات — لوحة دموية مؤطّرة، كل عنصر مربوط بمفتاح حقيقي
## في Settings ويُحفظ فوراً.

## عند التشغيل من داخل اللعبة (قائمة الإيقاف) لا نبدّل المشهد،
## بل نُغلق الطبقة ونعود إلى اللعب كما هو.
signal closed()

@export var embedded: bool = false
var _rows: Array = []

func _ready() -> void:
	name = "SettingsMenu"
	process_mode = Node.PROCESS_MODE_ALWAYS
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.build()

	var bg := AtmosphereBG.new()
	bg.fog_amount = 0.3
	bg.blood_glow = 0.3
	add_child(bg)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(880, 0)
	center.add_child(panel)

	var frame := OrnateFrame.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(frame)

	var col := VBoxContainer.new()
	col.layout_direction = Control.LAYOUT_DIRECTION_RTL
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	col.add_child(_header("الإعدادات"))
	col.add_child(_separator())

	_rows.append(_add(col, SettingSlider.new("master_volume", "الصوت", "♪")))
	_rows.append(_add(col, SettingSlider.new("music_volume", "الموسيقى", "♫")))
	_rows.append(_add(col, SettingSlider.new("sfx_volume", "المؤثرات", "♬")))
	_rows.append(_add(col, SettingSlider.new("camera_sensitivity", "حساسية الكاميرا", "◎")))

	col.add_child(_separator())

	_rows.append(_add(col, OptionCycler.new(
		"graphics_quality", "جودة الرسومات",
		["low", "medium", "high"], ["منخفضة", "متوسطة", "عالية"], "✦")))
	_rows.append(_add(col, OptionCycler.new(
		"language", "اللغة",
		["ar", "en"], ["العربية", "English"], "⌘")))
	_rows.append(_add(col, OptionCycler.new(
		"control_mode", "وضع التحكم",
		["touch", "joystick"], ["لمس", "عصا"], "✥")))
	_rows.append(_add(col, OptionCycler.new(
		"invert_y", "عكس المحور الرأسي",
		[false, true], ["معطّل", "مفعّل"], "↕")))
	_rows.append(_add(col, OptionCycler.new(
		"vibration", "الاهتزاز",
		[true, false], ["مفعّل", "معطّل"], "≋")))
	_rows.append(_add(col, OptionCycler.new(
		"show_fps", "عدّاد الإطارات",
		[false, true], ["مخفي", "ظاهر"], "⊞")))

	col.add_child(_separator())

	var actions := HBoxContainer.new()
	actions.layout_direction = Control.LAYOUT_DIRECTION_RTL
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 18)
	col.add_child(actions)

	var apply := Button.new()
	apply.text = "تطبيق"
	apply.custom_minimum_size = Vector2(210, 60)
	apply.pressed.connect(_on_apply)
	actions.add_child(apply)

	var reset := Button.new()
	reset.text = "إعادة تعيين"
	reset.custom_minimum_size = Vector2(210, 60)
	reset.pressed.connect(_on_reset)
	actions.add_child(reset)

	var back := Button.new()
	back.text = "رجوع"
	back.custom_minimum_size = Vector2(210, 60)
	back.pressed.connect(_on_back)
	actions.add_child(back)

	_entrance(panel)

func _add(parent: Node, row: Control) -> Control:
	parent.add_child(row)
	return row

func _header(txt: String) -> Control:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", UITheme.SIZE_HEADING + 6)
	l.add_theme_color_override("font_color", Palette.BLOOD_HOT)
	return l

func _separator() -> Control:
	var r := ColorRect.new()
	r.color = Palette.with_alpha(Palette.BLOOD, 0.5)
	r.custom_minimum_size = Vector2(0, 1)
	return r

func _entrance(panel: Control) -> void:
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.97, 0.97)
	panel.pivot_offset = panel.size * 0.5
	var tw := create_tween().set_parallel(true)
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(panel, "modulate:a", 1.0, 0.3)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.32)

func _on_apply() -> void:
	Settings.apply_all()
	Settings.save_settings()
	_flash("حُفظت الإعدادات")

func _on_reset() -> void:
	Settings.reset_to_defaults()
	for r in _rows:
		if r.has_method("_ready"):
			pass
	# تحديث العناصر من القيم الافتراضية
	for r in _rows:
		if r is SettingSlider:
			(r as SettingSlider).set_value(float(Settings.get_value((r as SettingSlider).key)))
		elif r is OptionCycler:
			(r as OptionCycler)._ready()
	_flash("أُعيد التعيين")

func _on_back() -> void:
	Settings.save_settings()
	if embedded:
		closed.emit()
		queue_free()
	else:
		Router.go_to("res://src/ui/screens/main_menu.tscn")

func _flash(msg: String) -> void:
	var l := Label.new()
	l.text = msg
	l.add_theme_color_override("font_color", Palette.EMBER)
	l.add_theme_font_size_override("font_size", UITheme.SIZE_BODY)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	l.offset_top = -90
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 0.0, 1.4).set_delay(0.6)
	tw.tween_callback(l.queue_free)
