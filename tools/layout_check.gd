extends Node
## فحص التخطيط: يشغّل كل شاشة داخل الشجرة ويتأكد أن عناصرها
## لها مساحة فعلية وداخل حدود الشاشة.
## أُضيف بعد خلل حقيقي: layout_direction=RTL عكس المراسي فصارت
## خلفية الشاشة بمساحة صفر وطارت القائمة خارج الكادر.

const SCENES := [
	"res://src/ui/screens/main_menu.tscn",
	"res://src/ui/screens/settings_menu.tscn",
	"res://src/ui/screens/chapters_menu.tscn",
	"res://src/ui/screens/collectibles_menu.tscn",
]

var _fail := 0

func _ready() -> void:
	print("=== فحص التخطيط ===")
	for path in SCENES:
		await _check(path)
	print("\n=== التخطيط: %s ===" % ("سليم" if _fail == 0 else "%d مشكلة" % _fail))
	get_tree().quit(_fail)

func _check(path: String) -> void:
	var ps: PackedScene = load(path)
	if ps == null:
		_bad(path, "تعذّر التحميل")
		return
	var inst := ps.instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	var vp := get_viewport().get_visible_rect()
	var root := inst as Control
	if root == null:
		inst.queue_free()
		return
	print("\n[%s]  %s" % [path.get_file(), str(root.size)])
	var problems := 0
	for c in root.get_children():
		if not (c is Control):
			continue
		var cc := c as Control
		if not cc.visible:
			continue
		if cc.size.x < 1.0 or cc.size.y < 1.0:
			print("  FAIL  %s مساحته صفر: %s" % [cc.name, str(cc.size)])
			problems += 1
			continue
		var r := Rect2(cc.global_position, cc.size)
		if not vp.intersects(r):
			print("  FAIL  %s خارج الشاشة: pos=%s size=%s" % [cc.name, str(cc.global_position), str(cc.size)])
			problems += 1
			continue
		# تحذير إن خرج أكثر من ثلثه خارج الكادر
		var inter := vp.intersection(r)
		var ratio := (inter.size.x * inter.size.y) / maxf(1.0, r.size.x * r.size.y)
		if ratio < 0.66:
			print("  FAIL  %s مقصوص: %d%% فقط داخل الشاشة" % [cc.name, int(ratio * 100.0)])
			problems += 1
		else:
			print("  PASS  %-18s size=%s" % [cc.name, str(cc.size)])
	if problems == 0:
		print("  → سليم")
	_fail += problems
	inst.queue_free()
	await get_tree().process_frame

func _bad(path: String, why: String) -> void:
	print("  FAIL  %s: %s" % [path, why])
	_fail += 1
