extends Control
## شاشة الفصول — بطاقات مقفلة ومفتوحة حسب ملف الحفظ.

func _ready() -> void:
	name = "ChaptersMenu"
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.build()

	var bg := AtmosphereBG.new()
	bg.fog_amount = 0.55
	add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var root := VBoxContainer.new()
	root.layout_direction = Control.LAYOUT_DIRECTION_RTL
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 50
	root.offset_right = -50
	root.offset_top = 32
	root.offset_bottom = -32
	root.add_theme_constant_override("separation", 16)
	add_child(root)

	var h := Label.new()
	h.text = "الفصول"
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_size_override("font_size", UITheme.SIZE_HEADING + 8)
	h.add_theme_color_override("font_color", Palette.BLOOD_HOT)
	root.add_child(h)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var list := VBoxContainer.new()
	list.layout_direction = Control.LAYOUT_DIRECTION_RTL
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)

	for i in Chapters.DATA.size():
		list.add_child(_card(Chapters.DATA[i], i))

	var back := Button.new()
	back.text = "رجوع"
	back.custom_minimum_size = Vector2(220, 60)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): Router.go_to("res://src/ui/screens/main_menu.tscn"))
	root.add_child(back)

func _card(ch: Dictionary, index: int) -> Control:
	var n := int(ch["n"])
	var unlocked := SaveSystem.is_chapter_unlocked(n)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 112)
	panel.modulate = Color(1, 1, 1, 1.0 if unlocked else 0.45)

	var frame := OrnateFrame.new()
	frame.line_color = Palette.BLOOD if unlocked else Palette.SMOKE
	frame.accent_color = Palette.EMBER if unlocked else Palette.MUTED
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(frame)

	var row := HBoxContainer.new()
	row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	row.add_theme_constant_override("separation", 20)
	panel.add_child(row)

	var num := Label.new()
	num.text = "%02d" % n
	num.custom_minimum_size = Vector2(86, 0)
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.add_theme_font_size_override("font_size", UITheme.SIZE_TITLE)
	num.add_theme_color_override("font_color", Palette.BLOOD if unlocked else Palette.MUTED)
	row.add_child(num)

	var texts := VBoxContainer.new()
	texts.layout_direction = Control.LAYOUT_DIRECTION_RTL
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(texts)

	var title := Label.new()
	title.text = str(ch["ar"])
	title.add_theme_font_size_override("font_size", UITheme.SIZE_BUTTON)
	title.add_theme_color_override("font_color", Palette.BONE if unlocked else Palette.MUTED)
	texts.add_child(title)

	var en := Label.new()
	en.text = str(ch["en"])
	en.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL)
	en.add_theme_color_override("font_color", Palette.MOON_DIM)
	texts.add_child(en)

	var desc := Label.new()
	desc.text = str(ch["desc"]) if unlocked else "مقفل — أكمل الفصل السابق"
	if unlocked and not Chapters.is_playable(n):
		desc.text = str(ch["desc"]) + "  (قيد البناء)"
	desc.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL)
	desc.add_theme_color_override("font_color", Palette.DUST if unlocked else Palette.MUTED)
	texts.add_child(desc)

	var playable := unlocked and Chapters.is_playable(n)

	var status := Label.new()
	status.text = ("▶" if playable else "…") if unlocked else "🔒"
	status.custom_minimum_size = Vector2(70, 0)
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", UITheme.SIZE_HEADING)
	status.add_theme_color_override("font_color", Palette.EMBER if unlocked else Palette.MUTED)
	row.add_child(status)

	# زر شفاف فوق البطاقة: البطاقة كلها قابلة للنقر
	var hit := Button.new()
	hit.name = "Open"
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.disabled = not playable
	hit.mouse_filter = Control.MOUSE_FILTER_STOP if playable else Control.MOUSE_FILTER_IGNORE
	if playable:
		hit.pressed.connect(func() -> void: Router.go_to(Chapters.scene_path(n)))
	panel.add_child(hit)

	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(panel, "modulate:a", 1.0 if unlocked else 0.45, 0.3).set_delay(0.07 * float(index))
	return panel
