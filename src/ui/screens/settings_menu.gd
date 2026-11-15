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

	## التمرير: المحتوى أطول من شاشة الجوال، وCenterContainer كان
	## يقصّ ما يزيد فتختفي الإعدادات السفلية. ScrollContainer يسمح
	## بالسحب باللمس (Godot يحوّل اللمس إلى تمرير تلقائياً).
	## ثلاث طبقات: شريط علوي ثابت، ومنطقة تمرير، وشريط سفلي ثابت.
	## السبب أن زرّي الإغلاق والحفظ يجب أن يبقيا مرئيين مهما نزل
	## اللاعب في القائمة — وإلا احتاج التمرير إلى الأسفل ليحفظ.
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["top", "bottom", "left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)

	var outer := VBoxContainer.new()
	outer.layout_direction = Control.LAYOUT_DIRECTION_RTL
	outer.add_theme_constant_override("separation", 8)
	margin.add_child(outer)

	outer.add_child(_top_bar())

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# منطقة ميتة للسحب: بدونها تخطف المنزلقات اللمسة فلا تتمرّر
	# الشاشة أبداً. 28 بكسلاً تكفي لتمييز سحب رأسي عن ضبط منزلق.
	scroll.add_theme_constant_override("scroll_deadzone", 28)
	outer.add_child(scroll)

	# صفّ أفقي يوسّط اللوحة دون أن يقيّد ارتفاعها
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	scroll.add_child(row)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	# عرض متجاوب: يملأ الشاشات العريضة بدل عمود ضيّق وسط سواد
	var vw := float(get_viewport_rect().size.x)
	panel.custom_minimum_size = Vector2(clampf(vw * 0.62, 620.0, 1180.0), 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(panel)

	var frame := OrnateFrame.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(frame)

	var col := VBoxContainer.new()
	col.layout_direction = Control.LAYOUT_DIRECTION_RTL
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	_rows.append(_add(col, SettingSlider.new("master_volume", "الصوت", "♪")))
	_rows.append(_add(col, SettingSlider.new("music_volume", "الموسيقى", "♫")))
	_rows.append(_add(col, SettingSlider.new("sfx_volume", "المؤثرات", "♬")))
	_rows.append(_add(col, SettingSlider.new("camera_sensitivity", "حساسية الكاميرا", "◎")))
	_rows.append(_add(col, SettingSlider.new("brightness", "سطوع الصورة", "☀")))

	col.add_child(_separator())

	_rows.append(_add(col, OptionCycler.new(
		"time_of_day", "وقت اليوم",
		Daylight.KEYS, Daylight.LABELS, "◐")))

	col.add_child(_header("الرسومات"))

	# الإعداد الجاهز يضبط الباقي دفعة واحدة؛ أي تعديل يدوي بعده
	# ينقل الإعداد إلى «مخصص» تلقائياً.
	_rows.append(_add(col, OptionCycler.new(
		"gfx_preset", "تفضيلات الرسومات",
		["auto", "custom", "lite", "fps", "balanced", "quality"],
		["تلقائي حسب الجهاز", "مخصص", "مخففة للأجهزة الضعيفة",
		 "معدل إطارات أفضل", "متوازنة", "رسومات أفضل"], "✧")))

	_rows.append(_add(col, OptionCycler.new(
		"gfx_quality", "الرسومات",
		Graphics.QUALITY_ORDER,
		Graphics.QUALITY_ORDER.map(func(k): return Graphics.quality_label(k)), "✦")))

	_rows.append(_add(col, OptionCycler.new(
		"gfx_fps_tier", "إعدادات معدل الإطارات",
		Graphics.FPS_ORDER,
		Graphics.FPS_ORDER.map(func(k): return Graphics.fps_label(k)), "⏱")))

	_rows.append(_add(col, OptionCycler.new(
		"gfx_fps_manual", "تعديل معدّل الإطارات",
		[false, true], ["ضبط ذكي", "ضبط يدوي"], "⚙")))

	_rows.append(_add(col, SettingSlider.new("gfx_fps_cap", "معدل الإطارات", "▦",
		20.0, 120.0, 1.0)))

	_rows.append(_add(col, OptionCycler.new(
		"gfx_style", "نمط الرسوم",
		Graphics.STYLE_ORDER,
		Graphics.STYLE_ORDER.map(func(k): return Graphics.style_label(k)), "◈")))

	col.add_child(_header("إعدادات الرسومات المتقدمة"))

	_rows.append(_add(col, OptionCycler.new(
		"gfx_adaptive", "الرسومات التكيفية",
		[true, false], ["تفعيل", "تعطيل"], "⟳")))
	_rows.append(_add(col, OptionCycler.new(
		"gfx_shadows", "الظلال",
		[true, false], ["تفعيل", "تعطيل"], "◗")))
	_rows.append(_add(col, OptionCycler.new(
		"gfx_antialiasing", "تنعيم الحواف",
		[true, false], ["تفعيل", "تعطيل"], "◍")))
	_rows.append(_add(col, OptionCycler.new(
		"gfx_power_save", "توفير الطاقة",
		[false, true], ["تعطيل", "تفعيل"], "⚡")))

	_rows.append(_add(col, OptionCycler.new(
		"gfx_colorblind", "وضع عمى الألوان",
		Graphics.CB_ORDER,
		Graphics.CB_ORDER.map(func(k): return str(Graphics.CB_LABEL[k])), "◉")))

	_rows.append(_add(col, OptionCycler.new(
		"gfx_texture_res", "دقة الخامات",
		["512", "1k"], ["منخفضة (أخف)", "عالية"], "▣")))

	_rows.append(_add(col, OptionCycler.new(
		"gfx_show_fps", "عداد الإطارات",
		[false, true], ["إخفاء", "إظهار"], "📊")))

	# محرّر مواضع الأزرار: يفتح شاشة سحب فوق الإعدادات
	var edit_row := HBoxContainer.new()
	edit_row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	edit_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var edit_btn := Button.new()
	edit_btn.text = "✥  تعديل أزرار الشاشة"
	edit_btn.custom_minimum_size = Vector2(340, 58)
	edit_btn.add_theme_font_size_override("font_size", 21)
	edit_btn.pressed.connect(_open_layout_editor)
	edit_row.add_child(edit_btn)
	col.add_child(edit_row)

	_rows.append(_add(col, SettingSlider.new("ui_safe_area",
		"واجهة الشاشات غير القياسية", "▭", 0.0, 1.0, 0.05)))

	col.add_child(_separator())

	_rows.append(_add(col, OptionCycler.new(
		"graphics_quality", "تفصيل العالم",
		["low", "medium", "high"], ["منخفض", "متوسط", "عالٍ"], "✣")))
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

	outer.add_child(_bottom_bar())
	_entrance(panel)


## الشريط العلوي: العنوان وزرّ الإغلاق. يبقى ثابتاً فوق التمرير.
func _top_bar() -> Control:
	var bar := PanelContainer.new()
	bar.name = "TopBar"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.04, 0.05, 0.92)
	sb.border_color = Palette.BLOOD
	sb.border_width_bottom = 2
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	bar.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.layout_direction = Control.LAYOUT_DIRECTION_RTL
	h.add_theme_constant_override("separation", 12)
	bar.add_child(h)

	var title := Label.new()
	title.text = "الإعدادات"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", UITheme.SIZE_HEADING + 4)
	title.add_theme_color_override("font_color", Palette.BLOOD_HOT)
	h.add_child(title)

	# زرّ الإغلاق: يحفظ ثم يخرج. الخروج بلا حفظ يفقد عمل اللاعب.
	var x := Button.new()
	x.name = "CloseButton"
	x.text = "✕"
	x.custom_minimum_size = Vector2(62, 54)
	x.add_theme_font_size_override("font_size", 26)
	x.tooltip_text = "إغلاق والعودة"
	x.pressed.connect(_on_back)
	h.add_child(x)
	return bar

## الشريط السفلي: الحفظ وما يتبعه. يبقى ثابتاً تحت التمرير.
func _bottom_bar() -> Control:
	var bar := PanelContainer.new()
	bar.name = "BottomBar"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.04, 0.05, 0.92)
	sb.border_color = Palette.BLOOD
	sb.border_width_top = 2
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	bar.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.layout_direction = Control.LAYOUT_DIRECTION_RTL
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 14)
	bar.add_child(h)

	var save := Button.new()
	save.name = "SaveButton"
	save.text = "حفظ الإعدادات"
	save.custom_minimum_size = Vector2(250, 58)
	save.add_theme_font_size_override("font_size", 22)
	save.pressed.connect(_on_apply)
	h.add_child(save)

	var reset_gfx := Button.new()
	reset_gfx.text = "إعادة ضبط الرسومات"
	reset_gfx.custom_minimum_size = Vector2(230, 58)
	reset_gfx.pressed.connect(_on_reset_graphics)
	h.add_child(reset_gfx)

	var reset := Button.new()
	reset.text = "إعادة تعيين الكل"
	reset.custom_minimum_size = Vector2(210, 58)
	reset.pressed.connect(_on_reset)
	h.add_child(reset)
	return bar

## يفتح محرّر مواضع أزرار الشاشة فوق الإعدادات
func _open_layout_editor() -> void:
	var ed := HudLayoutEditor.new()
	var layer := CanvasLayer.new()
	layer.layer = 60
	layer.add_child(ed)
	ed.closed.connect(func() -> void: layer.queue_free())
	add_child(layer)

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

## يعيد مفاتيح الرسومات وحدها إلى الافتراضي، ولا يمسّ الصوت
## ولا التحكّم ولا الحفظ — وهو ما يفعله الزرّ في الصورة المرجعية.
func _on_reset_graphics() -> void:
	for k in Settings.DEFAULTS:
		if str(k).begins_with("gfx_") or k == "ui_safe_area" or k == "brightness":
			Settings.set_value(k, Settings.DEFAULTS[k])
	Settings.save_settings()
	for r in _rows:
		if r.has_method("refresh_from_settings"):
			r.refresh_from_settings()
