class_name TriggerZone
extends Area3D
## منطقة تُطلق حدثاً حين يدخلها اللاعب. تُستخدم لتقدّم الأهداف والمشاهد.

signal entered(by: Node3D)

@export var once: bool = true
@export var save_flag: String = ""

var _fired := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	if save_flag != "" and SaveSystem.data.get("flags", {}).get(save_flag, false):
		_fired = true
	body_entered.connect(_on_body)

func setup_box(size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	add_child(cs)

func setup_sphere(radius: float) -> void:
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = radius
	cs.shape = s
	add_child(cs)

func _on_body(b: Node3D) -> void:
	if once and _fired:
		return
	if not (b is Player):
		return
	_fired = true
	if save_flag != "":
		var flags: Dictionary = SaveSystem.data.get("flags", {})
		flags[save_flag] = true
		SaveSystem.data["flags"] = flags
		SaveSystem.save_game()
	entered.emit(b)
