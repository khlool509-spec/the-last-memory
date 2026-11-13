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

echo
if [ "$CODE" -eq 0 ]; then
  echo "النتيجة النهائية: كل الاختبارات نجحت"
else
  echo "النتيجة النهائية: $CODE اختبار أخفق"
fi
exit $CODE
