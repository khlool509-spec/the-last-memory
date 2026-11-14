class_name NoteReader
extends Control
## واجهة قراءة الأوراق. تُوقف اللعب وتعرض النص على خلفية ورقية داكنة.

signal closed()

var _item_id := ""
var _body: Label
var _title: Label
var _card: PanelContainer

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	modulate.a = 0.0

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_card = PanelContainer.new()
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_card.custom_minimum_size = Vector2(880, 520)
	_card.offset_left = -440
	_card.offset_right = 440
	_card.offset_top = -260
	_card.offset_bottom = 260
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.082, 0.075, 0.063, 0.985)
	sb.border_color = Color(0.427, 0.408, 0.361, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 48
	sb.content_margin_right = 48
	sb.content_margin_top = 40
	sb.content_margin_bottom = 34
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 24
	_card.add_theme_stylebox_override("panel", sb)
	add_child(_card)

	var col := VBoxContainer.new()
	col.layout_direction = Control.LAYOUT_DIRECTION_LTR
	col.add_theme_constant_override("separation", 20)
	_card.add_child(col)

	_title = Label.new()
	_title.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", Color(0.894, 0.075, 0.137))
	col.add_child(_title)

	var rule := ColorRect.new()
	rule.color = Color(0.427, 0.408, 0.361, 0.5)
	rule.custom_minimum_size = Vector2(0, 1)
	col.add_child(rule)

	var scroll := ScrollContainer.new()
	scroll.layout_direction = Control.LAYOUT_DIRECTION_LTR
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	_body = Label.new()
	_body.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_size_override("font_size", 26)
	_body.add_theme_color_override("font_color", Color(0.839, 0.816, 0.78))
	_body.add_theme_constant_override("line_spacing", 12)
	scroll.add_child(_body)

	var close := Button.new()
	close.text = "أغلق"
	close.custom_minimum_size = Vector2(0, 56)
	close.layout_direction = Control.LAYOUT_DIRECTION_RTL
	close.pressed.connect(close_reader)
	col.add_child(close)

func open(item_id: String) -> void:
	_item_id = item_id
	var d := ItemDB.get_item(item_id)
	_title.text = str(d.get("name", "ورقة"))
	var body := str(d.get("body", ""))
	if body.strip_edges() == "":
		body = str(d.get("desc", ""))
	_body.text = body
	visible = true
	get_tree().paused = true
	_card.scale = Vector2(0.94, 0.94)
	_card.pivot_offset = _card.size * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.22)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func close_reader() -> void:
	if not visible:
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func() -> void:
		visible = false
		get_tree().paused = false
		closed.emit())

func _unhandled_input(e: InputEvent) -> void:
	if not visible:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		var k := e as InputEventKey
		if k.keycode == KEY_ESCAPE or k.keycode == KEY_ENTER or k.keycode == KEY_SPACE:
			close_reader()
			get_viewport().set_input_as_handled()
