class_name ItemDB
extends RefCounted
## تعريفات كل الأغراض. مصدر واحد تستهلكه الحقيبة والمذكرات والواجهات.

enum Kind { NOTE, KEY, TOOL, RELIC }

const ITEMS := {
	"note_awakening": {
		"name": "ورقة ممزقة", "kind": Kind.NOTE, "glyph": "✉",
		"desc": "خط مرتجف: «إن قرأت هذا فقد نسيتَ مرة أخرى.»",
		"body": "إن قرأت هذا فقد نسيتَ مرة أخرى.\nلا تثق بالبوابة. لا تثق بي.\nاتبع الفوانيس ولا تنظر خلفك.",
	},
	"note_lantern": {
		"name": "قصاصة محترقة", "kind": Kind.NOTE, "glyph": "✉",
		"desc": "نصفها رماد، والباقي بالكاد يُقرأ.",
		"body": "…الفوانيس لم تُشعل نفسها. أحدهم يسبقنا دائماً…",
	},
	"old_key": {
		"name": "مفتاح صدئ", "kind": Kind.KEY, "glyph": "⚷",
		"desc": "ثقيل أكثر مما ينبغي لمفتاح.",
		"body": "",
	},
	"lantern": {
		"name": "فانوس قديم", "kind": Kind.TOOL, "glyph": "✦",
		"desc": "زجاجه متشقق لكن اللهب ما زال حياً.",
		"body": "",
	},
	"pendant": {
		"name": "قلادة مكسورة", "kind": Kind.RELIC, "glyph": "◆",
		"desc": "نصف صورة داخلها. الوجه الآخر مفقود.",
		"body": "",
	},
	"gate_sigil": {
		"name": "ختم البوابة", "kind": Kind.RELIC, "glyph": "✵",
		"desc": "رموز لا تشبه أي لغة يعرفها.",
		"body": "",
	},
}

static func get_item(id: String) -> Dictionary:
	return ITEMS.get(id, {})

static func exists(id: String) -> bool:
	return ITEMS.has(id)

static func display_name(id: String) -> String:
	return str(get_item(id).get("name", id))

static func glyph(id: String) -> String:
	return str(get_item(id).get("glyph", "?"))

static func is_note(id: String) -> bool:
	return int(get_item(id).get("kind", -1)) == Kind.NOTE

static func all_ids() -> Array:
	return ITEMS.keys()
