class_name Palette
extends RefCounted
## الهوية اللونية المعتمدة — مستخرجة من لوحة التوجيه الفني.
## كل لون في الواجهات يأتي من هنا، لا يُكتب بشكل مباشر في أي مكان آخر.

const VOID        := Color("#07070a")  # أعمق سواد — الخلفيات
const NIGHT       := Color("#0e0f14")  # ليل — ألواح
const ASH         := Color("#191b22")  # رماد — ألواح ثانوية
const SMOKE       := Color("#2a2d36")  # دخان — حدود خافتة

const BLOOD       := Color("#b2121f")  # الأحمر الأساسي
const BLOOD_HOT   := Color("#e4192b")  # أحمر متوهج — التحديد
const BLOOD_DEEP  := Color("#6d0a12")  # أحمر داكن — الظلال
const EMBER       := Color("#ff4b3a")  # جمرة — التوهج

const BONE        := Color("#e9e4dc")  # نص أساسي
const DUST        := Color("#a39d94")  # نص ثانوي
const MUTED       := Color("#6b665f")  # نص معطّل

const MOON        := Color("#cfe0f2")  # ضوء القمر — لمسات باردة
const MOON_DIM    := Color("#7d93ad")

static func with_alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)
