#!/usr/bin/env bash
# تشغيل كل اختبارات المشروع عبر Godot headless
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"

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
  elif echo "$SMOKE" | grep -qiE "Can't run project|ERROR|SCRIPT ERROR|Failed to"; then
    echo "  FAIL  ظهرت أخطاء أثناء التشغيل"
    echo "$SMOKE" | grep -iE "Can't run project|ERROR|SCRIPT ERROR|Failed to" | head -5
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
    "res://levels/test/test_3d.tscn" ; do
    OUT=$("$GODOT" --headless --path "$ROOT" "$SCENE" --quit-after 90 2>&1)
    RC=$?
    BAD=$(echo "$OUT" | grep -ciE "SCRIPT ERROR|Parse Error|ERROR:|Failed to|Cannot call|Invalid (call|get|set|access)|null instance" || true)
    if [ "$RC" -ne 0 ] || [ "$BAD" -gt 0 ]; then
      echo "  FAIL  $SCENE  (rc=$RC, أخطاء=$BAD)"
      echo "$OUT" | grep -iE "SCRIPT ERROR|Parse Error|ERROR:|Failed to|Cannot call|Invalid|null instance" | head -6
      CODE=$((CODE + 1))
    else
      echo "  PASS  $SCENE"
    fi
  done
fi

echo
if [ "$CODE" -eq 0 ]; then
  echo "النتيجة النهائية: كل الاختبارات نجحت"
else
  echo "النتيجة النهائية: $CODE اختبار أخفق"
fi
exit $CODE
