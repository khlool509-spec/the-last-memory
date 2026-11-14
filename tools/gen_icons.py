#!/usr/bin/env python3
"""يولّد أيقونات التطبيق من الصورة الفنية المعتمدة للعبة.

لا رسم مخترع: الأيقونة قصاصة من نفس الفن الذي تظهره القائمة، فتتطابق
هوية الأيقونة مع هوية اللعبة تماماً.
"""
from PIL import Image, ImageFilter, ImageEnhance, ImageDraw
import pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "assets/textures/ui/menu_bg.png"
OUT = ROOT / "assets/textures/icon"
OUT.mkdir(parents=True, exist_ok=True)

# منطقة القصّ: القصر والقمر — أوضح عنصرين يُقرآن في مربع صغير
CROP = (0.345, 0.00, 0.625, 0.62)


def square_art(size: int) -> Image.Image:
    src = Image.open(SRC).convert("RGB")
    w, h = src.size
    box = (int(CROP[0] * w), int(CROP[1] * h), int(CROP[2] * w), int(CROP[3] * h))
    art = src.crop(box)
    # قصّ مربع من المركز
    s = min(art.size)
    cx, cy = art.width // 2, art.height // 2
    art = art.crop((cx - s // 2, cy - s // 2, cx + s // 2, cy + s // 2))
    art = art.resize((size, size), Image.LANCZOS)
    art = ImageEnhance.Contrast(art).enhance(1.18)
    art = ImageEnhance.Color(art).enhance(1.12)
    art = art.filter(ImageFilter.UnsharpMask(radius=size / 160.0, percent=70, threshold=2))
    return art


def vignette(img: Image.Image, strength: float = 0.55) -> Image.Image:
    size = img.size[0]
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse(
        [-size * 0.14, -size * 0.14, size * 1.14, size * 1.14], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(size * 0.15))
    dark = Image.new("RGB", (size, size), (0, 0, 0))
    return Image.composite(img, Image.blend(img, dark, strength), mask)


def accent(img: Image.Image) -> Image.Image:
    """خط أحمر رفيع أسفل الأيقونة: لمسة الهوية الدموية."""
    size = img.size[0]
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rectangle([0, int(size * 0.945), size, int(size * 0.975)], fill=(178, 18, 31, 235))
    glow = layer.filter(ImageFilter.GaussianBlur(size * 0.02))
    out = Image.alpha_composite(img.convert("RGBA"), glow)
    return Image.alpha_composite(out, layer)


def make_full(size: int) -> Image.Image:
    return accent(vignette(square_art(size)))


def make_adaptive_fg(size: int) -> Image.Image:
    """المنطقة الآمنة للأيقونة التكيّفية: المحتوى في الوسط فقط."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    inner = int(size * 0.66)
    core = make_full(inner).convert("RGBA")
    mask = Image.new("L", (inner, inner), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, inner - 1, inner - 1], radius=int(inner * 0.16), fill=255)
    core.putalpha(mask)
    img.alpha_composite(core, ((size - inner) // 2, (size - inner) // 2))
    return img


def make_adaptive_bg(size: int) -> Image.Image:
    base = square_art(size).filter(ImageFilter.GaussianBlur(size * 0.07))
    base = ImageEnhance.Brightness(base).enhance(0.55)
    return base.convert("RGBA")


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"المصدر غير موجود: {SRC}")
    for name, img in [
        ("icon_192.png", make_full(192)),
        ("icon_512.png", make_full(512)),
        ("icon_bg_432.png", make_adaptive_bg(432)),
        ("icon_fg_432.png", make_adaptive_fg(432)),
    ]:
        p = OUT / name
        img.save(p)
        print(f"  {name:<18} {img.size[0]}x{img.size[1]}  {p.stat().st_size} بايت")


if __name__ == "__main__":
    main()
