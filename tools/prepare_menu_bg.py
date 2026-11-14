#!/usr/bin/env python3
"""يحضّر خلفية القائمة من الصورة المرجعية.

الصورة المرجعية لقطة تصميم فيها الواجهة مدمجة داخل الرسم. الواجهة
الحقيقية تُرسم برمجياً فوق الخلفية، فلو تُركت المدمجة لظهر كل شيء
مكرراً. هذا السكربت يطمس مناطق الواجهة المدمجة بضباب قوي متدرّج
الحواف — وهي نفس المناطق التي تغطيها الواجهة الحقيقية — ثم يكبّر.
"""
from PIL import Image, ImageFilter, ImageDraw
import sys, pathlib

SRC = sys.argv[1] if len(sys.argv) > 1 else "/mnt/user-data/uploads/e129af74-image.png"
DST = sys.argv[2] if len(sys.argv) > 2 else "assets/textures/ui/menu_bg.png"
OUT_W = 2560

# مناطق الواجهة المدمجة بنسب من أبعاد الصورة
REGIONS = [
    (0.000, 0.10, 0.345, 0.97),  # الشعار والعنوان الفرعي
    (0.545, 0.12, 0.845, 0.95),  # قائمة الأزرار
    (0.845, 0.00, 1.000, 1.000), # العمود الأيمن: زر الإيقاف والعصا والحدّ
]

# قصّ الحواف: الصورة المرجعية فيها إطار أسود رفيع وحدّ عمودي يمين
CROP = (0.004, 0.012, 0.996, 0.988)


def clean(img: Image.Image) -> Image.Image:
    """يطمس الواجهة المدمجة بضباب ثم تعتيم عميق.

    الضباب وحده يحوّل الشعار الأحمر إلى لطخة. التعتيم العميق يحوّله إلى
    ظل — وهو مقبول بصرياً في مشهد ليلي، والواجهة الحقيقية تُرسم فوقه.
    """
    from PIL import ImageEnhance
    w, h = img.size
    base = img.convert("RGB")
    treated = base.filter(ImageFilter.GaussianBlur(radius=max(7, w * 0.020)))
    treated = ImageEnhance.Color(treated).enhance(0.25)      # إزالة التشبّع
    treated = ImageEnhance.Brightness(treated).enhance(0.30)  # تعتيم عميق
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    for x0, y0, x1, y1 in REGIONS:
        d.rectangle([x0 * w, y0 * h, x1 * w, y1 * h], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(radius=max(7, w * 0.020)))
    return Image.composite(treated, base, mask)


def main():
    img = Image.open(SRC)
    w, h = img.size
    img = img.crop((int(CROP[0] * w), int(CROP[1] * h),
                    int(CROP[2] * w), int(CROP[3] * h)))
    cleaned = clean(img)
    scale = OUT_W / cleaned.width
    out_h = int(round(cleaned.height * scale))
    big = cleaned.resize((OUT_W, out_h), Image.LANCZOS)
    big = big.filter(ImageFilter.UnsharpMask(radius=2.4, percent=55, threshold=3))
    dst = pathlib.Path(DST)
    dst.parent.mkdir(parents=True, exist_ok=True)
    big.save(dst)
    print(f"الأصل   : {img.size[0]}x{img.size[1]}")
    print(f"الناتج  : {big.size[0]}x{big.size[1]}  ({dst})")
    print(f"الحجم   : {dst.stat().st_size} بايت")


if __name__ == "__main__":
    main()
