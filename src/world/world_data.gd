class_name WorldData
extends Resource
## العالم المخبوز. يُولَّد مرة بأمر واحد ويُحمَّل جاهزاً على الجهاز،
## فلا يدفع اللاعب ثمن توليد التضاريس عند كل تشغيل.
##
## ملحوظة مهمة: بيانات MultiMesh لا تنجو من الحفظ بالتشغيل الصامت
## (خادم العرض الوهمي يُهملها)، لذلك يُخزَّن النبات هنا كأرقام خام
## وتُملأ الـ MultiMesh منها وقت التشغيل — وهو رخيص.

@export var chunk_size: float = 40.0
@export var grid: int = 10
@export var world_half: float = 200.0

## شبكة واحدة لكل مقطع أرض
@export var chunk_meshes: Array[ArrayMesh] = []

## خريطة ارتفاع التصادم — تُقرأ مباشرة إلى HeightMapShape3D
@export var height_res: int = 201
@export var height_step: float = 2.0
@export var height_map: PackedFloat32Array = PackedFloat32Array()

## النبات والتفاصيل: اسم النوع -> 12 رقماً لكل نسخة (مصفوفة Transform3D)
@export var scatter: Dictionary = {}

## خطوط العالم ومواقعه
@export var river_points: PackedVector2Array = PackedVector2Array()
@export var road_segments: Array = []
@export var poi: Dictionary = {}
@export var water_level: float = -2.6

func chunk_origin(i: int, j: int) -> Vector3:
	return Vector3(-world_half + float(i) * chunk_size, 0.0, -world_half + float(j) * chunk_size)

## ارتفاع من خريطة التصادم بالاستيفاء الثنائي — نفس ما تراه الفيزياء
func sample_height(x: float, z: float) -> float:
	if height_map.is_empty():
		return 0.0
	var fx := (x + world_half) / height_step
	var fz := (z + world_half) / height_step
	var i0 := clampi(int(floor(fx)), 0, height_res - 1)
	var j0 := clampi(int(floor(fz)), 0, height_res - 1)
	var i1 := mini(i0 + 1, height_res - 1)
	var j1 := mini(j0 + 1, height_res - 1)
	var tx := clampf(fx - float(i0), 0.0, 1.0)
	var tz := clampf(fz - float(j0), 0.0, 1.0)
	var h00 := height_map[j0 * height_res + i0]
	var h10 := height_map[j0 * height_res + i1]
	var h01 := height_map[j1 * height_res + i0]
	var h11 := height_map[j1 * height_res + i1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)

func instance_count(species: String) -> int:
	if not scatter.has(species):
		return 0
	var arr: PackedFloat32Array = scatter[species]
	return int(arr.size() / 12.0)

## الترتيب هو ترتيب MultiMesh.buffer نفسه: مصفوفة 3x4 صفاً صفاً.
## بهذا تُحمَّل آلاف النسخ بإسناد واحد بدل نداء لكل نسخة — وهذا الفرق
## بين تركيب العالم في جزء من ثانية وبين تعليق الجهاز دقائق.
static func pack_transform(into: PackedFloat32Array, t: Transform3D) -> void:
	var b := t.basis
	into.append(b.x.x); into.append(b.y.x); into.append(b.z.x); into.append(t.origin.x)
	into.append(b.x.y); into.append(b.y.y); into.append(b.z.y); into.append(t.origin.y)
	into.append(b.x.z); into.append(b.y.z); into.append(b.z.z); into.append(t.origin.z)

## فكّ النسخة رقم k من مصفوفة مُمرَّرة — لا قراءة من القاموس لكل نسخة
static func unpack_transform(arr: PackedFloat32Array, k: int) -> Transform3D:
	var o := k * 12
	return Transform3D(
		Basis(Vector3(arr[o], arr[o + 4], arr[o + 8]),
			  Vector3(arr[o + 1], arr[o + 5], arr[o + 9]),
			  Vector3(arr[o + 2], arr[o + 6], arr[o + 10])),
		Vector3(arr[o + 3], arr[o + 7], arr[o + 11]))

func instance_transform(species: String, k: int) -> Transform3D:
	return unpack_transform(scatter[species], k)
