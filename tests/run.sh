#!/usr/bin/env bash
# تشغيل كل اختبارات المشروع عبر Godot headless
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"

# ملاحظة: بالتشغيل الصامت يُستخدم سائق صوت وهمي لا يعالج شيئاً، فتبقى
# كائنات AudioStreamPlayback حيّة حتى الإغلاق ويطبع المحرك تحذير تسريب.
# هذا أثر البيئة الصامتة لا عيب في اللعبة، فيُستثنى سطراه وحدهما.
EXIT_NOISE='resources still in use at exit|ObjectDB instances were leaked at exit|Leaked instance:|Resource still in use:|Hint: Leaked instances'


echo "محرك: $($GODOT --headless --version)"
echo

"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1

"$GODOT" --headless --path "$ROOT" --script res://tests/test_runner.gd
CODE=$?

# اختبار دخان: تشغيل المشروع فعلياً كما يشغّله الجهاز.
# هذا ما كان سيكشف خطأ "Unable to setup the Godot engine!" مبكراً.
if [ "$CODE" -eq 0 ]; then
  echo
  echo "[اختبار الدخان: تشغيل المشروع 180 إطاراً]"
  SMOKE=$("$GODOT" --headless --path "$ROOT" --quit-after 180 2>&1)
  SMOKE_CODE=$?
  if [ "$SMOKE_CODE" -ne 0 ]; then
    echo "  FAIL  المشروع خرج برمز $SMOKE_CODE"
    echo "$SMOKE" | tail -10
    CODE=$((CODE + 1))
  elif echo "$SMOKE" | grep -vE "$EXIT_NOISE" | grep -qiE "Can't run project|ERROR|SCRIPT ERROR|Failed to"; then
    echo "  FAIL  ظهرت أخطاء أثناء التشغيل"
    echo "$SMOKE" | grep -vE "$EXIT_NOISE" | grep -iE "Can't run project|ERROR|SCRIPT ERROR|Failed to" | head -5
    CODE=$((CODE + 1))
  else
    echo "  PASS  المشروع يعمل 180 إطاراً بلا أخطاء"
  fi
fi

# اختبار إقلاع كل شاشة على حدة: يشغّل _ready فعلياً فيكشف أخطاء
# البناء وقت التشغيل التي لا يكشفها التحميل وحده.
if [ "$CODE" -eq 0 ]; then
  echo
  echo "[اختبار إقلاع الشاشات]"
  for SCENE in \
    "res://src/ui/screens/main_menu.tscn" \
    "res://src/ui/screens/settings_menu.tscn" \
    "res://src/ui/screens/chapters_menu.tscn" \
    "res://src/ui/screens/collectibles_menu.tscn" \
    "res://levels/test/playground.tscn" \
    "res://levels/test/test_3d.tscn" \
    "res://levels/ch01_forest/chapter_one.tscn" ; do
    OUT=$("$GODOT" --headless --path "$ROOT" "$SCENE" --quit-after 90 2>&1)
    RC=$?
    CLEAN=$(echo "$OUT" | grep -vE "$EXIT_NOISE" || true)
    BAD=$(echo "$CLEAN" | grep -ciE "SCRIPT ERROR|Parse Error|ERROR:|Failed to|Cannot call|Invalid (call|get|set|access)|null instance" || true)
    if [ "$RC" -ne 0 ] || [ "$BAD" -gt 0 ]; then
      echo "  FAIL  $SCENE  (rc=$RC, أخطاء=$BAD)"
      echo "$CLEAN" | grep -iE "SCRIPT ERROR|Parse Error|ERROR:|Failed to|Cannot call|Invalid|null instance" | head -6
      CODE=$((CODE + 1))
    else
      echo "  PASS  $SCENE"
    fi
  done
fi

# اختبارات اللعب: تعمل بالحلقة العادية فتكون الـ autoloads حيّة.
# تُرصد هنا أخطاء التشغيل أيضاً، لا الإخفاقات المعلنة وحدها.
if [ "$CODE" -eq 0 ]; then
  echo
  OUT=$("$GODOT" --headless --path "$ROOT" res://tests/gameplay_test.tscn 2>&1)
  RC=$?
  echo "$OUT" | sed -n '/=== اختبارات اللعب ===/,$p'
  BAD=$(echo "$OUT" | grep -vE "$EXIT_NOISE" | grep -ciE "SCRIPT ERROR|Parse Error|Cannot call|Invalid (call|get|set|access)|null instance" || true)
  if [ "$RC" -ne 0 ]; then
    echo "  >> أخفقت اختبارات اللعب (عدد الإخفاقات=$RC)"
    CODE=$((CODE + RC))
  fi
  if [ "$BAD" -gt 0 ]; then
    echo "  >> أخطاء تشغيل أثناء اختبارات اللعب: $BAD"
    echo "$OUT" | grep -iE "SCRIPT ERROR|Parse Error|Cannot call|Invalid|null instance" | head -8
    CODE=$((CODE + BAD))
  fi
fi

# اختبارات العالم المفتوح: فيزياء حقيقية على التضاريس المخبوزة
if [ "$CODE" -eq 0 ]; then
  echo
  OUT=$("$GODOT" --headless --path "$ROOT" res://tests/world_test.tscn 2>&1)
  RC=$?
  echo "$OUT" | sed -n '/=== اختبارات العالم ===/,$p'
  BAD=$(echo "$OUT" | grep -vE "$EXIT_NOISE" | grep -ciE "SCRIPT ERROR|Parse Error|Cannot call|Invalid (call|get|set|access)|null instance" || true)
  if [ "$RC" -ne 0 ]; then
    echo "  >> أخفقت اختبارات العالم (عدد الإخفاقات=$RC)"
    CODE=$((CODE + RC))
  fi
  if [ "$BAD" -gt 0 ]; then
    echo "  >> أخطاء تشغيل أثناء اختبارات العالم: $BAD"
    echo "$OUT" | grep -vE "$EXIT_NOISE" | grep -iE "SCRIPT ERROR|Parse Error|Cannot call|Invalid|null instance" | head -8
    CODE=$((CODE + BAD))
  fi
fi

# فحص التخطيط: يكشف العناصر صفرية المساحة أو الخارجة عن الكادر
if [ "$CODE" -eq 0 ]; then
  echo
  OUT=$("$GODOT" --headless --path "$ROOT" res://tools/layout_check.tscn 2>&1)
  RC=$?
  echo "$OUT" | grep -E "^\[|PASS|FAIL|التخطيط" | sed 's/^/  /'
  if [ "$RC" -ne 0 ]; then
    CODE=$((CODE + RC))
  fi
fi

echo
if [ "$CODE" -eq 0 ]; then
  echo "النتيجة النهائية: كل الاختبارات نجحت"
else
  echo "النتيجة النهائية: $CODE اختبار أخفق"
fi
exit $CODE
