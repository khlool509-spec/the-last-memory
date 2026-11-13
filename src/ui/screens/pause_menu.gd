class_name PauseMenu
extends CanvasLayer
## قائمة الإيقاف — تُنشأ داخل مشهد اللعب ولا تُبدّل المشهد.

signal resumed()

var _root: Control
var _panel: PanelContainer

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_root.theme = UITheme.build()
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(_panel)

	var frame := OrnateFrame.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(frame)

	var col := VBoxContainer.new()
	col.layout_direction = Control.LAYOUT_DIRECTION_RTL
	col.add_theme_constant_override("separation", 12)
	_panel.add_child(col)

	var h := Label.new()
	h.text = "إيقاف مؤقت"
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_size_override("font_size", UITheme.SIZE_HEADING)
	h.add_theme_color_override("font_color", Palette.BLOOD_HOT)
	col.add_child(h)

	col.add_child(_mk("متابعة", resume))
	col.add_child(_mk("حفظ اللعبة", _on_save))
	col.add_child(_mk("الإعدادات", _open_settings))
	col.add_child(_mk("القائمة الرئيسية", _on_main_menu))

func _mk(txt: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(0, 62)
	b.pressed.connect(cb)
	return b

func open() -> void:
	visible = true
	get_tree().paused = true
	_panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_panel, "modulate:a", 1.0, 0.22)

func resume() -> void:
	get_tree().paused = false
	visible = false
	resumed.emit()

func toggle() -> void:
	if visible:
		resume()
	else:
		open()

func _open_settings() -> void:
	var ps: PackedScene = ResourceLoader.load("res://src/ui/screens/settings_menu.tscn")
	if ps == null:
		return
	var panel := ps.instantiate()
	panel.set("embedded", true)
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.add_child(panel)
	if panel.has_signal("closed"):
		panel.connect("closed", func(): _panel.visible = true)
	_panel.visible = false

func _on_save() -> void:
	if SaveSystem.save_game():
		_toast("تم الحفظ")
	else:
		_toast("تعذّر الحفظ")

func _toast(msg: String) -> void:
	var l := Label.new()
	l.text = msg
	l.add_theme_color_override("font_color", Palette.EMBER)
	l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	l.offset_top = -70
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 0.0, 1.2).set_delay(0.5)
	tw.tween_callback(l.queue_free)

func _on_main_menu() -> void:
	get_tree().paused = false
	Router.go_to("res://src/ui/screens/main_menu.tscn")
