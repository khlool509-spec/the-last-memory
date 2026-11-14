class_name ObjectiveMarker
extends Node3D
## منارة هدف: عمود ضوئي ينبض وحلقة تدور على الأرض، ومنطقة تكشف الوصول.
## مرسومة بالكود: بلا أصول، وتعمل على Mobile renderer (لا ضباب حجمي).

signal reached(marker_id: String)

@export var marker_id: String = ""
@export var radius: float = 4.5
@export var beam_height: float = 26.0
@export var color: Color = Color("#7d93ad")

var _beam: MeshInstance3D
var _ring: MeshInstance3D
var _area: Area3D
var _t: float = 0.0
var _armed: bool = true

func _ready() -> void:
	_build_beam()
	_build_ring()
	_build_area()

func _build_beam() -> void:
	_beam = MeshInstance3D.new()
	_beam.name = "Beam"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.26
	cyl.bottom_radius = 0.55
	cyl.height = beam_height
	cyl.radial_segments = 10
	cyl.rings = 1
	_beam.mesh = cyl
	_beam.position = Vector3(0, beam_height * 0.5, 0)
	_beam.material_override = _glow_material(0.22)
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)

func _build_ring() -> void:
	_ring = MeshInstance3D.new()
	_ring.name = "Ring"
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.35
	torus.outer_radius = radius
	torus.rings = 24
	torus.ring_segments = 6
	_ring.mesh = torus
	_ring.position = Vector3(0, 0.28, 0)
	_ring.material_override = _glow_material(0.72)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)

func _build_area() -> void:
	_area = Area3D.new()
	_area.name = "ReachArea"
	_area.collision_layer = 0
	_area.collision_mask = 2  # طبقة اللاعب
	_area.monitoring = true
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = 8.0
	shape.shape = cyl
	shape.position = Vector3(0, 3.0, 0)
	_area.add_child(shape)
	_area.body_entered.connect(_on_body_entered)
	add_child(_area)

func _on_body_entered(body: Node3D) -> void:
	if not _armed:
		return
	if body is Player:
		_armed = false
		reached.emit(marker_id)

func rearm() -> void:
	_armed = true

func set_color(c: Color) -> void:
	color = c
	if _beam:
		_beam.material_override = _glow_material(0.22)
	if _ring:
		_ring.material_override = _glow_material(0.72)

func _glow_material(alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.disable_receive_shadows = true
	return m

func _process(delta: float) -> void:
	_t += delta
	if _ring:
		_ring.rotation.y += delta * 0.9
		var s := 1.0 + sin(_t * 2.1) * 0.045
		_ring.scale = Vector3(s, 1.0, s)
	if _beam:
		var a := 0.16 + 0.10 * (0.5 + 0.5 * sin(_t * 1.7))
		var mat := _beam.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color = Color(color.r, color.g, color.b, a)

## الإخفاء لا يوقف Area3D تلقائياً: هذا يوقف الكشف والرسم معاً
func set_monitoring(on: bool) -> void:
	if _area:
		_area.monitoring = on
	set_process(on)
