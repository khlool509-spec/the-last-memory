#!/usr/bin/env python3
"""يرسم خريطة إغاثة مظللة للعالم + مقاطع ارتفاع، لمعاينة الشكل بلا بطاقة رسوم."""
import json, sys, math
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

SRC = Path(sys.argv[1] if len(sys.argv) > 1 else
    "/root/.local/share/godot/app_userdata/THE LAST MEMORY/profile_dump.json")
OUT = Path(sys.argv[2] if len(sys.argv) > 2 else "/tmp/world_relief.png")

d = json.loads(SRC.read_text())
N, HALF, WATER = d["n"], d["half"], d["water"]
H = np.array(d["heights"], dtype=np.float32).reshape(N, N)      # [j=z][i=x]
RIV = np.array(d["rivers"], dtype=np.float32).reshape(N, N)
ROAD = np.array(d["roads"], dtype=np.float32).reshape(N, N)
cell = (HALF * 2.0) / (N - 1)

# ---- تظليل تلّي ----
gz, gx = np.gradient(H, cell)
slope = np.arctan(np.hypot(gx, gz))
aspect = np.arctan2(-gz, gx)
az, alt = np.radians(315.0), np.radians(42.0)
shade = (np.sin(alt) * np.cos(slope) +
         np.cos(alt) * np.sin(slope) * np.cos(az - aspect))
shade = np.clip(shade, 0, 1)

# ---- تلوين حسب الارتفاع ----
lo, hi = H.min(), H.max()
t = np.clip((H - lo) / max(1e-6, hi - lo), 0, 1)
stops = [(0.00, (36, 48, 34)), (0.30, (48, 62, 42)), (0.55, (62, 72, 50)),
         (0.78, (84, 84, 62)), (1.00, (120, 116, 104))]
rgb = np.zeros((N, N, 3), dtype=np.float32)
for k in range(len(stops) - 1):
    a_t, a_c = stops[k]; b_t, b_c = stops[k + 1]
    m = (t >= a_t) & (t <= b_t)
    f = (t[m] - a_t) / max(1e-6, b_t - a_t)
    for ch in range(3):
        rgb[..., ch][m] = a_c[ch] + (b_c[ch] - a_c[ch]) * f
rgb *= (0.42 + 0.78 * shade)[..., None]

# ---- الماء ----
wet = H < WATER
depth = np.clip((WATER - H) / 4.0, 0, 1)
water_col = np.stack([28 + 10 * (1 - depth), 58 + 40 * (1 - depth), 86 + 48 * (1 - depth)], -1)
rgb[wet] = water_col[wet]

# ---- خطوط كنتور كل مترين ----
cont = (np.abs(((H / 2.0) % 1.0) - 0.5) < 0.055) & ~wet
rgb[cont] *= 0.80

img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB").resize((1000, 1000), Image.LANCZOS)
dr = ImageDraw.Draw(img, "RGBA")
S = 1000 / (HALF * 2.0)
def px(x, z): return (500 + x * S, 500 + z * S)

for s in d["road_segments"]:
    dr.line([px(s[0], s[1]), px(s[2], s[3])], fill=(196, 170, 120, 170), width=max(1, int(s[4] * S * 0.9)))
rp = [px(p[0], p[1]) for p in d["river_points"]]
dr.line(rp, fill=(90, 170, 220, 120), width=2)

for k, (x, z, h) in d["poi"].items():
    a, b = px(x, z)
    dr.ellipse([a - 5, b - 5, a + 5, b + 5], fill=(220, 60, 70), outline=(255, 230, 230))
    dr.text((a + 8, b - 6), f"{k} {h:.1f}", fill=(255, 235, 215))

dr.text((12, 10), f"THE LAST MEMORY — relief  {int(HALF*2)}x{int(HALF*2)} m", fill=(235, 230, 220))
dr.text((12, 26), f"height {lo:.1f} .. {hi:.1f} m   water {WATER}   contours 2 m", fill=(180, 178, 170))
img.save(OUT)
print("map:", OUT)

# ---- أرقام تحكم ----
print(f"الارتفاع: {lo:.1f} .. {hi:.1f} م  (مدى {hi-lo:.1f} م)")
print(f"نسبة الماء من المساحة: {100*wet.mean():.1f}%")
deg = np.degrees(slope)
print(f"الميل: متوسط {deg.mean():.1f}°  |  وسيط {np.median(deg):.1f}°  |  أقصى {deg.max():.1f}°")
for lim in (25, 35, 45):
    print(f"  مساحة أشد من {lim}°: {100*(deg>lim).mean():.1f}%")
# هل الطرق سالكة؟ ميل الأرض على مسار الطريق
onroad = ROAD < 2.0
print(f"ميل الأرض على الطرق: متوسط {deg[onroad].mean():.1f}°  أقصى {deg[onroad].max():.1f}°")
print(f"أعلى نقطة على طريق: {H[onroad].max():.1f} م  |  أدنى: {H[onroad].min():.1f} م")
# هل النهر فعلاً تحت الماء على طوله؟
core = RIV < 3.0
print(f"محور النهر: ارتفاع من {H[core].min():.1f} إلى {H[core].max():.1f} م  (الماء عند {WATER})")
print(f"  نسبة محور النهر فوق سطح الماء (جفاف): {100*(H[core]>WATER).mean():.1f}%")
