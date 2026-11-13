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
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.build()

	add_child(AtmosphereBG.new())
	_build_title()
	_build_menu()
	_build_footer()
	_intro_animation()

func _build_title() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	box.anchor_left = 0.06
	box.anchor_right = 0.06
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = 0
	box.offset_top = -150
	box.custom_minimum_size = Vector2(560, 0)
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	var t1 := Label.new()
	t1.name = "TitleTop"
	t1.text = "الذاكرة"
	t1.add_theme_font_size_override("font_size", UITheme.SIZE_TITLE + 22)
	t1.add_theme_color_override("font_color", Palette.BONE)
	t1.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	t1.add_theme_constant_override("shadow_offset_y", 4)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(t1)

	var t2 := Label.new()
	t2.name = "TitleBottom"
	t2.text = "الأخيرة"
	t2.add_theme_font_size_override("font_size", UITheme.SIZE_TITLE + 22)
	t2.add_theme_color_override("font_color", Palette.BLOOD_HOT)
	t2.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	t2.add_theme_constant_override("shadow_offset_y", 4)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(t2)

	var rule := ColorRect.new()
	rule.color = Palette.with_alpha(Palette.BLOOD, 0.85)
	rule.custom_minimum_size = Vector2(0, 2)
	box.add_child(rule)

	var sub := Label.new()
	sub.name = "Subtitle"
	sub.text = "رحلة في أعماق الماضي…"
	sub.add_theme_font_size_override("font_size", UITheme.SIZE_BODY)
	sub.add_theme_color_override("font_color", Palette.DUST)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(sub)

func _build_menu() -> void:
	var list := VBoxContainer.new()
	list.name = "MenuList"
	list.layout_direction = Control.LAYOUT_DIRECTION_RTL
	list.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	list.anchor_left = 0.97
	list.anchor_right = 0.97
	list.anchor_top = 0.5
	list.anchor_bottom = 0.5
	list.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	list.grow_vertical = Control.GROW_DIRECTION_BOTH
	list.add_theme_constant_override("separation", 10)
	add_child(list)

	for item in ITEMS:
		var b := MenuButton3D.new(str(item["label"]))
		b.name = "Btn_" + str(item["id"])
		b.set_meta("action_id", str(item["id"]))
		b.pressed.connect(_on_item_pressed.bind(str(item["id"])))
		list.add_child(b)
		_buttons.append(b)

	_refresh_continue_state()
	if not _buttons.is_empty():
		_buttons[0].grab_focus()

func _build_footer() -> void:
	var v := Label.new()
	v.name = "Version"
	v.text = "v" + str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	v.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL)
	v.add_theme_color_override("font_color", Palette.MUTED)
	v.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
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
