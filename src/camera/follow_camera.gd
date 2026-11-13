class_name FollowCamera
extends Node3D
## كاميرا متابعة بذراع نابضة: تتجنّب اختراق الجدران، وتستقبل دوراناً
## من الواجهة مضروباً بحساسية المستخدم من الإعدادات.

@export var target_path: NodePath
@export var height: float = 1.55
@export var distance: float = 4.2
@export var min_pitch: float = -32.0
@export var max_pitch: float = 24.0
@export var follow_lag: float = 10.0
@export var base_sensitivity: float = 0.16

var yaw: float = 0.0
var pitch: float = -8.0

var _target: Node3D
var _arm: SpringArm3D
var _cam: Camera3D

func _ready() -> void:
	if target_path != NodePath(""):
		_target = get_node_or_null(target_path) as Node3D

	_arm = SpringArm3D.new()
	_arm.name = "Arm"
	_arm.spring_length = distance
	_arm.margin = 0.3
	_arm.collision_mask = 1
	add_child(_arm)

	_cam = Camera3D.new()
	_cam.name = "Cam"
	_cam.current = true
	_cam.fov = 70.0
	_arm.add_child(_cam)
	_apply_rotation()

func set_target(t: Node3D) -> void:
	_target = t

func get_camera() -> Camera3D:
	return _cam

func get_yaw_radians() -> float:
	return deg_to_rad(yaw)

func apply_look(delta_px: Vector2) -> void:
	var sens := base_sensitivity * (0.25 + 1.75 * float(Settings.get_value("camera_sensitivity")))
	var inv := -1.0 if bool(Settings.get_value("invert_y")) else 1.0
	yaw -= delta_px.x * sens
	pitch -= delta_px.y * sens * inv
	pitch = clampf(pitch, min_pitch, max_pitch)
	yaw = wrapf(yaw, -180.0, 180.0)
	_apply_rotation()

func _apply_rotation() -> void:
	rotation_degrees = Vector3(pitch, yaw, 0.0)

func _physics_process(delta: float) -> void:
	if _target == null:
		return
	var want := _target.global_position + Vector3.UP * height
	var t := clampf(follow_lag * delta, 0.0, 1.0)
	global_position = global_position.lerp(want, t)
