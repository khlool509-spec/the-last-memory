class_name LifeSupport
extends Node
## بدلة الفضاء: مخزون الأكسجين ينفد مع الزمن، والمجهود يسرّعه.
## لا تعرف شيئاً عن الواجهة — تبثّ نسبتها وحالاتها فقط.

signal oxygen_changed(ratio: float)
signal entered_warning()
signal entered_critical()
signal depleted()
signal refilled()

@export var capacity: float = 100.0
## استهلاك الراحة بالوحدة/ثانية — المخزون الكامل يكفي نحو 10 دقائق سكوناً
@export var idle_drain: float = 0.165
@export var walk_drain: float = 0.31
@export var run_drain: float = 0.72
@export var warning_ratio: float = 0.35
@export var critical_ratio: float = 0.15

var oxygen: float = 100.0
var active: bool = true

var _last_band: int = 0  # 0 سليم، 1 تحذير، 2 حرج، 3 نفد

func _ready() -> void:
	oxygen = capacity
	_last_band = 0

func ratio() -> float:
	return clampf(oxygen / maxf(0.001, capacity), 0.0, 1.0)

func is_empty() -> bool:
	return oxygen <= 0.0

## الثواني المتبقية عند معدل الاستهلاك الممرَّر
func seconds_left(drain: float) -> float:
	if drain <= 0.0:
		return INF
	return oxygen / drain

func refill(amount: float = -1.0) -> void:
	var before := oxygen
	oxygen = capacity if amount < 0.0 else minf(capacity, oxygen + amount)
	if not is_equal_approx(before, oxygen):
		_last_band = 0
		oxygen_changed.emit(ratio())
		refilled.emit()

## يُستدعى كل إطار من المستوى بحالة حركة اللاعب
func consume(delta: float, moving: bool, running: bool) -> void:
	if not active or oxygen <= 0.0:
		return
	var rate := idle_drain
	if running:
		rate = run_drain
	elif moving:
		rate = walk_drain
	var before := oxygen
	oxygen = maxf(0.0, oxygen - rate * delta)
	if not is_equal_approx(before, oxygen):
		oxygen_changed.emit(ratio())
	_check_bands()

func _check_bands() -> void:
	var r := ratio()
	var band := 0
	if oxygen <= 0.0:
		band = 3
	elif r <= critical_ratio:
		band = 2
	elif r <= warning_ratio:
		band = 1
	if band <= _last_band:
		return
	_last_band = band
	match band:
		1: entered_warning.emit()
		2: entered_critical.emit()
		3: depleted.emit()
