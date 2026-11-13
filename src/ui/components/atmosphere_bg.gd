class_name AtmosphereBG
extends ColorRect
## خلفية الأجواء الإجرائية. تُضاف في أعلى كل شاشة.

@export var moon_pos := Vector2(0.27, 0.26)
@export var fog_amount := 0.45
@export var blood_glow := 0.22

func _ready() -> void:
	# المراسي تنعكس تحت RTL فتُنتج مساحة صفر. الهندسة دائماً LTR.
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = -100
	var sh: Shader = ResourceLoader.load("res://assets/shaders/atmosphere.gdshader")
	if sh == null:
		color = Palette.VOID
		return
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("moon_pos", moon_pos)
	mat.set_shader_parameter("fog_amount", fog_amount)
	mat.set_shader_parameter("blood_glow", blood_glow)
	material = mat
	# لون احتياطي داكن: الشيدر يستبدله كلياً، لكن إن فشل لا نرى رمادياً
	color = Palette.NIGHT
