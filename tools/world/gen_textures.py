#!/usr/bin/env python3
"""خامات العالم، مولَّدة رياضياً وقابلة للتبليط تماماً.

التبليط مضمون لأن الضجيج يُبنى في مجال فورييه: كل تردد دوري على
المربع، فلا تظهر خياطة عند حواف البلاطة.
"""
import numpy as np
from PIL import Image
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
OUT = ROOT / "assets/textures/world"
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(20261114)

def fnoise(n, beta=2.0, lo_cut=0.0):
    """ضجيج دوري بطيف 1/f^beta — قابل للتبليط بالبناء."""
    w = rng.standard_normal((n, n))
    F = np.fft.fft2(w)
    fy = np.fft.fftfreq(n)[:, None]
    fx = np.fft.fftfreq(n)[None, :]
    r = np.sqrt(fx ** 2 + fy ** 2)
    r[0, 0] = 1e-6
    filt = 1.0 / (r ** beta)
    if lo_cut > 0:
        filt *= (r > lo_cut)
    filt[0, 0] = 0.0
    out = np.real(np.fft.ifft2(F * filt))
    out -= out.min()
    return out / (out.max() + 1e-9)

def octaves(n, specs):
    acc = np.zeros((n, n))
    tot = 0.0
    for beta, amp, cut in specs:
        acc += fnoise(n, beta, cut) * amp
        tot += amp
    acc /= tot
    acc -= acc.min()
    return acc / (acc.max() + 1e-9)

def to_normal(height, strength=2.4):
    gy, gx = np.gradient(height.astype(np.float32))
    nx, ny, nz = -gx * strength, -gy * strength, np.ones_like(height)
    l = np.sqrt(nx ** 2 + ny ** 2 + nz ** 2)
    rgb = np.stack([nx / l, ny / l, nz / l], -1) * 0.5 + 0.5
    return (rgb * 255).astype(np.uint8)

def save(arr, name):
    Image.fromarray(arr).save(OUT / name)
    kb = (OUT / name).stat().st_size / 1024
    print(f"{name:26s} {arr.shape[1]}x{arr.shape[0]}  {kb:7.1f} KB")

# ---------- أرض الغابة ----------
N = 512
coarse = octaves(N, [(2.6, 1.0, 0.0), (2.0, 0.55, 0.012)])
fine = octaves(N, [(1.5, 1.0, 0.03)])
grain = octaves(N, [(0.7, 1.0, 0.10)])

# تربة داكنة ← طين ← رمل خفيف، مع حبيبات
soil = np.array([44, 40, 31], np.float32)
loam = np.array([64, 58, 42], np.float32)
dust = np.array([88, 82, 62], np.float32)
t = np.clip(coarse * 1.15 - 0.08, 0, 1)[..., None]
col = soil + (loam - soil) * np.clip(t * 2, 0, 1)
col = np.where(t > 0.5, loam + (dust - loam) * ((t - 0.5) * 2), col)
col *= (0.80 + 0.40 * fine)[..., None]
col *= (0.90 + 0.20 * grain)[..., None]

# بقع طحلب خضراء متفرقة
moss_mask = np.clip((octaves(N, [(3.0, 1.0, 0.008)]) - 0.52) * 4.2, 0, 1)[..., None]
moss = np.array([38, 52, 30], np.float32) * (0.75 + 0.5 * fine)[..., None]
col = col * (1 - moss_mask) + moss * moss_mask

# حصى صغير
peb = (octaves(N, [(0.9, 1.0, 0.16)]) > 0.76)[..., None]
col = np.where(peb, col * 1.5 + 24, col)
save(np.clip(col, 0, 255).astype(np.uint8), "ground_albedo.png")
save(to_normal(coarse * 0.55 + fine * 0.35 + grain * 0.10, 3.4), "ground_normal.png")

# ---------- صخر ----------
rk = octaves(N, [(2.9, 1.0, 0.0), (1.3, 0.6, 0.04), (0.8, 0.3, 0.12)])
# طبقات صخرية متموّجة لا خطوط مستقيمة
warp = octaves(N, [(2.4, 1.0, 0.02)]) * 26.0
yy = np.arange(N)[:, None] + warp
strata = 0.5 + 0.5 * np.sin(yy * (14 * np.pi / N)) * 0.16
rock = (np.array([56, 56, 58], np.float32) * (0.62 + 0.75 * rk)[..., None]
        * (0.88 + 0.24 * strata)[..., None])
save(np.clip(rock, 0, 255).astype(np.uint8), "rock_albedo.png")
save(to_normal(rk, 4.2), "rock_normal.png")

# ---------- ماء ----------
M = 256
ripple = octaves(M, [(2.2, 1.0, 0.012), (1.1, 0.55, 0.05)])
# تمدّد باتجاه الجريان: الموجات تستطيل مع التيار
stretched = np.zeros_like(ripple)
for k in range(4):
    stretched += np.roll(ripple, k * 3, axis=0)
stretched /= 4.0
save(to_normal(stretched, 1.9), "water_normal.png")

# ---------- لحاء ----------
B = 256
vert = octaves(B, [(1.1, 1.0, 0.05)])
vert = np.repeat(vert.mean(axis=0, keepdims=True), B, 0) * 0.0 + vert
cracks = np.clip((octaves(B, [(0.9, 1.0, 0.08)]) - 0.55) * 5, 0, 1)
bark = np.array([74, 62, 50], np.float32) * (0.55 + 0.95 * vert)[..., None]
bark *= (1 - 0.55 * cracks)[..., None]
save(np.clip(bark, 0, 255).astype(np.uint8), "bark_albedo.png")
print("تمت الخامات")
