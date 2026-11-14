class_name Player
extends CharacterBody3D
## تحكم الشخصية بمنظور الشخص الثالث.
## لا يعرف شيئاً عن اللمس: يستقبل اتجاهاً مطبّعاً من الواجهة فقط.
## الجاذبية والتحكم الجوي قابلان للضبط، فنفس الشخصية تعمل على الأرض
## وعلى القمر بلا تفريع في الكود.

signal stamina_changed(ratio: float)
signal interacted()
signal landed(impact_speed: float)
signal jumped()

@export var walk_speed: float = 3.4
@export var run_speed: float = 6.6
@export var acceleration: float = 12.0
@export var deceleration: float = 16.0
@export var jump_velocity: float = 5.0
@export var turn_speed: float = 11.0
@export var max_stamina: float = 100.0
@export var stamina_drain: float = 22.0
@export var stamina_regen: float = 16.0

## قوة الجاذبية بالمتر/ث². سالب = استعمل قيمة إعدادات المشروع.
@export var gravity_override: float = -1.0
## نسبة التحكم بالاتجاه أثناء الطيران (0 = لا تحكم، 1 = كما على الأرض)
@export var air_control: float = 1.0
## سرعة السقوط القصوى
@export var terminal_velocity: float = 55.0

var move_dir: Vector2 = Vector2.ZERO
var want_run: bool = false
var camera_basis_yaw: float = 0.0
var stamina: float = 100.0

var _gravity: float = 9.8
var _was_on_floor: bool = true
var _fall_speed: float = 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	_refresh_gravity()
	stamina = max_stamina

func _refresh_gravity() -> void:
	if gravity_override > 0.0:
		_gravity = gravity_override
	else:
		_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))

func set_gravity(g: float) -> void:
	gravity_override = g
	_refresh_gravity()

func get_gravity_value() -> float:
	return _gravity

func set_move_input(dir: Vector2) -> void:
	move_dir = dir if dir.length() <= 1.0 else dir.normalized()

func set_run(active: bool) -> void:
	want_run = active

func try_jump() -> bool:
	if is_on_floor():
		velocity.y = jump_velocity
		jumped.emit()
		return true
	return false

func interact() -> void:
	interacted.emit()

func is_running() -> bool:
	return want_run and stamina > 1.0 and move_dir.length() > 0.5

func is_moving() -> bool:
	return move_dir.length() > 0.05

## زمن بقاء القفزة في الهواء بالثواني — يُستعمل في الاختبارات والضبط
func hang_time() -> float:
	return 2.0 * jump_velocity / maxf(0.01, _gravity)

## أقصى ارتفاع تبلغه القفزة بالأمتار
func jump_apex() -> float:
	return (jump_velocity * jump_velocity) / (2.0 * maxf(0.01, _gravity))

func _physics_process(delta: float) -> void:
	var grounded := is_on_floor()

	if not grounded:
		velocity.y = maxf(velocity.y - _gravity * delta, -terminal_velocity)
		_fall_speed = minf(_fall_speed, velocity.y)
	elif velocity.y < 0.0:
		velocity.y = 0.0

	# لحظة الهبوط: تُبثّ بسرعة الارتطام فتستعملها المؤثرات والصوت
	if grounded and not _was_on_floor:
		landed.emit(absf(_fall_speed))
		_fall_speed = 0.0

	_update_stamina(delta)

	# تحويل اتجاه الإدخال إلى فضاء الكاميرا
	var input3 := Vector3(move_dir.x, 0.0, move_dir.y)
	var dir := input3.rotated(Vector3.UP, camera_basis_yaw)
	var speed := run_speed if is_running() else walk_speed
	var target := dir * speed

	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	var rate := acceleration if dir.length() > 0.01 else deceleration
	if not grounded:
		# في الفراغ لا احتكاك: التحكم الجوي محدود بقدر ما يضبطه المستوى
		rate *= clampf(air_control, 0.0, 1.0)
	horiz = horiz.move_toward(Vector3(target.x, 0.0, target.z), rate * delta)
	velocity.x = horiz.x
	velocity.z = horiz.z

	# استدارة الجسم نحو اتجاه الحركة
	if dir.length() > 0.05:
		var want := atan2(-dir.x, -dir.z)
		var turn := turn_speed if grounded else turn_speed * maxf(0.25, air_control)
		rotation.y = lerp_angle(rotation.y, want, clampf(turn * delta, 0.0, 1.0))

	move_and_slide()
	_was_on_floor = grounded

func _update_stamina(delta: float) -> void:
	var before := stamina
	if is_running():
		stamina = maxf(0.0, stamina - stamina_drain * delta)
	else:
		stamina = minf(max_stamina, stamina + stamina_regen * delta)
	if not is_equal_approx(before, stamina):
		stamina_changed.emit(stamina / max_stamina)
