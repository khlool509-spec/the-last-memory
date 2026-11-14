#!/usr/bin/env bash
# يستورد ثم يصيّر. الاستيراد إلزامي: محرك اللعبة لا يعيد استيراد
# صورة تغيّرت — يقرأ .godot/imported فقط — فبدون هذه الخطوة
# تُصيَّر خامات قديمة ويُظنّ أن التعديل بلا أثر.
set -e
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-$HOME/.local/bin/godot}"
"$GODOT" --headless --import --path . >/tmp/import.log 2>&1 || true
grep -c "reimport" /tmp/import.log | xargs -I{} echo "أُعيد استيراد {} ملفاً"
export VK_ICD_FILENAMES=/opt/lavapipe/lvp_icd.json
export VK_DRIVER_FILES=/opt/lavapipe/lvp_icd.json
timeout "${SHOT_TIMEOUT:-900}" xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . \
  --rendering-driver vulkan --rendering-method forward_plus --resolution 1280x720 \
  res://tools/shots/shoot.tscn >/tmp/shoot.log 2>&1
grep -aE "حُفظت|SCRIPT ERROR" /tmp/shoot.log || { echo "لا صور — آخر السجل:"; tail -5 /tmp/shoot.log; exit 1; }
