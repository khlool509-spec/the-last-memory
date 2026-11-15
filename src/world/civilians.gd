class_name Civilians
extends Node3D
## مدنيّون يسكنون العالم — يمشون ويقفون وينظرون حولهم وينتبهون للّاعب.
##
## الهدف أن يُحسّ المكان مأهولاً، لا أن يُحاكى ذكاء بشري كامل. آلة حالات
## صغيرة تعطي ذلك بكلفة شبه معدومة: كل مدنيّ عقدة واحدة بسلوك محدود،
## والعدد الظاهر مقيّد بالمسافة فلا يدفع الجوال ثمن من لا يُرى.
##
## الكلفة مضبوطة عمداً: التحديث يدور على المدنيّين بالتناوب لا كلّهم في
## الإطار الواحد، فيبقى الحمل ثابتاً مهما زاد العدد.

const COUNT := 14
const WANDER_R := 46.0            # نصف قطر التجوال حول نقطة السكن
const SEE_PLAYER := 16.0          # متى ينتبه المدنيّ للاعب
const UPDATE_SLICE := 4           # كم مدنيّاً يُحدَّث في الإطار الواحد

class Civ:
	var rig: CharacterRig
	var home: Vector3
	var target: Vector3
	var state := "idle"           # idle / walk / look / flee
	var timer := 0.0
	var speed := 1.25
	var yaw := 0.0

var _civs: Array = []
var _cursor := 0
var _player: Node3D = null
var _profile = null

func setup(profile, player: Node3D) -> void:
	_profile = profile
	_player = player
	_spawn()

func _spawn() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9173
	var placed := 0
	var tries := 0
	while placed < COUNT and tries < COUNT * 40:
		tries += 1
		var x := rng.randf_range(-150.0, 150.0)
		var z := rng.randf_range(-150.0, 150.0)
		var h: float = _profile.height(x, z)
		# لا أحد يقف في الماء ولا على منحدر لا يُمشى عليه
		if h <= _profile.WATER_LEVEL + 0.9:
			continue
		if _profile.slope(x, z) > 0.30:
			continue
		var c := Civ.new()
		c.home = Vector3(x, h, z)
		c.target = c.home
		c.speed = rng.randf_range(0.95, 1.65)
		c.rig = CharacterRig.create("female" if rng.randf() < 0.45 else "male")
		c.rig.position = c.home
		c.rig.rotation.y = rng.randf_range(0.0, TAU)
		c.yaw = c.rig.rotation.y
		# المدنيّون يختفون في المسافة: لا قيمة لرسم من لا يُميَّز
		for ch in c.rig.get_children():
			if ch is GeometryInstance3D:
				(ch as GeometryInstance3D).visibility_range_end = 95.0
		add_child(c.rig)
		_civs.append(c)
		placed += 1

func _process(delta: float) -> void:
	if _civs.is_empty():
		return
	var ppos: Vector3 = _player.global_position if _player else Vector3.ZERO

	# شريحة من المدنيّين كل إطار: الحمل ثابت لا يتضاعف بالعدد
	for n in UPDATE_SLICE:
		_cursor = (_cursor + 1) % _civs.size()
		_think(_civs[_cursor], ppos, delta * float(_civs.size())
			/ float(UPDATE_SLICE))

	# أما الحركة والتحريك فلكلّ واحد كل إطار، وإلا بدت متقطّعة
	for c in _civs:
		_move(c, delta)

func _think(c: Civ, ppos: Vector3, dt: float) -> void:
	c.timer -= dt
	var near: float = c.rig.position.distance_to(ppos)

	# الانتباه للّاعب يسبق كل شيء: اقتراب غريب يوقف ما في اليد
	if near < SEE_PLAYER and c.state != "flee":
		c.state = "look"
		c.timer = 1.6
		return

	if c.timer > 0.0:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = int(c.rig.position.x * 131.0 + c.rig.position.z * 17.0
		+ Time.get_ticks_msec() / 97)
	match c.state:
		"walk":
			c.state = "idle"
			c.timer = rng.randf_range(1.8, 5.5)
		_:
			# وجهة جديدة داخل نطاق السكن، على أرض يابسة وممشيّة
			for _try in 8:
				var a := rng.randf_range(0.0, TAU)
				var r := rng.randf_range(6.0, WANDER_R)
				var p := c.home + Vector3(cos(a) * r, 0.0, sin(a) * r)
				var h: float = _profile.height(p.x, p.z)
				if h > _profile.WATER_LEVEL + 0.9 \
						and _profile.slope(p.x, p.z) < 0.34:
					c.target = Vector3(p.x, h, p.z)
					c.state = "walk"
					c.timer = rng.randf_range(4.0, 11.0)
					break

func _move(c: Civ, delta: float) -> void:
	var state_name := "مشي"
	var spd := 0.0
	if c.state == "walk":
		var to := c.target - c.rig.position
		to.y = 0.0
		if to.length() < 0.6:
			c.state = "idle"
			c.timer = 1.0
		else:
			var dir := to.normalized()
			spd = c.speed
			var step := dir * spd * delta
			var np := c.rig.position + step
			np.y = _profile.height(np.x, np.z)
			c.rig.position = np
			c.yaw = lerp_angle(c.yaw, atan2(-dir.x, -dir.z),
				clampf(5.0 * delta, 0.0, 1.0))
	elif c.state == "look" and _player:
		# يستدير نحو اللاعب: أوضح إشارة على أن هناك من ينتبه
		var to := _player.global_position - c.rig.position
		to.y = 0.0
		if to.length() > 0.1:
			c.yaw = lerp_angle(c.yaw, atan2(-to.x, -to.z),
				clampf(4.0 * delta, 0.0, 1.0))
	c.rig.rotation.y = c.yaw
	c.rig.pose(state_name, spd, delta, false)
