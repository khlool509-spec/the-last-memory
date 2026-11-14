#!/usr/bin/env python3
"""معاينة شيدر الأجواء: إعادة تنفيذ رياضياته في numpy لرؤية التركيب
قبل الشحن. بيئة البناء بلا بطاقة رسوم، فهذه الطريقة الوحيدة للتحقق
من التأليف البصري دون جهاز.
الناتج ليس مطابقاً بالبكسل لكنه مطابق في البنية والمواضع والنسب.
"""
import numpy as np
from PIL import Image
import sys, pathlib

W, H = 1280, 592          # نسبة 2.16 قريبة من S22 Ultra أفقياً
ASPECT = W / H
TIME = 3.0

sky_high = np.array([0.035, 0.043, 0.075])
sky_low = np.array([0.094, 0.063, 0.078])
moon_tint = np.array([0.878, 0.918, 0.973])
blood = np.array([0.698, 0.071, 0.122])
window_lit = np.array([1.0, 0.584, 0.231])
MOON_POS = (0.30, 0.24)
MOON_SIZE = 0.062
FOG = 0.55
RAIN = 0.40
BLOOD_GLOW = 0.18
VIGN = 1.25
WIND = 0.012


def fract(x): return x - np.floor(x)


def hash2(x, y):
    return fract(np.sin(x * 127.1 + y * 311.7) * 43758.5453)


def hash1(x):
    return fract(np.sin(x * 91.3458) * 47453.5453)


def noise(px, py):
    ix, iy = np.floor(px), np.floor(py)
    fx, fy = px - ix, py - iy
    ux = fx * fx * (3 - 2 * fx)
    uy = fy * fy * (3 - 2 * fy)
    a = hash2(ix, iy); b = hash2(ix + 1, iy)
    c = hash2(ix, iy + 1); d = hash2(ix + 1, iy + 1)
    return (a + (b - a) * ux) + ((c - a) + (a - b - c + d) * ux) * uy


def fbm(px, py, oct=5):
    v = np.zeros_like(px); a = 0.5
    for _ in range(oct):
        v += a * noise(px, py)
        px, py, a = px * 2.07, py * 2.07, a * 0.5
    return v


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0 + 1e-9), 0, 1)
    return t * t * (3 - 2 * t)


def treeline(ux, uy, density, height, base, seed, shift):
    """صنوبر ضيّق مدبّب بجذع — لا مثلثات عريضة تشبه الجبال."""
    x = (ux + shift) * density
    cell = np.floor(x); t = fract(x)
    h = base + height * (0.55 + 0.45 * hash1(cell + seed))
    # تاج مدبّب: الأس العالي يجعل الجوانب شبه رأسية
    crown = h * np.power(np.clip(1.0 - np.abs(t - 0.5) * 2.0, 0, None), 0.30)
    crown += 0.006 * noise(x * 14.0, np.full_like(x, seed))
    trunk = (np.abs(t - 0.5) < 0.035).astype(float) * base * 0.9
    return np.maximum((uy <= crown).astype(float), (uy <= trunk).astype(float))


MX, BASE, TOP, HW = 0.625, 0.135, 0.40, 0.078


def mansion(ux, uy):
    """قصر يعلو خط الأشجار: جسم وسقف مثلث وبرج، بنوافذ داخل الجسم فقط."""
    px = ux - MX
    body = (np.abs(px) <= HW) & (uy >= BASE) & (uy <= TOP)
    roof_h = 0.085
    roof = (np.abs(px) <= np.clip(HW * (1 - (uy - TOP) / roof_h), 0, None)) & (uy > TOP) & (uy <= TOP + roof_h)
    tw, tx = 0.026, HW * 0.72
    tower = (np.abs(px - tx) <= tw) & (uy >= BASE) & (uy <= TOP + 0.10)
    spire = (np.abs(px - tx) <= np.clip(tw * (1 - (uy - TOP - 0.10) / 0.06), 0, None)) & (uy > TOP + 0.10) & (uy <= TOP + 0.16)
    m = (body | roof | tower | spire).astype(float)
    # شبكة نوافذ داخل الجسم فقط
    gx = (px + HW) / (2 * HW) * 5.0
    gy = (uy - BASE) / (TOP - BASE) * 4.0
    gix, giy = np.floor(gx), np.floor(gy)
    gfx, gfy = fract(gx), fract(gy)
    cell = ((gfx >= 0.30) & (gfx <= 0.70) & (gfy >= 0.25) & (gfy <= 0.72))
    lit = (hash2(gix + 3.7, giy + 1.3) >= 0.42)
    win = (body & cell & lit).astype(float)
    return m, win


def rain_layer(ux, uy, t):
    """خطوط مطر مائلة ممتدة لا نقاط."""
    px = ux * 210.0 + uy * 26.0
    py = uy * 9.0 - t * 5.2
    col = np.floor(px)
    seed = hash1(col)
    f = fract(py + seed)
    active = (fract(seed * 7.3) >= 0.90).astype(float)
    across = 1.0 - smoothstep(0.0, 0.55, np.abs(fract(px) - 0.5) * 2.0)
    streak = np.power(np.clip(1.0 - f, 0, None), 2.2)
    return active * across * streak


def stars(ux, uy):
    """نقاط دائرية ناعمة لا مربعات: المسافة من مركز الخلية تحدد السطوع."""
    gx, gy = ux * 170.0, uy * 80.0
    ix, iy = np.floor(gx), np.floor(gy)
    r = hash2(ix, iy)
    on = (r >= 0.990).astype(float)
    cx = 0.25 + 0.5 * hash1(ix * 1.7 + iy)
    cy = 0.25 + 0.5 * hash1(iy * 2.3 + ix)
    d = np.sqrt((fract(gx) - cx) ** 2 + (fract(gy) - cy) ** 2)
    point = np.power(np.clip(1.0 - d / 0.28, 0, None), 2.5)
    twinkle = 0.55 + 0.45 * hash1(ix + iy * 3.1)
    return on * point * twinkle * smoothstep(0.26, 0.9, uy)


def render(t=TIME):
    xs = (np.arange(W) + 0.5) / W
    ys = (np.arange(H) + 0.5) / H
    U, V = np.meshgrid(xs, ys)
    ux, uy = U, 1.0 - V

    col = sky_low[None, None, :] + (sky_high - sky_low)[None, None, :] * smoothstep(0, 1, uy)[..., None]

    dx = (ux - MOON_POS[0]) * ASPECT
    dy = uy - (1.0 - MOON_POS[1])
    dist = np.sqrt(dx * dx + dy * dy)
    cloud = fbm(ux * 2.4 + t * WIND, uy * 1.6)
    occl = 1 - smoothstep(0.42, 0.72, cloud) * 0.55
    col += moon_tint * (smoothstep(MOON_SIZE, MOON_SIZE * 0.80, dist) * 0.95 * occl)[..., None]
    col += moon_tint * (np.power(np.clip(1 - dist / (MOON_SIZE * 9.0), 0, None), 2.6) * 0.30 * occl)[..., None]

    col += np.array([0.85, 0.90, 1.0]) * (stars(ux, uy) * 0.55 * occl)[..., None]
    cl = smoothstep(0.40, 0.78, cloud) * smoothstep(0.25, 0.95, uy)
    col = col + (np.array([0.055, 0.058, 0.075]) * (cl * 0.85)[..., None])

    m, win = mansion(ux, uy)
    col = col * (1 - (m * 0.96)[..., None]) + np.array([0.022, 0.024, 0.034]) * (m * 0.96)[..., None]
    flick = 0.82 + 0.18 * noise(np.full_like(ux, t * 1.6), np.zeros_like(ux))
    col += window_lit * (win * 0.85 * flick)[..., None]
    col += window_lit * (m * 0.05)[..., None]

    for shift, dens, hgt, base, seed, tint, amt in [
        (t * WIND * 0.15, 46.0, 0.085, 0.105, 1.0, [0.040, 0.043, 0.058], 0.82),
        (-t * WIND * 0.25, 27.0, 0.135, 0.085, 7.0, [0.023, 0.024, 0.035], 0.91),
        (t * WIND * 0.40, 16.0, 0.215, 0.060, 13.0, [0.007, 0.007, 0.013], 0.98),
    ]:
        tl = treeline(ux, uy, dens, hgt, base, seed, shift) * amt
        col = col * (1 - tl[..., None]) + np.array(tint) * tl[..., None]

    gf = smoothstep(0.42, 0.0, uy) * (0.45 + 0.55 * fbm(ux * 3.4 + t * 0.02, uy * 5.0))
    gf = gf * FOG
    col = col * (1 - gf[..., None]) + np.array([0.105, 0.115, 0.140]) * gf[..., None]

    col += blood * (smoothstep(0.35, 0.0, uy) * BLOOD_GLOW)[..., None]
    col += np.array([0.62, 0.68, 0.80]) * (rain_layer(ux, uy, t) * RAIN * 0.55)[..., None]

    vx, vy = U - 0.5, V - 0.5
    col *= np.clip(1 - (vx * vx + vy * vy) * VIGN, 0, 1)[..., None]

    return Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8))


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/shader_preview.png"
    render().save(out)
    print("المعاينة:", out)
