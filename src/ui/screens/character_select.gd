class_name CharacterSelect
extends Control
## اختيار الشخصية قبل بدء اللعب — ذكر أو أنثى.
##
## المعاينة ثلاثية الأبعاد حيّة: نفس الهيكل الذي يُستخدم في اللعب
## يدور أمام الكاميرا. لا صورة مسبقة، فما تراه هنا هو ما ستلعب به
## بالضبط — ولو عدّلتُ النسب لاحقاً لانعكس هنا بلا عمل إضافي.

signal chosen(gender: String)
signal cancelled()

const GENDERS := ["male", "female"]
const LABELS := {"male": "رجل", "female": "امرأة"}
const DESC := {
	"male": "بنية أعرض وخطوة أثقل",
	"female": "أخفّ حركة وقامة أقصر",
}

var _index := 0
var _vp: SubViewport
var _rig: CharacterRig
var _pivot: Node3D
var _title: Label
var _sub: Label

func _ready() -> void:
	name = "CharacterSelect"
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.build()
	process_mode = Node.PROCESS_MODE_ALWAYS

	var bg := ColorRect.new()
	bg.color = Color(0.035, 0.038, 0.047, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_build_preview()

	var col := VBoxContainer.new()
	col.layout_direction = Control.LAYOUT_DIRECTION_RTL
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	col.anchor_left = 0.5
	col.anchor_right = 0.5
	col.offset_left = -300
	col.offset_right = 300
	col.offset_top = 26
	col.add_theme_constant_override("separation", 6)
	add_child(col)

	_title = Label.new()
	_title.text = "اختر شخصيتك"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 34)
	col.add_child(_title)

	_sub = Label.new()
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_font_size_override("font_size", 17)
	_sub.add_theme_color_override("font_color", Palette.DUST)
	col.add_child(_sub)

	_build_controls()
	_apply()

func _build_preview() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(560, 760)
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# شاشة اختيار واحدة لا عالم: تصيير معاينة صغيرة هنا مقبول،
	# وهي تُحرَّر فور الدخول إلى اللعب.
	add_child(_vp)

	var world := Node3D.new()
	_vp.add_child(world)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.08, 2.35)
	cam.rotation_degrees = Vector3(-4, 0, 0)
	cam.fov = 38.0
	world.add_child(cam)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-34, 36, 0)
	key.light_energy = 1.5
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-14, -128, 0)
	fill.light_energy = 0.55
	fill.light_color = Color(0.72, 0.80, 0.96)
	world.add_child(fill)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.035, 0.038, 0.047)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.46, 0.50, 0.58)
	e.ambient_light_energy = 1.1
	env.environment = e
	world.add_child(env)

	_pivot = Node3D.new()
	world.add_child(_pivot)

	var holder := TextureRect.new()
	holder.texture = _vp.get_texture()
	holder.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	holder.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.offset_top = 96
	holder.offset_bottom = -150
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)

func _build_controls() -> void:
	var row := HBoxContainer.new()
	row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_top = -124
	row.offset_bottom = -58
	row.add_theme_constant_override("separation", 18)
	add_child(row)

	for g: String in GENDERS:
		var b := Button.new()
		b.text = str(LABELS[g])
		b.custom_minimum_size = Vector2(190, 58)
		b.add_theme_font_size_override("font_size", 23)
		var gg: String = g
		b.pressed.connect(func() -> void: _pick(gg))
		row.add_child(b)

	var go := Button.new()
	go.text = "ابدأ"
	go.custom_minimum_size = Vector2(230, 58)
	go.add_theme_font_size_override("font_size", 25)
	go.pressed.connect(_confirm)
	row.add_child(go)

	var back := Button.new()
	back.text = "رجوع"
	back.custom_minimum_size = Vector2(150, 58)
	back.pressed.connect(func() -> void: cancelled.emit())
	row.add_child(back)

func _pick(g: String) -> void:
	_index = GENDERS.find(g)
	_apply()

func _apply() -> void:
	var g: String = GENDERS[_index]
	_sub.text = "%s — %s" % [str(LABELS[g]), str(DESC[g])]
	if _rig:
		_rig.queue_free()
	_rig = CharacterRig.create(g)
	_pivot.add_child(_rig)

func _process(delta: float) -> void:
	if _pivot:
		_pivot.rotate_y(delta * 0.55)
	if _rig:
		# وقفة ساكنة حيّة: تنفّس خفيف بدل تمثال جامد
		_rig.pose("مشي", 0.0, delta, false)

func _confirm() -> void:
	var g: String = GENDERS[_index]
	Settings.set_value("character_gender", g)
	chosen.emit(g)
