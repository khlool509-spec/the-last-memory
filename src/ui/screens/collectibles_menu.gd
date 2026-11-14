extends Control
## شاشة المقتنيات — خانة لكل غرض معرّف في ItemDB.
## ما جُمع يُضيء باسمه ورمزه، وما لم يُجمع يبقى علامة استفهام.
## (كان الاختيار سابقاً يقارن أرقاماً بمعرّفات نصية فلا يضيء شيء أبداً.)

var _detail_name: Label
var _detail_desc: Label

func _ready() -> void:
	name = "CollectiblesMenu"
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.build()

	var bg := AtmosphereBG.new()
	bg.fog_amount = 0.35
	add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var root := VBoxContainer.new()
	root.layout_direction = Control.LAYOUT_DIRECTION_RTL
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 60
	root.offset_right = -60
	root.offset_top = 32
	root.offset_bottom = -32
	root.add_theme_constant_override("separation", 16)
	add_child(root)

	var ids: Array = ItemDB.all_ids()
	var owned: Array = SaveSystem.collected_ids()
	var have := 0
	for id in ids:
		if owned.has(id):
			have += 1

	var h := Label.new()
	h.text = "المقتنيات   %d / %d" % [have, ids.size()]
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_size_override("font_size", UITheme.SIZE_HEADING + 6)
	h.add_theme_color_override("font_color", Palette.BLOOD_HOT)
	root.add_child(h)

	var wrap := CenterContainer.new()
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(wrap)

	var grid := GridContainer.new()
	grid.columns = 6 if ids.size() > 4 else maxi(1, ids.size())
	grid.layout_direction = Control.LAYOUT_DIRECTION_RTL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	wrap.add_child(grid)

	for id in ids:
		grid.add_child(_slot(str(id), owned.has(id)))

	var detail := PanelContainer.new()
	detail.custom_minimum_size = Vector2(0, 96)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.with_alpha(Palette.VOID, 0.7)
	sb.border_color = Palette.with_alpha(Palette.SMOKE, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(14)
	detail.add_theme_stylebox_override("panel", sb)
	root.add_child(detail)

	var dcol := VBoxContainer.new()
	dcol.layout_direction = Control.LAYOUT_DIRECTION_RTL
	detail.add_child(dcol)

	_detail_name = Label.new()
	_detail_name.text = "اختر خانة"
	_detail_name.add_theme_font_size_override("font_size", UITheme.SIZE_BUTTON)
	_detail_name.add_theme_color_override("font_color", Palette.BONE)
	dcol.add_child(_detail_name)

	_detail_desc = Label.new()
	_detail_desc.text = "ما تجمعه في اللعبة يظهر هنا."
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL)
	_detail_desc.add_theme_color_override("font_color", Palette.DUST)
	dcol.add_child(_detail_desc)

	var back := Button.new()
	back.text = "رجوع"
	back.custom_minimum_size = Vector2(220, 60)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: Router.go_to("res://src/ui/screens/main_menu.tscn"))
	root.add_child(back)

func _slot(id: String, owned: bool) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(132, 132)

	var frame := OrnateFrame.new()
	frame.line_color = Palette.BLOOD if owned else Palette.SMOKE
	frame.accent_color = Palette.EMBER if owned else Palette.with_alpha(Palette.SMOKE, 0.7)
	frame.corner_len = 18.0
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.add_child(frame)

	var col := VBoxContainer.new()
	col.layout_direction = Control.LAYOUT_DIRECTION_RTL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(col)

	var g := Label.new()
	g.text = ItemDB.glyph(id) if owned else "؟"
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g.add_theme_font_size_override("font_size", UITheme.SIZE_TITLE - 6)
	g.add_theme_color_override("font_color", Palette.EMBER if owned else Palette.MUTED)
	col.add_child(g)

	var nm := Label.new()
	nm.text = ItemDB.display_name(id) if owned else "—"
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL - 3)
	nm.add_theme_color_override("font_color", Palette.DUST if owned else Palette.MUTED)
	col.add_child(nm)

	var hit := Button.new()
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.pressed.connect(func() -> void: _show(id, owned))
	p.add_child(hit)
	return p

func _show(id: String, owned: bool) -> void:
	if owned:
		_detail_name.text = ItemDB.display_name(id)
		_detail_desc.text = str(ItemDB.get_item(id).get("desc", ""))
	else:
		_detail_name.text = "لم يُكتشف بعد"
		_detail_desc.text = "ابحث عنه في الفصول."
