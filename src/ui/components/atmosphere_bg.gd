class_name AtmosphereBG
extends Control
## خلفية الشاشات.
##
## تفضّل صورة فنية جاهزة إن وُجدت في assets/textures/ui، وإلا ترسم
## مشهداً ليلياً إجرائياً بالشيدر. هذا يجعل استبدال الخلفية بعمل فني
## مسألة إسقاط ملف واحد، بلا أي تعديل في الكود.

const IMAGE_CANDIDATES := [
	"res://assets/textures/ui/menu_bg.png",
	"res://assets/textures/ui/menu_bg.jpg",
	"res://assets/textures/ui/menu_bg.webp",
]

@export var moon_pos := Vector2(0.30, 0.24)
@export var fog_amount := 0.55
@export var rain_amount := 0.40
@export var blood_glow := 0.18
## تعتيم فوق الصورة الفنية حتى يبقى النص مقروءاً
@export var image_darken := 0.42

var _shader_rect: ColorRect
var using_image: bool = false

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = -100

	var tex := _find_image()
	if tex != null:
		_build_image(tex)
	else:
		_build_shader()
	resized.connect(_update_aspect)
	_update_aspect()

func _find_image() -> Texture2D:
	for p in IMAGE_CANDIDATES:
		if ResourceLoader.exists(p):
			var t: Texture2D = ResourceLoader.load(p)
			if t != null:
				return t
	return null

func _build_image(tex: Texture2D) -> void:
	using_image = true
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.layout_direction = Control.LAYOUT_DIRECTION_LTR
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)

	# تعتيم متدرّج: الصورة تبقى ظاهرة والنص فوقها مقروء
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, image_darken)
	dim.layout_direction = Control.LAYOUT_DIRECTION_LTR
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

func _build_shader() -> void:
	using_image = false
	_shader_rect = ColorRect.new()
	_shader_rect.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_shader_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shader_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# لون احتياطي داكن: لو فشل الشيدر لا نرى رمادياً ولا أبيض
	_shader_rect.color = Palette.NIGHT
	add_child(_shader_rect)

	var sh: Shader = ResourceLoader.load("res://assets/shaders/atmosphere.gdshader")
	if sh == null:
		push_warning("شيدر الأجواء غير موجود — استُخدم لون داكن ثابت")
		return
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("moon_pos", moon_pos)
	mat.set_shader_parameter("fog_amount", fog_amount)
	mat.set_shader_parameter("rain_amount", rain_amount)
	mat.set_shader_parameter("blood_glow", blood_glow)
	_shader_rect.material = mat

func _update_aspect() -> void:
	if _shader_rect == null or _shader_rect.material == null:
		return
	var s := size
	if s.y > 1.0:
		(_shader_rect.material as ShaderMaterial).set_shader_parameter("aspect", s.x / s.y)
