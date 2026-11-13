extends Control
## شاشة المقتنيات — شبكة خانات، المجموع منها مضيء والباقي صامت.

const SLOTS := 12

func _ready() -> void:
	name = "CollectiblesMenu"
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.build()

	var bg := AtmosphereBG.new()
	bg.fog_amount = 0.35
	add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
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
	root.add_theme_constant_override("separation", 18)
	add_child(root)

	var collected: Array = SaveSystem.collected_ids()

	var h := Label.new()
	h.text = "المقتنيات   %d / %d" % [collected.size(), SLOTS]
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_size_override("font_size", UITheme.SIZE_HEADING + 6)
	h.add_theme_color_override("font_color", Palette.BLOOD_HOT)
	root.add_child(h)

	var wrap := CenterContainer.new()
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(wrap)

	var grid := GridContainer.new()
	grid.columns = 6
	grid.layout_direction = Control.LAYOUT_DIRECTION_RTL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	wrap.add_child(grid)

	for i in SLOTS:
		grid.add_child(_slot(i, collected.has(i)))

	var back := Button.new()
	back.text = "رجوع"
	back.custom_minimum_size = Vector2(220, 60)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): Router.go_to("res://src/ui/screens/main_menu.tscn"))
	root.add_child(back)

func _slot(index: int, owned: bool) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(132, 132)

	var frame := OrnateFrame.new()
	frame.line_color = Palette.BLOOD if owned else Palette.SMOKE
	frame.accent_color = Palette.EMBER if owned else Palette.with_alpha(Palette.SMOKE, 0.7)
	frame.corner_len = 18.0
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.add_child(frame)

	var c := CenterContainer.new()
	p.add_child(c)
	var l := Label.new()
	l.text = "؟" if not owned else "◆"
	l.add_theme_font_size_override("font_size", UITheme.SIZE_TITLE)
	l.add_theme_color_override("font_color", Palette.EMBER if owned else Palette.MUTED)
	c.add_child(l)
	return p
