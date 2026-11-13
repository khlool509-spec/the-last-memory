#!/usr/bin/env python3
"""يولّد أيقونات التطبيق من الهوية اللونية المعتمدة.
تُشغَّل مرة عند تغيّر الهوية: python3 tools/gen_icons.py
"""
from PIL import Image, ImageDraw, ImageFilter
import math, pathlib

OUT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "textures" / "icon"
OUT.mkdir(parents=True, exist_ok=True)

VOID = (7, 7, 12)
NIGHT = (20, 12, 18)
BLOOD = (178, 18, 31)
EMBER = (255, 75, 58)
MOON = (207, 224, 242)


def gradient_bg(size):
    img = Image.new("RGB", (size, size), VOID)
    d = ImageDraw.Draw(img)
    for y in range(size):
        t = y / max(1, size - 1)
        c = tuple(int(VOID[i] + (NIGHT[i] - VOID[i]) * (t ** 1.4)) for i in range(3))
        d.line([(0, y), (size, y)], fill=c)
    return img


def add_moon(img, cx, cy, r):
    size = img.size[0]
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([cx - r * 3.1, cy - r * 3.1, cx + r * 3.1, cy + r * 3.1],
               fill=(MOON[0], MOON[1], MOON[2], 46))
    glow = glow.filter(ImageFilter.GaussianBlur(r * 0.85))
    img.alpha_composite(glow) if img.mode == "RGBA" else img.paste(
        Image.alpha_composite(img.convert("RGBA"), glow).convert("RGB"), (0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=MOON)
    # ظل خفيف على القمر يعطيه حجماً
    d.ellipse([cx - r * 0.62, cy - r * 0.78, cx + r * 1.05, cy + r * 0.92],
              fill=tuple(int(v * 0.93) for v in MOON))
    return img


def crack_points(cx, cy, r, size, n=11):
    """مسار شرخ مسنّن يشقّ القمر من أعلاه إلى أسفله."""
    import random
    rnd = random.Random(20261114)
    pts = []
    for i in range(n + 1):
        t = i / n
        y = cy - r * 1.22 + (r * 2.44) * t
        # انحراف يضيق عند الطرفين ويتسع في الوسط
        spread = math.sin(t * math.pi) ** 0.6
        off = (rnd.uniform(-1.0, 1.0) * 0.30 + math.sin(t * 5.4) * 0.22) * r * spread
        pts.append((cx + off, y))
    return pts


def add_cracked_moon(img, cx, cy, r):
    """قمر شاحب يشقّه صدع دموي — استعارة الذاكرة المكسورة."""
    size = img.size[0]
    base = img.convert("RGBA")

    # هالة
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse(
        [cx - r * 2.6, cy - r * 2.6, cx + r * 2.6, cy + r * 2.6],
        fill=(MOON[0], MOON[1], MOON[2], 40))
    glow = glow.filter(ImageFilter.GaussianBlur(r * 0.8))
    base = Image.alpha_composite(base, glow)

    # قرص القمر
    disc = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    dd = ImageDraw.Draw(disc)
    dd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=MOON + (255,))
    # بحار خافتة تعطي ملمساً
    for ox, oy, rr, sh in [(-0.34, -0.26, 0.20, 0.93), (0.28, 0.14, 0.26, 0.95), (-0.10, 0.42, 0.15, 0.91)]:
        c = tuple(int(v * sh) for v in MOON)
        dd.ellipse([cx + r * ox - r * rr, cy + r * oy - r * rr,
                    cx + r * ox + r * rr, cy + r * oy + r * rr], fill=c + (255,))
    base = Image.alpha_composite(base, disc)

    pts = crack_points(cx, cy, r, size)

    # قناع القرص: الصدع لا يتجاوز حدود القمر
    disc_mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(disc_mask).ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)

    gap = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(gap).line(pts, fill=(VOID[0], VOID[1], VOID[2], 255),
                             width=max(3, int(r * 0.17)), joint="curve")
    gap.putalpha(Image.composite(gap.getchannel("A"), Image.new("L", (size, size), 0), disc_mask))
    base = Image.alpha_composite(base, gap)

    hot = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(hot).line(pts, fill=EMBER + (255,),
                             width=max(2, int(r * 0.075)), joint="curve")
    hot.putalpha(Image.composite(hot.getchannel("A"), Image.new("L", (size, size), 0), disc_mask))
    blur = hot.filter(ImageFilter.GaussianBlur(r * 0.14))
    base = Image.alpha_composite(base, blur)
    base = Image.alpha_composite(base, hot)

    # قطرات تسيل أسفل الصدع
    drip = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ddr = ImageDraw.Draw(drip)
    bx = cx + (pts[-1][0] - cx) * 0.35
    by = cy + r * 0.96
    ddr.line([(bx, by), (bx + r * 0.06, by + r * 0.55)],
             fill=BLOOD + (235,), width=max(2, int(r * 0.055)))
    ddr.ellipse([bx + r * 0.02, by + r * 0.52, bx + r * 0.12, by + r * 0.64],
                fill=BLOOD + (235,))
    base = Image.alpha_composite(base, drip)
    return base


def vignette(img, strength=0.75):
    size = img.size[0]
    mask = Image.new("L", (size, size), 0)
    md = ImageDraw.Draw(mask)
    md.ellipse([-size * 0.18, -size * 0.18, size * 1.18, size * 1.18], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(size * 0.17))
    dark = Image.new("RGB", (size, size), (0, 0, 0))
    return Image.composite(img, Image.blend(img, dark, strength), mask)


def make_full(size):
    img = gradient_bg(size).convert("RGBA")
    img = add_cracked_moon(img, size * 0.5, size * 0.46, size * 0.285)
    return vignette(img.convert("RGB")).convert("RGBA")


def make_adaptive_fg(size):
    """الواجهة الأمامية للأيقونة التكيّفية: المحتوى داخل المنطقة الآمنة الوسطى."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    inner = int(size * 0.64)
    core = Image.new("RGBA", (inner, inner), (0, 0, 0, 0))
    core = add_cracked_moon(core, inner * 0.5, inner * 0.46, inner * 0.33)
    img.alpha_composite(core, (int((size - inner) / 2), int((size - inner) / 2)))
    return img


def main():
    made = []
    for name, img in [
        ("icon_192.png", make_full(192)),
        ("icon_512.png", make_full(512)),
        ("icon_bg_432.png", vignette(gradient_bg(432)).convert("RGBA")),
        ("icon_fg_432.png", make_adaptive_fg(432)),
    ]:
        path = OUT / name
        img.save(path)
        made.append((name, path.stat().st_size, img.size))
    for n, s, sz in made:
        print(f"  {n:<18} {sz[0]}x{sz[1]}  {s} بايت")


if __name__ == "__main__":
    main()
