class_name CharacterRig
extends Node3D
## شخصية بشرية مفصليّة — بديل الكبسولة.
##
## لماذا مفاصل لا هيكل بأوزان جلد: الجلد الموزون يحتاج مجسّماً ممسوحاً
## وأوزاناً مرسومة بيد فنّان، وليس عندي مصدر مرخّص لذلك. سلسلة مفاصل
## حقيقية بأطراف منفصلة تعطي حركة مفصليّة صحيحة — كتف ومرفق وركبة
## تدور كما تدور فعلاً — بكلفة رسم أقلّ، وهي الطريقة التي تحتمل
## استبدال المجسّمات لاحقاً بلا إعادة كتابة: المفاصل تبقى، والأشكال
## المعلّقة عليها هي ما يُستبدل.

const PROPORTIONS := {
	"male": {
		"height": 1.80, "shoulder": 0.205, "hip_w": 0.115,
		"torso": 0.54, "neck": 0.075, "head": 0.118,
		"upper_arm": 0.305, "forearm": 0.265, "arm_r": 0.052,
		"thigh": 0.445, "shin": 0.425, "leg_r": 0.072,
		"chest_w": 0.175, "chest_d": 0.105,
	},
	"female": {
		"height": 1.68, "shoulder": 0.172, "hip_w": 0.122,
		"torso": 0.505, "neck": 0.068, "head": 0.110,
		"upper_arm": 0.280, "forearm": 0.245, "arm_r": 0.044,
		"thigh": 0.420, "shin": 0.400, "leg_r": 0.066,
		"chest_w": 0.150, "chest_d": 0.096,
	},
}

## ألوان محايدة واقعية — لا نسخ من لعبة أخرى
const SKIN := Color(0.705, 0.545, 0.432)
const SHIRT_M := Color(0.228, 0.262, 0.238)
const SHIRT_F := Color(0.300, 0.272, 0.318)
const PANTS := Color(0.168, 0.176, 0.196)
const BOOT := Color(0.104, 0.098, 0.094)
const HAIR := Color(0.112, 0.090, 0.078)
const VEST := Color(0.196, 0.188, 0.162)

var gender: String = "male"
var P: Dictionary = {}

# المفاصل — تُدار من دالة الوضع
var hips: Node3D
var chest: Node3D
var neck: Node3D
var head: Node3D
var sh_l: Node3D
var sh_r: Node3D
var elb_l: Node3D
var elb_r: Node3D
var hip_l: Node3D
var hip_r: Node3D
var knee_l: Node3D
var knee_r: Node3D
var hand_r: Node3D
var weapon: Node3D

var _t := 0.0
var _lean := 0.0

static func create(g: String) -> CharacterRig:
	var r := CharacterRig.new()
	r.gender = g if PROPORTIONS.has(g) else "male"
	r.name = "CharacterRig"
	return r

func _ready() -> void:
	P = PROPORTIONS[gender]
	_build()

# ---------- البناء ----------
func _mat(c: Color, rough: float = 0.86) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = 0.0
	# مصيّر Mobile: نُبقي الخامات بسيطة فلا تضيف تمريرات
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return m

func _joint(parent: Node3D, nm: String, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = nm
	n.position = at
	parent.add_child(n)
	return n

## طرف مخروطي: أعرض عند المفصل وأضيق عند طرفه، فيبدو كعضلة لا كأنبوب
func _limb(parent: Node3D, nm: String, length: float, r_top: float,
		r_bot: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = length
	cm.radial_segments = 8
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = _mat(col)
	# المحور ينزل من المفصل: المركز عند نصف الطول تحته
	mi.position = Vector3(0, -length * 0.5, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

func _box(parent: Node3D, nm: String, sz: Vector3, at: Vector3,
		col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = _mat(col)
	mi.position = at
	parent.add_child(mi)
	return mi

func _build() -> void:
	var shirt: Color = SHIRT_F if gender == "female" else SHIRT_M
	var hip_y: float = float(P["thigh"]) + float(P["shin"]) + 0.09

	hips = _joint(self, "Hips", Vector3(0, hip_y, 0))
	# الحوض: أعرض في الأنثى، والفرق مقروء من الظهر كما في الواقع
	_box(hips, "Pelvis", Vector3(float(P["hip_w"]) * 2.0, 0.17,
		float(P["chest_d"]) * 1.7), Vector3(0, 0.02, 0), PANTS)

	chest = _joint(hips, "Chest", Vector3(0, 0.10, 0))
	_box(chest, "Torso", Vector3(float(P["chest_w"]) * 2.0,
		float(P["torso"]) * 0.78, float(P["chest_d"]) * 2.0),
		Vector3(0, float(P["torso"]) * 0.36, 0), shirt)
	# سترة تكتيكية: تكسر استواء الجذع وتعطي صمتاً بصرياً للكتفين
	_box(chest, "Vest", Vector3(float(P["chest_w"]) * 2.04,
		float(P["torso"]) * 0.42, float(P["chest_d"]) * 2.06),
		Vector3(0, float(P["torso"]) * 0.42, 0), VEST)

	neck = _joint(chest, "Neck", Vector3(0, float(P["torso"]) * 0.76, 0))
	_limb(neck, "NeckMesh", float(P["neck"]), 0.044, 0.050, SKIN)

	head = _joint(neck, "Head", Vector3(0, float(P["neck"]), 0))
	var hd := MeshInstance3D.new()
	hd.name = "Skull"
	var sm := SphereMesh.new()
	sm.radius = float(P["head"])
	sm.height = float(P["head"]) * 2.22
	sm.radial_segments = 12
	sm.rings = 8
	hd.mesh = sm
	hd.material_override = _mat(SKIN, 0.78)
	hd.position = Vector3(0, float(P["head"]) * 0.92, 0)
	head.add_child(hd)
	# شعر: قلنسوة للذكر، وذيل خلفي للأنثى — فارق يُقرأ من بعيد
	var cap := MeshInstance3D.new()
	var cs := SphereMesh.new()
	cs.radius = float(P["head"]) * 1.06
	cs.height = float(P["head"]) * 1.72
	cs.radial_segments = 12
	cs.rings = 7
	cap.mesh = cs
	cap.material_override = _mat(HAIR, 0.92)
	cap.position = Vector3(0, float(P["head"]) * 1.10, -0.006)
	head.add_child(cap)
	if gender == "female":
		var tail := MeshInstance3D.new()
		var tm := CapsuleMesh.new()
		tm.radius = 0.042
		tm.height = 0.26
		tm.radial_segments = 8
		tail.mesh = tm
		tail.material_override = _mat(HAIR, 0.92)
		tail.position = Vector3(0, float(P["head"]) * 0.80, -float(P["head"]) * 1.0)
		tail.rotation_degrees = Vector3(26, 0, 0)
		head.add_child(tail)

	# ذراعان
	var sy: float = float(P["torso"]) * 0.66
	sh_l = _joint(chest, "ShoulderL", Vector3(float(P["shoulder"]), sy, 0))
	elb_l = _joint(sh_l, "ElbowL", Vector3(0, -float(P["upper_arm"]), 0))
	_limb(sh_l, "UpperArmL", float(P["upper_arm"]), float(P["arm_r"]),
		float(P["arm_r"]) * 0.86, shirt)
	_limb(elb_l, "ForearmL", float(P["forearm"]), float(P["arm_r"]) * 0.84,
		float(P["arm_r"]) * 0.66, SKIN)

	sh_r = _joint(chest, "ShoulderR", Vector3(-float(P["shoulder"]), sy, 0))
	elb_r = _joint(sh_r, "ElbowR", Vector3(0, -float(P["upper_arm"]), 0))
	_limb(sh_r, "UpperArmR", float(P["upper_arm"]), float(P["arm_r"]),
		float(P["arm_r"]) * 0.86, shirt)
	_limb(elb_r, "ForearmR", float(P["forearm"]), float(P["arm_r"]) * 0.84,
		float(P["arm_r"]) * 0.66, SKIN)
	hand_r = _joint(elb_r, "HandR", Vector3(0, -float(P["forearm"]), 0))

	# ساقان
	hip_l = _joint(hips, "HipL", Vector3(float(P["hip_w"]) * 0.62, -0.02, 0))
	knee_l = _joint(hip_l, "KneeL", Vector3(0, -float(P["thigh"]), 0))
	_limb(hip_l, "ThighL", float(P["thigh"]), float(P["leg_r"]),
		float(P["leg_r"]) * 0.82, PANTS)
	_limb(knee_l, "ShinL", float(P["shin"]), float(P["leg_r"]) * 0.80,
		float(P["leg_r"]) * 0.60, PANTS)
	_box(knee_l, "BootL", Vector3(0.105, 0.085, 0.215),
		Vector3(0, -float(P["shin"]) - 0.035, 0.035), BOOT)

	hip_r = _joint(hips, "HipR", Vector3(-float(P["hip_w"]) * 0.62, -0.02, 0))
	knee_r = _joint(hip_r, "KneeR", Vector3(0, -float(P["thigh"]), 0))
	_limb(hip_r, "ThighR", float(P["thigh"]), float(P["leg_r"]),
		float(P["leg_r"]) * 0.82, PANTS)
	_limb(knee_r, "ShinR", float(P["shin"]), float(P["leg_r"]) * 0.80,
		float(P["leg_r"]) * 0.60, PANTS)
	_box(knee_r, "BootR", Vector3(0.105, 0.085, 0.215),
		Vector3(0, -float(P["shin"]) - 0.035, 0.035), BOOT)

	_build_weapon()

## بندقية مبسّطة: جسم وسبطانة ومخزن ومقبض. شكل أصلي لا نسخة
## عن سلاح حقيقي أو من لعبة أخرى.
func _build_weapon() -> void:
	weapon = Node3D.new()
	weapon.name = "Weapon"
	hand_r.add_child(weapon)
	_box(weapon, "Receiver", Vector3(0.052, 0.082, 0.34),
		Vector3(0, 0, 0.02), Color(0.138, 0.140, 0.146))
	_box(weapon, "Barrel", Vector3(0.028, 0.028, 0.30),
		Vector3(0, 0.012, 0.30), Color(0.100, 0.102, 0.108))
	_box(weapon, "Mag", Vector3(0.036, 0.135, 0.062),
		Vector3(0, -0.095, 0.01), Color(0.118, 0.120, 0.126))
	_box(weapon, "Stock", Vector3(0.044, 0.070, 0.20),
		Vector3(0, -0.012, -0.22), Color(0.156, 0.140, 0.118))
	weapon.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	weapon.position = Vector3(0.0, -0.06, 0.0)
	weapon.visible = false

# ---------- الوضع والتحريك ----------
## تُستدعى كل إطار من اللاعب. الحالة تختار الوضع، والسرعة تضبط إيقاع
## دورة المشي، فتتسارع الخطوة مع الجري بلا جداول تحريك.
func pose(state: String, speed: float, delta: float, aiming: bool) -> void:
	var cadence := 0.0
	match state:
		"ركض": cadence = 9.2
		"مشي": cadence = 5.4
		"قرفصاء": cadence = 4.2
		"سباحة", "غوص": cadence = 3.0
		_: cadence = 0.0
	_t += delta * (cadence if speed > 0.25 else 2.0)

	var sw := sin(_t)
	var sw2 := sin(_t * 2.0)
	var moving: float = clampf(speed / 3.0, 0.0, 1.0)

	match state:
		"سباحة", "غوص":
			_pose_swim(sw, state == "غوص")
			return
		"انبطاح":
			_pose_prone(sw, moving)
			return

	# ميل الجذع للأمام مع السرعة: الجسم يسبق القدمين حين يركض
	var want_lean: float = clampf(speed * 0.034, 0.0, 0.26)
	_lean = lerpf(_lean, want_lean, clampf(delta * 6.0, 0.0, 1.0))

	var crouch: bool = (state == "قرفصاء")
	hips.position.y = (float(P["thigh"]) + float(P["shin"]) + 0.09) \
		* (0.72 if crouch else 1.0) + sw2 * 0.012 * moving
	hips.rotation = Vector3(_lean * 0.4, 0.0, 0.0)
	chest.rotation = Vector3(_lean * 0.6, -sw * 0.10 * moving, 0.0)
	neck.rotation = Vector3(-_lean * 0.7, 0.0, 0.0)

	# الساقان: الفخذ يتأرجح والركبة تنثني في نصف الدورة الخلفي فقط
	var amp: float = 0.72 * moving
	hip_l.rotation = Vector3(sw * amp - (0.62 if crouch else 0.0), 0, 0)
	hip_r.rotation = Vector3(-sw * amp - (0.62 if crouch else 0.0), 0, 0)
	knee_l.rotation = Vector3(maxf(-sw, 0.0) * amp * 1.25
		+ (1.05 if crouch else 0.0), 0, 0)
	knee_r.rotation = Vector3(maxf(sw, 0.0) * amp * 1.25
		+ (1.05 if crouch else 0.0), 0, 0)

	if aiming:
		_pose_aim()
	else:
		# الذراعان تتأرجحان عكس الساقين — وهذا ما يجعل المشية تُقرأ
		# حمل منخفض: السلاح في اليد اليمنى مائلاً عبر الجسم، واليد
		# اليسرى على المقدّمة. الذراع اليمنى لا تتأرجح لأنها مشغولة،
		# واليسرى تتأرجح أقلّ — وهذا ما يفصل مشية المسلّح عن الأعزل.
		weapon.visible = true
		sh_r.rotation = Vector3(-0.92, 0.22, -0.20)
		elb_r.rotation = Vector3(-0.72, 0.0, 0.0)
		sh_l.rotation = Vector3(-0.98 - sw * amp * 0.18, -0.40, 0.28)
		elb_l.rotation = Vector3(-1.02, 0.0, 0.20)
		weapon.rotation = Vector3(PI * 0.5 - 0.34, 0.22, 0.0)
		weapon.position = Vector3(0.0, -0.07, 0.0)

## التصويب: السلاح مرفوع أمام الصدر واليد اليسرى تسنده
func _pose_aim() -> void:
	weapon.visible = true
	# الكتف يرفع الذراع أفقياً أمام الصدر، والمرفق ينثني قليلاً،
	# فتصير السبطانة موازية لخط النظر.
	sh_r.rotation = Vector3(-1.52, 0.26, -0.18)
	elb_r.rotation = Vector3(-0.34, 0.0, 0.0)
	sh_l.rotation = Vector3(-1.46, -0.46, 0.30)
	elb_l.rotation = Vector3(-0.72, 0.0, 0.26)
	weapon.rotation = Vector3(PI * 0.5 - 0.06, 0.0, 0.0)
	weapon.position = Vector3(0.0, -0.07, 0.02)

func _pose_swim(sw: float, diving: bool) -> void:
	weapon.visible = false
	# الجسم أفقي على السطح، وأميل للأسفل عند الغوص
	hips.rotation = Vector3(-1.32 if not diving else -1.08, 0.0, 0.0)
	hips.position.y = (float(P["thigh"]) + float(P["shin"]) + 0.09) * 0.52
	chest.rotation = Vector3(0.18, sw * 0.10, 0.0)
	neck.rotation = Vector3(0.62 if not diving else 0.20, 0.0, 0.0)
	# ذراعان تجدّفان بالتناوب
	sh_l.rotation = Vector3(-1.9 - sw * 0.9, 0.0, 0.42)
	sh_r.rotation = Vector3(-1.9 + sw * 0.9, 0.0, -0.42)
	elb_l.rotation = Vector3(-0.55, 0, 0)
	elb_r.rotation = Vector3(-0.55, 0, 0)
	# رفسات صغيرة متناوبة
	hip_l.rotation = Vector3(sw * 0.34, 0, 0)
	hip_r.rotation = Vector3(-sw * 0.34, 0, 0)
	knee_l.rotation = Vector3(maxf(-sw, 0.0) * 0.55, 0, 0)
	knee_r.rotation = Vector3(maxf(sw, 0.0) * 0.55, 0, 0)

func _pose_prone(sw: float, moving: float) -> void:
	weapon.visible = true
	hips.rotation = Vector3(-1.48, 0.0, 0.0)
	hips.position.y = 0.21
	chest.rotation = Vector3(0.26, 0.0, 0.0)
	neck.rotation = Vector3(0.80, 0.0, 0.0)
	sh_l.rotation = Vector3(-1.52, -0.42, 0.30)
	sh_r.rotation = Vector3(-1.46, 0.34, -0.24)
	elb_l.rotation = Vector3(-1.30, 0, 0)
	elb_r.rotation = Vector3(-1.08, 0, 0)
	hip_l.rotation = Vector3(0.10 + sw * 0.16 * moving, 0, 0.16)
	hip_r.rotation = Vector3(0.10 - sw * 0.16 * moving, 0, -0.16)
	knee_l.rotation = Vector3(0.30, 0, 0)
	knee_r.rotation = Vector3(0.30, 0, 0)

## ارتداد الإطلاق: دفعة قصيرة للخلف في الكتف تتلاشى من تلقائها
func recoil() -> void:
	if sh_r:
		sh_r.rotation.x -= 0.16
		chest.rotation.x -= 0.05
