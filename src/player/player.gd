class_name Player
extends CharacterBody3D
## تحكم الشخصية بمنظور الشخص الثالث.
## لا يعرف شيئاً عن اللمس: يستقبل اتجاهاً مطبّعاً من الواجهة فقط.

signal stamina_changed(ratio: float)
signal interacted()
signal stance_changed(stance: String)
signal swim_changed(in_water: bool)
signal fired()

@export var walk_speed: float = 3.4
@export var run_speed: float = 6.6
@export var acceleration: float = 12.0
@export var deceleration: float = 16.0
@export var jump_velocity: float = 5.0
@export var turn_speed: float = 11.0
@export var crouch_speed: float = 1.9
@export var prone_speed: float = 0.9
@export var aim_speed_mult: float = 0.46
## السباحة: ببجي يسبح أبطأ من المشي ويغوص أبطأ من السباحة
@export var swim_speed: float = 2.3
@export var dive_speed: float = 1.7
@export var swim_vert_speed: float = 1.4
@export var max_stamina: float = 100.0
@export var stamina_drain: float = 22.0
@export var stamina_regen: float = 16.0

var move_dir: Vector2 = Vector2.ZERO
var want_run: bool = false
## الركض التلقائي: مفتاح لا ضغطة. يدفع الشخصية للأمام بلا إبهام على
## العصا، ويُلغى بأي إدخال حركة معاكس أو بلمس الزر ثانية — كما في ببجي.
var auto_run: bool = false
## الوضع: standing / crouch / prone. يغيّر السرعة وارتفاع المصادم.
var stance: String = "standing"
var is_aiming: bool = false
var is_firing: bool = false
## السباحة: ‎+1 صعود، ‎-1 غوص، 0 طفو
var swim_vert: int = 0
var in_water: bool = false
var submerged: bool = false
var camera_basis_yaw: float = 0.0
var stamina: float = 100.0

var _gravity: float = 9.8
var _was_on_floor: bool = true
var rig: CharacterRig = null          # الشخصية المفصليّة، تُركَّب من المرحلة
var model: CharacterModel = null      # مجسّم مرخّص مجهّز، إن وُجد
var _fire_cd := 0.0
var _step_accum: float = 0.0
## السطح الذي يقف عليه: تحدّثه المرحلة، ويغيّر صوت الخطوة
var surface: String = "grass"
## المسافة بين خطوتين بالأمتار — ثابتة بالمسافة لا بالزمن،
## فلا تتسارع النقرات حين يتسارع اللاعب.
const STEP_WALK := 1.9
const STEP_RUN := 2.6

func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	stamina = max_stamina

func set_move_input(dir: Vector2) -> void:
	move_dir = dir if dir.length() <= 1.0 else dir.normalized()

func set_run(active: bool) -> void:
	want_run = active
	if active:
		auto_run = false          # الضغط اليدوي يلغي التلقائي

func set_auto_run(active: bool) -> void:
	auto_run = active

func set_aim(active: bool) -> void:
	is_aiming = active

func set_fire(active: bool) -> void:
	is_firing = active

func set_swim_vertical(dir: int) -> void:
	swim_vert = clampi(dir, -1, 1)

## دورة الأوضاع: وقوف ← قرفصاء ← وقوف. الانبطاح زرّ مستقل.
func toggle_crouch() -> void:
	_set_stance("standing" if stance == "crouch" else "crouch")

func toggle_prone() -> void:
	_set_stance("standing" if stance == "prone" else "prone")

func _set_stance(v: String) -> void:
	if stance == v:
		return
	stance = v
	# ارتفاع المصادم يتبع الوضع فعلاً: الانبطاح يُمرّر تحت الحواجز
	var col := get_node_or_null("Collider") as CollisionShape3D
	if col and col.shape is CapsuleShape3D:
		var cap := col.shape as CapsuleShape3D
		cap.height = {"standing": 1.80, "crouch": 1.18, "prone": 0.62}.get(v, 1.80)
		col.position.y = cap.height * 0.5
	stance_changed.emit(v)

## سرعة الحركة الحالية بعد كل المعدِّلات
func current_speed() -> float:
	if in_water:
		return dive_speed if submerged else swim_speed
	var sp := walk_speed
	match stance:
		"crouch": sp = crouch_speed
		"prone": sp = prone_speed
		_:
			if is_running():
				sp = run_speed
	if is_aiming:
		sp *= aim_speed_mult
	return sp

func try_jump() -> void:
	if is_on_floor():
		velocity.y = jump_velocity

func interact() -> void:
	interacted.emit()

func is_running() -> bool:
	if stance != "standing" or in_water:
		return false
	var moving := move_dir.length() > 0.5 or auto_run
	return (want_run or auto_run) and stamina > 1.0 and moving

## حالة قصيرة للواجهة وشريط الإحداثيات
func state_label() -> String:
	if submerged:
		return "غوص"
	if in_water:
		return "سباحة"
	match stance:
		"crouch": return "قرفصاء"
		"prone": return "انبطاح"
	if is_running():
		return "ركض"
	return "مشي"

func _physics_process(delta: float) -> void:
	_update_water(delta)

	if in_water:
		# طفو: الجسم يرتفع إلى السطح من تلقائه ما لم يغُص اللاعب.
		# هذا ما يجعل السباحة تُحسّ كسباحة لا كمشي تحت الماء.
		var want_y := 0.0
		if swim_vert > 0:
			want_y = swim_vert_speed
		elif swim_vert < 0:
			want_y = -swim_vert_speed
		else:
			# قوّة الطفو تتناسب مع عمق الغطس: كلّما غاص أكثر دُفع أقوى
			var depth := _water_y - global_position.y
			want_y = clampf(depth * 1.9, -0.4, 1.6)
		velocity.y = move_toward(velocity.y, want_y, 7.0 * delta)
	elif not is_on_floor():
		velocity.y -= _gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	_update_stamina(delta)

	# الركض التلقائي يدفع للأمام حين لا يلمس اللاعب العصا
	var eff := move_dir
	if auto_run and eff.length() < 0.15:
		eff = Vector2(0.0, -1.0)
	elif auto_run and eff.y > 0.35:
		auto_run = false            # سحب العصا للخلف يلغيه، كما في ببجي

	# تحويل اتجاه الإدخال إلى فضاء الكاميرا
	var input3 := Vector3(eff.x, 0.0, eff.y)
	var dir := input3.rotated(Vector3.UP, camera_basis_yaw)
	var speed := current_speed()
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

	# تحريك الشخصية: الحالة والسرعة تقودان الوضع، فلا جداول تحريك
	var hspd := Vector2(velocity.x, velocity.z).length()
	if model:
		model.play_state(state_label(), hspd, is_aiming)
	elif rig:
		rig.pose(state_label(), hspd, delta, is_aiming)
	if is_firing:
		_fire_cd -= delta
		if _fire_cd <= 0.0:
			_fire_cd = 0.11            # ‎≈545 طلقة/دقيقة
			if model:
				model.fire_once()
			elif rig:
				rig.recoil()
			fired.emit()
	else:
		_fire_cd = 0.0

	move_and_slide()
	if not in_water:
		_update_footsteps(delta)

	# هبوط بعد قفزة: نقرة أقوى
	if is_on_floor() and not _was_on_floor:
		Audio.play_surface_step(surface, true)
	_was_on_floor = is_on_floor()


## ══════════ الماء ══════════
## منسوب الماء ثابت في هذا الفصل، فلا حاجة لاستعلام فيزيائي كل إطار.
## الدخول والخروج يرسلان إشارة تُظهر أزرار السباحة وتخفيها.
var _water_y: float = -2.6
var _swim_enter_depth := 0.95      # يبدأ السباحة حين يغمره للصدر
var _submerge_depth := 1.55        # الغوص حين يغطّي الرأس

func set_water_level(y: float) -> void:
	_water_y = y

func _update_water(_delta: float) -> void:
	var depth := _water_y - global_position.y
	var now_in := depth > _swim_enter_depth
	var now_sub := depth > _submerge_depth
	if now_in != in_water:
		in_water = now_in
		if in_water:
			_set_stance("standing")   # لا انبطاح في الماء
			auto_run = false
		else:
			swim_vert = 0
		swim_changed.emit(in_water)
	submerged = now_sub and in_water

func _update_footsteps(_delta: float) -> void:
	if not is_on_floor():
		_step_accum = 0.0
		return
	var moved := Vector2(velocity.x, velocity.z).length() * _delta
	if moved < 0.001:
		_step_accum = maxf(0.0, _step_accum - 0.6 * _delta)
		return
	_step_accum += moved
	var stride := STEP_RUN if is_running() else STEP_WALK
	if _step_accum >= stride:
		_step_accum = 0.0
		Audio.play_surface_step(surface, is_running())

func _update_stamina(delta: float) -> void:
	var before := stamina
	if is_running():
		stamina = maxf(0.0, stamina - stamina_drain * delta)
	else:
		stamina = minf(max_stamina, stamina + stamina_regen * delta)
	if not is_equal_approx(before, stamina):
		stamina_changed.emit(stamina / max_stamina)
