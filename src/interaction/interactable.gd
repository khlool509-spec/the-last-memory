class_name Interactable
extends Area3D
## أي جسم يمكن للاعب استعماله. يسجّل نفسه تلقائياً في مجموعة
## `interactables` فيجده كاشف اللاعب بلا ربط يدوي.

signal used(interact_id: String, node: Interactable)

@export var interact_id: String = ""
@export var prompt: String = "تفاعل"
@export var once: bool = true
@export var reach: float = 2.8

var consumed: bool = false

func _ready() -> void:
	add_to_group("interactables")
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	monitorable = true
	if get_child_count() == 0 or _needs_shape():
		var shape := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = reach
		shape.shape = sph
		add_child(shape)

func _needs_shape() -> bool:
	for c in get_children():
		if c is CollisionShape3D:
			return false
	return true

func can_use() -> bool:
	return not (once and consumed)

func use() -> bool:
	if not can_use():
		return false
	if once:
		consumed = true
	used.emit(interact_id, self)
	return true

func distance_to_point(p: Vector3) -> float:
	return global_position.distance_to(p)
