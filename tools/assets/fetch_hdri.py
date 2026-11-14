#!/usr/bin/env python3
"""ينزّل HDRI من Poly Haven بتحقّق من البصمة.

سماء HDRI تعطي ثلاثة أشياء معاً: خلفية مصوّرة، وإضاءة محيطة
فيزيائية صحيحة عبر خريطة الإشعاع، وانعكاسات. وهو أقرب ما يمكن
بلوغه من إضاءة عامّة حقيقية بلا خبز.
"""
import hashlib, json, subprocess, sys
from pathlib import Path

API = "https://api.polyhaven.com"
OUT = Path("assets/hdri")
WANT = {
    "nature_reserve_forest": "2k",          # إضاءة غابة — غير صالحة خلفيةً
    "sunset_forest": "2k",
    "kloofendal_48d_partly_cloudy_puresky": "2k",
    "kloofendal_overcast_puresky": "2k",
    "overcast_soil_puresky": "2k",
}


def get(url: str) -> bytes:
    r = subprocess.run(["curl", "-sS", "--max-time", "240", url], capture_output=True)
    if r.returncode != 0:
        raise RuntimeError(f"curl فشل: {r.stderr.decode()[:200]}")
    return r.stdout


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    man_path = OUT / "MANIFEST.json"
    man = json.loads(man_path.read_text(encoding="utf-8")) if man_path.exists() else {}
    bad = 0
    for hid, res in WANT.items():
        info = json.loads(get(f"{API}/info/{hid}"))
        files = json.loads(get(f"{API}/files/{hid}"))
        node = files.get("hdri", {}).get(res, {}).get("hdr")
        if node is None:
            print(f"  تعذّر: {hid} بلا hdr {res}")
            bad += 1
            continue
        name = f"{hid}_{res}.hdr"
        data = get(node["url"])
        digest = hashlib.md5(data).hexdigest()
        if digest != node["md5"] or len(data) != node["size"]:
            print(f"  بصمة/حجم لا يطابق: {name}")
            bad += 1
            continue
        (OUT / name).write_bytes(data)
        man[hid] = {
            "source": f"https://polyhaven.com/a/{hid}",
            "license": "CC0 1.0",
            "license_url": "https://polyhaven.com/license",
            "authors": info.get("authors", {}),
            "max_resolution": info.get("max_resolution"),
            "whitebalance": info.get("whitebalance"),
            "file": name, "path": f"assets/hdri/{name}",
            "url": node["url"], "md5": digest, "bytes": len(data),
        }
        print(f"  {name:36s} {len(data)/1048576:6.2f} MB  بصمة مطابقة")
    man_path.write_text(json.dumps(man, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\nالبيان: {man_path}  —  إخفاقات: {bad}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
