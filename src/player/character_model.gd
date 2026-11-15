class_name CharacterModel
extends Node3D
## مُحمِّل شخصيات مجهّزة بهيكل عظمي — مستقلّ عن مصدر المجسّم.
##
## يقبل أي ملف ‎.glb فيه Skeleton3D و AnimationPlayer، ويربط حالات
## اللعب بأسماء حركاته مهما اختلفت تسمياتها: المطابقة بالكلمات لا
## بالاسم الحرفي، فمجسّم يسمّي حركته "Run" وآخر يسمّيها
## "running_gun-cycle" كلاهما يعمل بلا تعديل كود.
##
## هذا هو ما يجعل استبدال الشخصية لاحقاً عملاً بدقائق لا بإعادة
## كتابة: المنطق هنا، والمجسّم ملف يُبدَّل.

## كلمات تُطابَق في أسماء الحركات، بترتيب الأولوية لكل حالة
const MATCH := {
	"idle":   [["idle", "cycle"], ["idle"], ["stand"]],
	"walk":   [["walk", "gun"], ["walk"], ["move"]],
	"run":    [["run", "gun"], ["run"], ["sprint"], ["jog"]],
	"aim":    [["aim", "center"], ["aim"], ["idlecombat"], ["standing"]],
	"crouch": [["crouch"], ["kneel"], ["duck"]],
	"prone":  [["prone"], ["crawl"], ["lay"]],
	# لا حركة سباحة في كل الحزم. حين تغيب نستعير المشي ونُميل الجسم
	# أفقياً من الكود — ساقان تتحرّكان وجسد منبسط يُقرآن سباحة.
	"swim":   [["swim"], ["float"], ["walk"]],
	"dive":   [["dive"], ["swim", "down"], ["swim"], ["walk"]],
	"jump":   [["jump", "midair"], ["jump"], ["fall"]],
	"fire":   [["fire"], ["shoot"], ["attack"]],
}
## حركات تجريبية يتركها الفنّانون في الملف — تُستبعَد من المطابقة
const JUNK := ["noexp", "borrar", "test", "ph", "xxx", "zzz", "metarig"]

var anim: AnimationPlayer = null
var skel: Skeleton3D = null
var root: Node3D = null
var _map: Dictionary = {}
var _current := ""
var _ok := false
## أوضاع تُطبَّق على الجذر حين تغيب حركتها من الحزمة: إمالة وخفض
## بدل حركة مخصّصة. الصدق هنا أنفع من ادّعاء حركة غير موجودة.
const POSE_FIX := {
	"swim":   {"pitch": -78.0, "lift": -0.55, "squash": 1.0},
	"dive":   {"pitch": -62.0, "lift": -0.80, "squash": 1.0},
	"prone":  {"pitch": -86.0, "lift": -0.74, "squash": 1.0},
	"crouch": {"pitch": 0.0,   "lift": -0.34, "squash": 0.74},
}
var _base_scale := Vector3.ONE
var _pose_t := 0.0
var _base_yaw := 0.0

func is_loaded() -> bool:
	return _ok

## يحمّل مجسّماً من res://. يعود false إن لم يوجد أو لم يكن مجهّزاً،
## فيستطيع النداء الرجوع إلى الشخصية المفصليّة بلا انهيار.
func load_model(path: String, scale_to_height: float = 0.0) -> bool:
	if not ResourceLoader.exists(path):
		push_warning("مجسّم الشخصية غير موجود: " + path)
		return false
	var packed := ResourceLoader.load(path)
	if packed == null or not (packed is PackedScene):
		push_warning("مجسّم الشخصية ليس مشهداً صالحاً: " + path)
		return false
	root = (packed as PackedScene).instantiate() as Node3D
	if root == null:
		return false
	add_child(root)
	anim = _find(root, "AnimationPlayer") as AnimationPlayer
	skel = _find(root, "Skeleton3D") as Skeleton3D
	if anim == null:
		push_warning("لا مشغّل حركات في: " + path)
		return false
	_build_map()
	if scale_to_height > 0.0:
		_fit_height(scale_to_height)
	_base_scale = root.scale
	# مجسّمات مصادر الأصول تواجه ‎+Z‎ غالباً، وأمام Godot هو ‎-Z‎.
	# بدون هذه الدورة تمشي الشخصية وهي تنظر إلى الكاميرا لا إلى
	# حيث تتّجه — وهو ما بدا «وجهه بالنظر إليّ».
	root.rotation.y += PI
	_base_yaw = root.rotation.y
	_ok = true
	return true

func _find(n: Node, cls: String) -> Node:
	if n.get_class() == cls:
		return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r != null:
			return r
	return null

## يوحّد طول الشخصية: مجسّمات المصادر المختلفة تأتي بمقاييس مختلفة،
## وبدون التوحيد تغرق إحداها في الأرض وتطفو أخرى فوقها.
func _fit_height(target: float) -> void:
	# بالفضاء المحلّي لا العالمي: القياس يجري قبل دخول المشهد الشجرة،
	# و global_transform هناك غير معرّف ويطبع خطأً في كل نداء.
	var aabb := AABB()
	var first := true
	for m in _meshes(root):
		var b: AABB = _local_xform(m) * (m as MeshInstance3D).get_aabb()
		if first:
			aabb = b
			first = false
		else:
			aabb = aabb.merge(b)
	if aabb.size.y > 0.01:
		var k := target / aabb.size.y
		root.scale = Vector3(k, k, k)

## تحويل العقدة بالنسبة إلى جذر المجسّم، بالصعود في السلسلة
func _local_xform(n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t

func _meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out

func _build_map() -> void:
	var names := anim.get_animation_list()
	var clean: Array = []
	for a in names:
		var low := String(a).to_lower()
		var junky := false
		for j in JUNK:
			if low.contains(j):
				junky = true
				break
		if not junky:
			clean.append(a)
	# إن استُبعد كل شيء نرجع إلى القائمة الكاملة: ملف سيّئ التسمية
	# أفضل من شخصية جامدة.
	if clean.is_empty():
		clean = names

	for state in MATCH:
		for wordset in MATCH[state]:
			var hit := _first_with(clean, wordset)
			if hit != "":
				_map[state] = hit
				break
	print("[CharacterModel] رُبطت %d حالة من %d حركة"
		% [_map.size(), names.size()])

func _first_with(list: Array, words: Array) -> String:
	for a in list:
		var low := String(a).to_lower()
		var all := true
		for w in words:
			if not low.contains(String(w)):
				all = false
				break
		if all:
			return String(a)
	return ""

## الحالة بالعربية كما يصدرها اللاعب → حركة المجسّم
const STATE_KEY := {
	"مشي": "walk", "ركض": "run", "قرفصاء": "crouch",
	"انبطاح": "prone", "سباحة": "swim", "غوص": "dive",
}

func play_state(state: String, speed: float, aiming: bool) -> void:
	if not _ok:
		return
	var key: String = str(STATE_KEY.get(state, "idle"))
	if speed < 0.2 and key in ["walk", "run"]:
		key = "idle"
	if aiming and _map.has("aim") and key in ["idle", "walk"]:
		key = "aim"
	_apply_pose_fix(key)
	var clip: String = str(_map.get(key, _map.get("idle", "")))
	if clip == "" or clip == _current:
		return
	_current = clip
	anim.play(clip, 0.25)

## يطبّق الإمالة والخفض على الجذر حسب الحالة. التحوّل ناعم فلا
## تقفز الشخصية بين وضع وآخر.
func _apply_pose_fix(key: String) -> void:
	if root == null:
		return
	var f: Dictionary = POSE_FIX.get(key, {})
	var pitch := float(f.get("pitch", 0.0))
	var lift := float(f.get("lift", 0.0))
	var squash := float(f.get("squash", 1.0))
	root.rotation.y = _base_yaw            # لا تُفقد دورة الاصطلاح
	root.rotation_degrees.x = lerpf(root.rotation_degrees.x, pitch, 0.18)
	root.position.y = lerpf(root.position.y, lift, 0.18)
	var want := _base_scale * Vector3(1.0, squash, 1.0)
	root.scale = root.scale.lerp(want, 0.18)

func fire_once() -> void:
	if _ok and _map.has("fire"):
		anim.play(str(_map["fire"]), 0.05)
		_current = ""
