extends Control
## القائمة الرئيسية — تطابق الهوية المعتمدة: خلفية ليلية، عنوان دموي
## على اليسار، وقائمة عمودية على اليمين بتخطيط RTL.

const ITEMS := [
	{"id": "new_game", "label": "لعبة جديدة"},
	{"id": "continue", "label": "متابعة اللعب"},
	{"id": "settings", "label": "الإعدادات"},
	{"id": "chapters", "label": "الفصول"},
	{"id": "collectibles", "label": "المقتنيات"},
	{"id": "quit", "label": "الخروج"},
]

var _buttons: Array[Button] = []

func _ready() -> void:
	name = "MainMenu"
	# الهندسة LTR عمداً: المراسي تنعكس تحت RTL وتكسر التخطيط.
	# اتجاه النص RTL يُضبط على العناصر النصية وحدها.
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.build()

	add_child(AtmosphereBG.new())

	var margin := MarginContainer.new()
	margin.layout_direction = Control.LAYOUT_DIRECTION_LTR
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_right", 46)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 46)
	add_child(margin)

	var row := HBoxContainer.new()
	row.layout_direction = Control.LAYOUT_DIRECTION_LTR
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(row)

	row.add_child(_build_title())

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	row.add_child(_build_menu())
	_build_footer()
	_intro_animation()

func _build_title() -> Control:
	var box := VBoxContainer.new()
	box.name = "TitleBlock"
	box.layout_direction = Control.LAYOUT_DIRECTION_RTL
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(540, 0)
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	box.add_child(_title_line("الذاكرة", Palette.BONE))
	box.add_child(_title_line("الأخيرة", Palette.BLOOD_HOT))

	var drip := BloodDrip.new()
	drip.drip_count = 9
	drip.max_length = 52.0
	box.add_child(drip)

	var sub := Label.new()
	sub.name = "Subtitle"
	sub.text = "رحلة في أعماق الماضي…"
	sub.layout_direction = Control.LAYOUT_DIRECTION_RTL
	sub.add_theme_font_size_override("font_size", UITheme.SIZE_BODY)
	sub.add_theme_color_override("font_color", Palette.DUST)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(sub)
	return box

func _title_line(txt: String, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.layout_direction = Control.LAYOUT_DIRECTION_RTL
	l.add_theme_font_size_override("font_size", UITheme.SIZE_TITLE + 18)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_y", 4)
	l.add_theme_constant_override("shadow_outline_size", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l

func _build_menu() -> Control:
	var list := VBoxContainer.new()
	list.name = "MenuList"
	list.layout_direction = Control.LAYOUT_DIRECTION_RTL
	list.alignment = BoxContainer.ALIGNMENT_CENTER
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)

	for item in ITEMS:
		var b := MenuButton3D.new(str(item["label"]))
		b.name = "Btn_" + str(item["id"])
		b.set_meta("action_id", str(item["id"]))
		b.pressed.connect(_on_item_pressed.bind(str(item["id"])))
		list.add_child(b)
		_buttons.append(b)

	_refresh_continue_state()
	if not _buttons.is_empty():
		_buttons[0].call_deferred("grab_focus")
	return list

func _build_footer() -> void:
	var v := Label.new()
	v.name = "Version"
	v.text = "v" + str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	v.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL)
	v.add_theme_color_override("font_color", Palette.MUTED)
	v.layout_direction = Control.LAYOUT_DIRECTION_LTR
	v.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	v.offset_left = 18
	v.offset_top = -38
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)

func _refresh_continue_state() -> void:
	var has_save := FileAccess.file_exists(SaveSystem.SAVE_PATH)
	for b in _buttons:
		if b.get_meta("action_id", "") == "continue":
			b.disabled = not has_save
			b.tooltip_text = "" if has_save else "لا توجد لعبة محفوظة"

func _intro_animation() -> void:
	for i in _buttons.size():
		var b := _buttons[i]
		b.modulate.a = 0.0
		b.position.x -= 60
		var tw := create_tween().set_parallel(true)
		tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(b, "modulate:a", 1.0, 0.35).set_delay(0.08 * float(i))
		tw.tween_property(b, "position:x", b.position.x + 60, 0.4).set_delay(0.08 * float(i))

func _on_item_pressed(id: String) -> void:
	match id:
		"new_game":
			SaveSystem.start_new_game()
			Router.go_to("res://levels/test/playground.tscn")
		"continue":
			SaveSystem.load_game()
			Router.go_to("res://levels/test/playground.tscn")
		"settings":
			Router.go_to("res://src/ui/screens/settings_menu.tscn")
		"chapters":
			Router.go_to("res://src/ui/screens/chapters_menu.tscn")
		"collectibles":
			Router.go_to("res://src/ui/screens/collectibles_menu.tscn")
		"quit":
			Router.quit_game()
