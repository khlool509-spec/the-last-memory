#!/usr/bin/env python3
"""ينزّل نماذج 3D ممسوحة ضوئياً من Poly Haven (glTF) بتحقّق من البصمة.

حقل الارتفاع لا يُنتج جرفاً عمودياً ولا رفّاً صخرياً مطبّقاً — وهو
ما يصنع هوية المراجع. هذه نماذج فوتوغرامترية حقيقية تُوضَع فوق
التضاريس لتصنع الجيولوجيا التي يعجز الضجيج عنها.
"""
import hashlib, json, subprocess, sys
from pathlib import Path

API = "https://api.polyhaven.com"
OUT = Path("assets/models")
RES = "2k"
WANT = [
    "rock_moss_set_01",   # صخور بطحلب — مطابقة للمرجع الثالث
    "rock_moss_set_02",
    "rock_face_01",       # وجه جرف
    "rock_face_02",
    "boulder_01",         # جلمود بأشنة
    "rock_07",
    "rock_09",
]


def get(url: str) -> bytes:
    r = subprocess.run(["curl", "-sS", "--max-time", "300", url], capture_output=True)
    if r.returncode != 0:
        raise RuntimeError(f"curl فشل: {r.stderr.decode()[:160]}")
    return r.stdout


def save(dest: Path, data: bytes, node: dict, label: str) -> bool:
    d = hashlib.md5(data).hexdigest()
    if d != node.get("md5") or len(data) != node.get("size"):
        print(f"  بصمة/حجم لا يطابق: {label}")
        return False
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(data)
    return True


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    man_path = OUT / "MANIFEST.json"
    man = json.loads(man_path.read_text(encoding="utf-8")) if man_path.exists() else {}
    bad = 0
    for mid in WANT:
        info = json.loads(get(f"{API}/info/{mid}"))
        files = json.loads(get(f"{API}/files/{mid}"))
        node = files.get("gltf", {}).get(RES, {}).get("gltf")
        if node is None:
            print(f"  تعذّر: {mid} بلا gltf {RES}")
            bad += 1
            continue
        base = OUT / mid
        ok = save(base / f"{mid}.gltf", get(node["url"]), node, f"{mid}.gltf")
        total = node["size"]
        for rel, sub in node.get("include", {}).items():
            data = get(sub["url"])
            ok = save(base / rel, data, sub, rel) and ok
            total += sub["size"]
        if not ok:
            bad += 1
            continue
        man[mid] = {
            "source": f"https://polyhaven.com/a/{mid}",
            "license": "CC0 1.0",
            "license_url": "https://polyhaven.com/license",
            "authors": info.get("authors", {}),
            "categories": info.get("categories", []),
            "resolution": RES,
            "path": f"assets/models/{mid}/{mid}.gltf",
            "bytes": total,
        }
        print(f"  {mid:22s} {total/1048576:7.2f} MB  بصمات مطابقة")
    man_path.write_text(json.dumps(man, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\nالبيان: {man_path}  —  إخفاقات: {bad}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
