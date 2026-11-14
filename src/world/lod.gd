class_name Lod
extends RefCounted
## مستويات التفصيل للعالم كله — لا للأشجار وحدها.
##
## القاعدة: لا شيء يُرسم أبعد مما يُرى فيه فعلاً. الأثاث داخل بيت
## لا معنى لرسمه من مئة متر، والسقف يُرى من بعيد. يكفي أن يُعلَّم
## أي مجسّم جديد بصنفه فيأخذ مداه تلقائياً.
##
## الاستعمال: Lod.tag(node, Lod.PROP) ثم Lod.apply(root)
## أو Lod.apply(root, Lod.STRUCTURE) ليرث كل ما بالداخل الصنف.

const META := "lod_class"

## الأصناف ومدياتها الأساسية بالأمتار (تُضرب في مقياس الجودة)
const SILHOUETTE := "silhouette"   # ما يصنع الظلّ البعيد: جدران، أسقف، بوابة
const STRUCTURE := "structure"     # هيكل المبنى وتفاصيله الخارجية
const PROP := "prop"               # أغراض خارجية: براميل، صناديق، سياج
const FURNITURE := "furniture"     # أثاث داخلي لا يُرى من الخارج
const DETAIL := "detail"           # تفاصيل دقيقة: مقابض، ألواح، زخارف
const ALWAYS := "always"           # لا يُقصّ أبداً

const RANGES := {
	SILHOUETTE: 260.0,
	STRUCTURE: 150.0,
	PROP: 70.0,
	FURNITURE: 34.0,
	DETAIL: 26.0,
	ALWAYS: 0.0,
}

const FADE := 6.0

static func tag(n: Node, cls: String) -> void:
	n.set_meta(META, cls)

## يضع المدى على كل مجسّم في الشجرة. الصنف يُورَّث من الأب ما لم
## يُعلَّم الابن بصنف خاص به.
static func apply(root: Node, inherited: String = STRUCTURE, scale: float = 1.0) -> int:
	var cls := inherited
	if root.has_meta(META):
		cls = str(root.get_meta(META))
	var touched := 0
	if root is GeometryInstance3D:
		var gi := root as GeometryInstance3D
		var r: float = float(RANGES.get(cls, 120.0)) * scale
		if r > 0.0:
			gi.visibility_range_end = r
			gi.visibility_range_end_margin = FADE
			gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			touched += 1
		# الظلال أغلى من الرسم: تبقى للهياكل القريبة فقط
		if cls == FURNITURE or cls == DETAIL:
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in root.get_children():
		touched += apply(c, cls, scale)
	return touched

## الأضواء أيضاً تُقصّ: ضوء داخل بيت بعيد يكلّف ولا يُرى
static func apply_lights(root: Node, dist: float = 48.0) -> int:
	var n := 0
	if root is OmniLight3D or root is SpotLight3D:
		(root as Light3D).distance_fade_enabled = true
		(root as Light3D).distance_fade_begin = dist * 0.72
		(root as Light3D).distance_fade_length = dist * 0.28
		(root as Light3D).distance_fade_shadow = dist * 0.5
		n += 1
	for c in root.get_children():
		n += apply_lights(c, dist)
	return n

static func scale_for_quality(q: String) -> float:
	match q:
		"low": return 0.62
		"medium": return 0.84
	return 1.0
