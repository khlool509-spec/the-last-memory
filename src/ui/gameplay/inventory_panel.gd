class_name InventoryPanel
extends Control
## الحقيبة داخل اللعب: شبكة أغراض + تبويب المذكرات. تُوقف اللعب أثناء فتحها.

signal closed()
signal note_opened(item_id: String)

var _grid: GridContainer
var _notes_col: VBoxContainer
var _detail: Label
var _detail_name: Label
var _tab_items: Button
var _tab_notes: Button
var _items_page: Control
var _notes_page: Control
var _empty: Label
var _selected := ""

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	modulate.a = 0.0

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", 90)
	frame.add_theme_constant_override("margin_right", 90)
	frame.add_theme_constant_override("margin_top", 48)
	frame.add_theme_constant_override("margin_bottom", 48)
	add_child(frame)

	var col := VBoxContainer.new()
	col.layout_direction = Control.LAYOUT_DIRECTION_LTR
	col.add_theme_constant_override("separation", 18)
	frame.add_child(col)

	col.add_child(_header())
	col.add_child(_tabs())

	var body := Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)

	_items_page = _build_items_page()
	body.add_child(_items_page)
	_notes_page = _build_notes_page()
	body.add_child(_notes_page)

	var close := Button.new()
	close.text = "رجوع"
	close.custom_minimum_size = Vector2(0, 60)
	close.layout_direction = Control.LAYOUT_DIRECTION_RTL
	close.pressed.connect(close_panel)
	col.add_child(close)

	_show_tab(true)
	Inv.changed.connect(refresh)

func _header() -> Control:
	var row := HBoxContainer.new()
	row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	var t := Label.new()
	t.text = "الحقيبة"
	t.layout_direction = Control.LAYOUT_DIRECTION_RTL
	t.add_theme_font_size_override("font_size", 44)
	t.add_theme_color_override("font_color", Color(0.894, 0.075, 0.137))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	return row

func _tabs() -> Control:
	var row := HBoxContainer.new()
	row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	row.add_theme_constant_override("separation", 12)
	_tab_items = Button.new()
	_tab_items.text = "الأغراض"
	_tab_items.custom_minimum_size = Vector2(190, 50)
	_tab_items.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_tab_items.pressed.connect(func() -> void: _show_tab(true))
	row.add_child(_tab_items)
	_tab_notes = Button.new()
	_tab_notes.text = "المذكرات"
	_tab_notes.custom_minimum_size = Vector2(190, 50)
	_tab_notes.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_tab_notes.pressed.connect(func() -> void: _show_tab(false))
	row.add_child(_tab_notes)
	return row

func _build_items_page() -> Control:
	var page := HBoxContainer.new()
	page.layout_direction = Control.LAYOUT_DIRECTION_RTL
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 22)

	var left := PanelContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.6
	left.add_theme_stylebox_override("panel", _box())
	page.add_child(left)

	var scroll := ScrollContainer.new()
	scroll.layout_direction = Control.LAYOUT_DIRECTION_LTR
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)

	var holder := Control.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(holder)

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	holder.add_child(_grid)

	_empty = Label.new()
	_empty.text = "لا شيء بعد."
	_empty.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.add_theme_font_size_override("font_size", 24)
	_empty.add_theme_color_override("font_color", Color(0.42, 0.4, 0.37))
	_empty.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_empty.offset_top = 40
	_empty.offset_left = -200
	_empty.offset_right = 200
	holder.add_child(_empty)

	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_stylebox_override("panel", _box())
	page.add_child(right)

	var dcol := VBoxContainer.new()
	dcol.layout_direction = Control.LAYOUT_DIRECTION_LTR
	dcol.add_theme_constant_override("separation", 14)
	right.add_child(dcol)

	_detail_name = Label.new()
	_detail_name.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_detail_name.add_theme_font_size_override("font_size", 30)
	_detail_name.add_theme_color_override("font_color", Color(0.914, 0.894, 0.863))
	dcol.add_child(_detail_name)

	_detail = Label.new()
	_detail.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_theme_font_size_override("font_size", 22)
	_detail.add_theme_color_override("font_color", Color(0.639, 0.616, 0.58))
	dcol.add_child(_detail)
	return page

func _build_notes_page() -> Control:
	var page := PanelContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_stylebox_override("panel", _box())
	var scroll := ScrollContainer.new()
	scroll.layout_direction = Control.LAYOUT_DIRECTION_LTR
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	_notes_col = VBoxContainer.new()
	_notes_col.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_notes_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notes_col.add_theme_constant_override("separation", 10)
	scroll.add_child(_notes_col)
	return page

func _box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.059, 0.078, 0.95)
	sb.border_color = Color(0.165, 0.176, 0.212, 1.0)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(18)
	return sb

func _slot(id: String) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(118, 118)
	b.layout_direction = Control.LAYOUT_DIRECTION_RTL
	b.text = ItemDB.glyph(id)
	b.tooltip_text = ItemDB.display_name(id)
	b.add_theme_font_size_override("font_size", 40)
	b.pressed.connect(func() -> void: _select(id))
	return b

func _select(id: String) -> void:
	_selected = id
	var d := ItemDB.get_item(id)
	_detail_name.text = str(d.get("name", id))
	_detail.text = str(d.get("desc", ""))

func _show_tab(items: bool) -> void:
	_items_page.visible = items
	_notes_page.visible = not items
	_tab_items.disabled = items
	_tab_notes.disabled = not items

func refresh() -> void:
	if _grid == null:
		return
	for c in _grid.get_children():
		c.queue_free()
	for id in Inv.items:
		_grid.add_child(_slot(id))
	_empty.visible = Inv.items.is_empty()
	if Inv.items.has(_selected):
		_select(_selected)
	elif not Inv.items.is_empty():
		_select(Inv.items[0])
	else:
		_detail_name.text = ""
		_detail.text = ""

	for c in _notes_col.get_children():
		c.queue_free()
	if Inv.notes.is_empty():
		var l := Label.new()
		l.text = "لم تجد أي أوراق بعد."
		l.layout_direction = Control.LAYOUT_DIRECTION_RTL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 24)
		l.add_theme_color_override("font_color", Color(0.42, 0.4, 0.37))
		_notes_col.add_child(l)
	else:
		for id in Inv.notes:
			var b := Button.new()
			b.text = "✉   " + ItemDB.display_name(id)
			b.custom_minimum_size = Vector2(0, 62)
			b.layout_direction = Control.LAYOUT_DIRECTION_RTL
			b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
			var nid := id
			b.pressed.connect(func() -> void: note_opened.emit(nid))
			_notes_col.add_child(b)

func open_panel() -> void:
	refresh()
	visible = true
	get_tree().paused = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.2)

func close_panel() -> void:
	if not visible:
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func() -> void:
		visible = false
		get_tree().paused = false
		closed.emit())
