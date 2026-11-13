class_name Player
extends CharacterBody3D
## تحكم الشخصية بمنظور الشخص الثالث.
## لا يعرف شيئاً عن اللمس: يستقبل اتجاهاً مطبّعاً من الواجهة فقط.

signal stamina_changed(ratio: float)
signal interacted()

@export var walk_speed: float = 3.4
@export var run_speed: float = 6.6
@export var acceleration: float = 12.0
@export var deceleration: float = 16.0
@export var jump_velocity: float = 5.0
@export var turn_speed: float = 11.0
@export var max_stamina: float = 100.0
@export var stamina_drain: float = 22.0
@export var stamina_regen: float = 16.0

var move_dir: Vector2 = Vector2.ZERO
var want_run: bool = false
var camera_basis_yaw: float = 0.0
var stamina: float = 100.0

var _gravity: float = 9.8
var _was_on_floor: bool = true

func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	stamina = max_stamina

func set_move_input(dir: Vector2) -> void:
	move_dir = dir if dir.length() <= 1.0 else dir.normalized()

func set_run(active: bool) -> void:
	want_run = active

func try_jump() -> void:
	if is_on_floor():
		velocity.y = jump_velocity

func interact() -> void:
	interacted.emit()

func is_running() -> bool:
	return want_run and stamina > 1.0 and move_dir.length() > 0.5

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	_update_stamina(delta)

	# تحويل اتجاه الإدخال إلى فضاء الكاميرا
	var input3 := Vector3(move_dir.x, 0.0, move_dir.y)
	var dir := input3.rotated(Vector3.UP, camera_basis_yaw)
	var speed := run_speed if is_running() else walk_speed
	var target := dir * speed

	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	var rate := acceleration if dir.length() > 0.01 else deceleration
	horiz = horiz.move_toward(Vector3(target.x, 0.0, target.z), rate * delta)
	velocity.x = horiz.x
	velocity.z = horiz.z

	# استدارة الجسم نحو اتجاه الحركة
	if dir.length() > 0.05:
		var want := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, want, clampf(turn_speed * delta, 0.0, 1.0))

	move_and_slide()
	_was_on_floor = is_on_floor()

func _update_stamina(delta: float) -> void:
	var before := stamina
	if is_running():
		stamina = maxf(0.0, stamina - stamina_drain * delta)
	else:
		stamina = minf(max_stamina, stamina + stamina_regen * delta)
	if not is_equal_approx(before, stamina):
		stamina_changed.emit(stamina / max_stamina)
