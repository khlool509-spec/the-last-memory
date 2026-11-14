#!/usr/bin/env python3
"""خامات العالم — الجيل الثاني.

الفرق عن الأول: تباين أعلى، خرائط خشونة وانسداد، وبطاقات أوراق وعشب
بقناة شفافية — وهي ما يحوّل الشجرة من مخروط صلب إلى شجرة.
كلها دورية في مجال فورييه فالتبليط بلا خياطة.
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
OUT = ROOT / "assets/textures/world"
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(20261114)

def fnoise(n, beta=2.0, lo_cut=0.0, seed=None):
    r = np.random.default_rng(seed) if seed is not None else rng
    F = np.fft.fft2(r.standard_normal((n, n)))
    fy = np.fft.fftfreq(n)[:, None]; fx = np.fft.fftfreq(n)[None, :]
    rad = np.sqrt(fx**2 + fy**2); rad[0, 0] = 1e-6
    filt = 1.0 / (rad ** beta)
    if lo_cut > 0: filt *= (rad > lo_cut)
    filt[0, 0] = 0.0
    o = np.real(np.fft.ifft2(F * filt)); o -= o.min()
    return o / (o.max() + 1e-9)

def oct(n, specs, seed=None):
    acc = np.zeros((n, n)); tot = 0.0
    for i, (b, a, c) in enumerate(specs):
        acc += fnoise(n, b, c, None if seed is None else seed + i) * a; tot += a
    acc /= tot; acc -= acc.min()
    return acc / (acc.max() + 1e-9)

def to_normal(h, s=3.0):
    gy, gx = np.gradient(h.astype(np.float32))
    nx, ny, nz = -gx * s, -gy * s, np.ones_like(h)
    l = np.sqrt(nx*nx + ny*ny + nz*nz)
    return ((np.stack([nx/l, ny/l, nz/l], -1) * 0.5 + 0.5) * 255).astype(np.uint8)

def save(a, name, mode="RGB"):
    Image.fromarray(a, mode).save(OUT / name)
    print(f"  {name:24s} {a.shape[1]}x{a.shape[0]}  {(OUT/name).stat().st_size/1024:7.1f} KB")

N = 512
print("أرض الغابة:")
macro = oct(N, [(2.8, 1.0, 0.0), (2.0, 0.6, 0.010)], seed=10)
mid   = oct(N, [(1.6, 1.0, 0.030)], seed=20)
fine  = oct(N, [(0.8, 1.0, 0.090)], seed=30)

soil = np.array([38, 32, 24], np.float32)
loam = np.array([74, 62, 42], np.float32)
dust = np.array([118, 104, 74], np.float32)
t = np.clip(macro * 1.25 - 0.12, 0, 1)[..., None]
col = soil + (loam - soil) * np.clip(t * 2, 0, 1)
col = np.where(t > 0.5, loam + (dust - loam) * ((t - 0.5) * 2), col)
col *= (0.62 + 0.76 * mid)[..., None]

# بقع عشب وطحلب: تباين لوني حقيقي لا تدرّج واحد
gm = np.clip((oct(N, [(3.2, 1.0, 0.006)], seed=40) - 0.47) * 4.0, 0, 1)[..., None]
grass_c = np.array([52, 74, 34], np.float32) * (0.70 + 0.62 * mid)[..., None]
col = col * (1 - gm) + grass_c * gm

# أوراق ساقطة
lm = np.clip((oct(N, [(1.2, 1.0, 0.055)], seed=50) - 0.62) * 5.0, 0, 1)[..., None]
leaf_c = np.array([104, 72, 38], np.float32)
col = col * (1 - lm) + leaf_c * lm

# حصى: نقاط فاتحة حادة ترفع التباين القريب
peb = (oct(N, [(0.75, 1.0, 0.15)], seed=60) > 0.74)
col[peb] = np.clip(col[peb] * 1.75 + 26, 0, 255)
col *= (0.88 + 0.24 * fine)[..., None]
save(np.clip(col, 0, 255).astype(np.uint8), "ground_albedo.png")

hgt = macro * 0.5 + mid * 0.32 + fine * 0.18
save(to_normal(hgt, 4.0), "ground_normal.png")
# خشونة: الحصى أملس والتراب خشن
rough = np.clip(0.94 - peb.astype(np.float32) * 0.34 - gm[..., 0] * 0.10, 0.25, 1.0)
ao = np.clip(0.55 + 0.52 * hgt, 0, 1)
save((np.stack([rough, rough, rough], -1) * 255).astype(np.uint8), "ground_rough.png")
save((np.stack([ao, ao, ao], -1) * 255).astype(np.uint8), "ground_ao.png")

print("لحاء:")
B = 512
vert_n = oct(B, [(1.05, 1.0, 0.025)], seed=70)
# تمدّد رأسي: اللحاء خطوط طولية لا بقع
stretched = np.zeros_like(vert_n)
for k in range(9):
    stretched += np.roll(vert_n, k * 4, axis=0)
stretched /= 9.0
stretched = (stretched - stretched.min()) / (np.ptp(stretched) + 1e-9)
cracks = np.clip((oct(B, [(0.85, 1.0, 0.05)], seed=80) - 0.52) * 4.5, 0, 1)
crk = np.zeros_like(cracks)
for k in range(7):
    crk += np.roll(cracks, k * 3, axis=0)
crk = np.clip(crk / 7.0 * 2.2, 0, 1)
bark = np.array([86, 68, 50], np.float32) * (0.48 + 1.05 * stretched)[..., None]
bark *= (1 - 0.62 * crk)[..., None]
save(np.clip(bark, 0, 255).astype(np.uint8), "bark_albedo.png")
save(to_normal(stretched * 0.6 + (1 - crk) * 0.4, 5.0), "bark_normal.png")

print("صخر:")
rk = oct(N, [(2.9, 1.0, 0.0), (1.25, 0.65, 0.035), (0.75, 0.35, 0.11)], seed=90)
warp = oct(N, [(2.4, 1.0, 0.02)], seed=95) * 30.0
yy = np.arange(N)[:, None] + warp
strata = 0.5 + 0.5 * np.sin(yy * (11 * np.pi / N)) * 0.20
rock = np.array([104, 102, 98], np.float32) * (0.42 + 0.92 * rk)[..., None] * (0.86 + 0.28 * strata)[..., None]
save(np.clip(rock, 0, 255).astype(np.uint8), "rock_albedo.png")
save(to_normal(rk, 5.5), "rock_normal.png")

print("بطاقات شفافة:")
def leaf_broad(size=512):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = np.random.default_rng(777)
    for _ in range(165):
        cx, cy = r.uniform(0.02, 0.92) * size, r.uniform(0.1, 0.9) * size
        L = r.uniform(0.10, 0.22) * size
        W = L * r.uniform(0.42, 0.62)
        ang = r.uniform(0, 360)
        g = int(r.uniform(86, 150)); rr = int(g * r.uniform(0.45, 0.78)); bb = int(g * r.uniform(0.26, 0.46))
        leaf = Image.new("RGBA", (int(L), int(W)), (0, 0, 0, 0))
        ld = ImageDraw.Draw(leaf)
        ld.ellipse([0, 0, int(L) - 1, int(W) - 1], fill=(rr, g, bb, 255))
        ld.line([(2, int(W/2)), (int(L) - 3, int(W/2))], fill=(int(rr*0.7), int(g*0.72), int(bb*0.7), 255), width=1)
        img.alpha_composite(leaf.rotate(ang, expand=True), (int(cx), int(cy)))
    return img

def leaf_needle(size=512):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = np.random.default_rng(888)
    for _ in range(70):
        bx, by = r.uniform(0.02, 0.98) * size, r.uniform(0.05, 0.95) * size
        ax = r.uniform(0, 2 * np.pi)
        L = r.uniform(0.13, 0.26) * size
        ex, ey = bx + np.cos(ax) * L, by + np.sin(ax) * L
        g = int(r.uniform(60, 120))
        d.line([(bx, by), (ex, ey)], fill=(int(g*0.42), g, int(g*0.5), 255), width=2)
        for k in range(26):
            tt = k / 26.0
            px, py = bx + (ex - bx) * tt, by + (ey - by) * tt
            nl = r.uniform(0.030, 0.062) * size
            for s in (-1, 1):
                na = ax + s * r.uniform(0.9, 1.3)
                gg = int(g * r.uniform(0.75, 1.15))
                d.line([(px, py), (px + np.cos(na) * nl, py + np.sin(na) * nl)],
                       fill=(int(gg*0.40), min(gg, 255), int(gg*0.48), 255), width=1)
    return img

def grass_card(size=512):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = np.random.default_rng(999)
    for _ in range(118):
        bx = r.uniform(0.01, 0.99) * size
        h = r.uniform(0.45, 0.95) * size
        lean = r.uniform(-0.26, 0.26) * size
        w = r.uniform(3.0, 6.5)
        base = int(r.uniform(44, 80)); tip = int(r.uniform(104, 168))
        steps = 16
        for k in range(steps):
            t0, t1 = k / steps, (k + 1) / steps
            y0, y1 = size - t0 * h, size - t1 * h
            x0, x1 = bx + lean * t0 * t0, bx + lean * t1 * t1
            cv = int(base + (tip - base) * t1)
            d.line([(x0, y0), (x1, y1)],
                   fill=(int(cv * 0.80), cv, int(cv * 0.38), 255),
                   width=max(1, int(w * (1 - t1 * 0.82))))
    return img

for fn, name in [(leaf_broad, "leaf_broad.png"), (leaf_needle, "leaf_needle.png"), (grass_card, "grass_card.png")]:
    im = fn()
    im = im.filter(ImageFilter.GaussianBlur(0.6))
    a = np.array(im)
    save(a, name, "RGBA")
    print(f"      تغطية الشفافية: {100*(a[...,3]>40).mean():.1f}%")
print("تمت خامات الجيل الثاني")
