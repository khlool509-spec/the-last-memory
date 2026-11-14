extends Node
## مدير الصوت. مسجَّل كـ autoload باسم Audio.
## كل الأصوات مولَّدة رياضياً داخل المشروع (tools/gen_audio.py)،
## فلا يوجد أي أصل خارجي ولا مشكلة ترخيص.

const MUSIC := {
	"menu": "res://assets/audio/music/menu_drone.wav",
}
const AMBIENT := {
	"forest": "res://assets/audio/ambient/forest_night.wav",
}
const SFX := {
	"footstep_1": "res://assets/audio/sfx/footstep_1.wav",
	"footstep_2": "res://assets/audio/sfx/footstep_2.wav",
	"footstep_3": "res://assets/audio/sfx/footstep_3.wav",
	"footstep_4": "res://assets/audio/sfx/footstep_4.wav",
	"pickup": "res://assets/audio/sfx/pickup.wav",
	"note": "res://assets/audio/sfx/note.wav",
	"ui_click": "res://assets/audio/sfx/ui_click.wav",
	"ui_back": "res://assets/audio/sfx/ui_back.wav",
	"gate": "res://assets/audio/sfx/gate_rumble.wav",
	"heartbeat": "res://assets/audio/sfx/heartbeat.wav",
}

const SFX_VOICES := 8

var _music: AudioStreamPlayer
var _ambient: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _voice_i := 0
var _cache: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _current_music := ""
var _current_ambient := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()

	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.bus = "Music"
	add_child(_music)

	_ambient = AudioStreamPlayer.new()
	_ambient.name = "Ambient"
	_ambient.bus = "Music"
	_ambient.volume_db = -6.0
	add_child(_ambient)

	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.name = "SFX%d" % i
		p.bus = "SFX"
		add_child(p)
		_voices.append(p)

	# كل زر في اللعبة يصدر نقرة بلا توصيل يدوي في كل شاشة
	get_tree().node_added.connect(_auto_wire)

	Inv.item_added.connect(func(_id: String) -> void: play("pickup"))
	Inv.note_added.connect(func(_id: String) -> void: play("note"))

func _exit_tree() -> void:
	# تحرير المخزون عند الخروج وإلا بقيت موارد مستخدَمة ونبّه المحرك
	stop_all()
	for p in _voices:
		p.stop()
		p.stream = null
	_music.stream = null
	_ambient.stream = null
	_cache.clear()

func _auto_wire(n: Node) -> void:
	if n is BaseButton and not (n as BaseButton).pressed.is_connected(_on_any_button):
		(n as BaseButton).pressed.connect(_on_any_button.bind(n))

func _on_any_button(btn: Node) -> void:
	var txt := ""
	if btn is Button:
		txt = (btn as Button).text
	play("ui_back" if txt in ["رجوع", "أغلق", "خروج"] else "ui_click")

# ---------- التحميل ----------
func _stream(path: String, looped: bool) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		return null
	var s: AudioStream = ResourceLoader.load(path)
	if s is AudioStreamWAV and looped:
		# نسخة مستقلة: تعديل المورد المخزَّن بمساره يُبقيه حياً بعد الإغلاق
		var w := (s as AudioStreamWAV).duplicate(true) as AudioStreamWAV
		w.take_over_path("")
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		# 16-bit أحادي: بايتان لكل إطار
		w.loop_end = int(w.data.size() / 2.0)
		s = w
	_cache[path] = s
	return s

# ---------- التشغيل ----------
func play(key: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var path := str(SFX.get(key, ""))
	if path == "":
		return
	var s := _stream(path, false)
	if s == null:
		return
	var p := _voices[_voice_i]
	_voice_i = (_voice_i + 1) % _voices.size()
	p.stream = s
	p.pitch_scale = clampf(pitch, 0.4, 2.4)
	p.volume_db = volume_db
	p.play()

func play_footstep(running: bool) -> void:
	var n := _rng.randi_range(1, 4)
	play("footstep_%d" % n,
		_rng.randf_range(0.92, 1.1) * (1.08 if running else 1.0),
		-4.0 if running else -8.0)

func play_music(key: String) -> void:
	var path := str(MUSIC.get(key, ""))
	if path == "" or _current_music == key:
		return
	var s := _stream(path, true)
	if s == null:
		return
	_current_music = key
	_music.stream = s
	_music.volume_db = -10.0
	_music.play()

func stop_music() -> void:
	_current_music = ""
	_music.stop()

func play_ambient(key: String) -> void:
	var path := str(AMBIENT.get(key, ""))
	if path == "" or _current_ambient == key:
		return
	var s := _stream(path, true)
	if s == null:
		return
	_current_ambient = key
	_ambient.stream = s
	_ambient.play()

func stop_ambient() -> void:
	_current_ambient = ""
	_ambient.stop()

func stop_all() -> void:
	stop_music()
	stop_ambient()
