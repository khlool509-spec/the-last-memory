extends Node
## إعدادات اللعبة: التحميل والحفظ والتطبيق الفوري.
## مسجَّل كـ autoload باسم Settings.

signal changed(key: String, value: Variant)

const PATH := "user://settings.cfg"
const SECTION := "game"

const DEFAULTS := {
	"master_volume": 0.8,
	"music_volume": 0.7,
	"sfx_volume": 0.7,
	"camera_sensitivity": 0.6,
	"language": "ar",
	"control_mode": "touch",
	"graphics_quality": "high",
	"time_of_day": "day",
	"brightness": 0.5,
	"show_vegetation": false,
	"invert_y": false,
	"show_fps": false,
	"vibration": true,
}

var _data: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()

func get_value(key: String) -> Variant:
	return _data.get(key, DEFAULTS.get(key))

func set_value(key: String, value: Variant) -> void:
	if _data.get(key) == value:
		return
	_data[key] = value
	_apply_one(key, value)
	changed.emit(key, value)

func reset_to_defaults() -> void:
	_data = DEFAULTS.duplicate(true)
	apply_all()
	save_settings()
	for k in _data:
		changed.emit(k, _data[k])

func load_settings() -> void:
	_data = DEFAULTS.duplicate(true)
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for key in DEFAULTS:
			if cfg.has_section_key(SECTION, key):
				_data[key] = cfg.get_value(SECTION, key)
	apply_all()

func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in _data:
		cfg.set_value(SECTION, key, _data[key])
	var err := cfg.save(PATH)
	if err != OK:
		push_warning("تعذّر حفظ الإعدادات: %d" % err)

func apply_all() -> void:
	for key in _data:
		_apply_one(key, _data[key])

func _apply_one(key: String, value: Variant) -> void:
	match key:
		"master_volume":
			_set_bus("Master", value)
		"music_volume":
			_set_bus("Music", value)
		"sfx_volume":
			_set_bus("SFX", value)
		"language":
			TranslationServer.set_locale(str(value))

func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	if linear <= 0.0005:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.0)))
