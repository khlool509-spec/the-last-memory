#!/usr/bin/env python3
"""ينزّل خامات PBR من Poly Haven ويتحقّق من بصمتها قبل القبول.

لا يُقبل ملف لا تطابق بصمته ما تُعلنه الواجهة الرسمية. المصدر CC0،
والمنشأ والبصمة والحجم تُسجَّل في assets/textures/pbr/MANIFEST.json
حتى يمكن التحقّق لاحقاً من كل ملف دخل المشروع.
"""
import hashlib, json, os, subprocess, sys
from pathlib import Path

API = "https://api.polyhaven.com"
OUT = Path(os.environ.get("PBR_OUT", "assets/textures/pbr"))
RES = os.environ.get("PBR_RES", "2k")
WANT = {                      # المعرّف: (الخرائط، الدقة)
    "forest_ground_04":    (["Diffuse", "nor_gl", "arm"], RES),
    "brown_mud_leaves_01": (["Diffuse", "nor_gl", "arm"], RES),
    "aerial_rocks_02":     (["Diffuse", "nor_gl", "arm"], RES),
    "aerial_grass_rock":   (["Diffuse", "nor_gl", "arm"], RES),
    "leafy_grass":         (["Diffuse", "nor_gl", "arm"], RES),
    "forrest_ground_01":   (["Diffuse", "nor_gl", "arm", "Displacement"], RES),
    "rocky_terrain_02":    (["Diffuse", "nor_gl", "arm"], RES),
    "weathered_plank_siding": (["Diffuse", "nor_gl", "arm"], RES),
    "weathered_planks":    (["Diffuse", "nor_gl", "arm"], RES),
    "lichen_rock":         (["Diffuse", "nor_gl", "arm"], RES),
    "red_slate_roof_tiles_01": (["Diffuse", "nor_gl", "arm"], RES),
    "roof_07":             (["Diffuse", "nor_gl", "arm"], RES),
    "beam_wall_01":        (["Diffuse", "nor_gl", "arm"], RES),
    "coral_stone_wall":    (["Diffuse", "nor_gl", "arm"], RES),
    "forest_floor":        (["Diffuse", "nor_gl", "arm", "Displacement"], RES),
    "mud_forest":          (["Diffuse", "nor_gl", "arm", "Displacement"], RES),
    "rocky_terrain":       (["Diffuse", "nor_gl", "arm"], RES),
}
SUFFIX = {"Diffuse": "diff", "nor_gl": "nor", "arm": "arm", "Displacement": "disp"}


def get(url: str) -> bytes:
    r = subprocess.run(["curl", "-sS", "--max-time", "180", url],
                       capture_output=True)
    if r.returncode != 0:
        raise RuntimeError(f"curl فشل على {url}: {r.stderr.decode()[:200]}")
    return r.stdout


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {}
    bad = 0
    for aid, (maps, res) in WANT.items():
        info = json.loads(get(f"{API}/info/{aid}"))
        files = json.loads(get(f"{API}/files/{aid}"))
        entry = {
            "source": f"https://polyhaven.com/a/{aid}",
            "api": f"{API}/files/{aid}",
            "license": "CC0 1.0",
            "license_url": "https://polyhaven.com/license",
            "authors": info.get("authors", {}),
            "real_size_mm": info.get("dimensions"),
            "max_resolution": info.get("max_resolution"),
            "files": {},
        }
        for m in maps:
            node = files.get(m, {}).get(res, {}).get("jpg")
            if node is None:
                print(f"  تعذّر: {aid}/{m} غير متاح بصيغة jpg {res}")
                bad += 1
                continue
            name = f"{aid}_{SUFFIX[m]}_{res}.jpg"
            dest = OUT / name
            data = get(node["url"])
            digest = hashlib.md5(data).hexdigest()
            if digest != node["md5"]:
                print(f"  بصمة لا تطابق: {name} ({digest} ≠ {node['md5']})")
                bad += 1
                continue
            if len(data) != node["size"]:
                print(f"  حجم لا يطابق: {name}")
                bad += 1
                continue
            dest.write_bytes(data)
            entry["files"][SUFFIX[m]] = {
                "file": name, "path": f"assets/textures/pbr/{name}",
                "url": node["url"], "md5": digest, "bytes": len(data),
            }
            print(f"  {name:42s} {len(data)/1048576:6.2f} MB  بصمة مطابقة")
        entry["in_use"] = True
        manifest[aid] = entry
    (OUT / "MANIFEST.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\nالبيان: {OUT/'MANIFEST.json'}  —  إخفاقات: {bad}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
