#!/usr/bin/env python3
"""يرسم مخططاً علوياً للفصل الأول من بيانات dump_level.gd للتحقق البصري."""
import json, sys
from pathlib import Path
from PIL import Image, ImageDraw

SRC = Path(sys.argv[1] if len(sys.argv) > 1 else
    "/root/.local/share/godot/app_userdata/THE LAST MEMORY/level_dump.json")
OUT = Path(sys.argv[2] if len(sys.argv) > 2 else "/tmp/level_map.png")

d = json.loads(SRC.read_text())
W = H = 1100
SCALE = 7.0          # بكسل لكل متر
CX, CY = W // 2, H // 2 - 60

def px(x, z):
    return (CX + x * SCALE, CY + z * SCALE)

img = Image.new("RGB", (W, H), (10, 11, 16))
dr = ImageDraw.Draw(img)

# شبكة كل 10 أمتار
for m in range(-70, 71, 10):
    a = px(m, -70); b = px(m, 70)
    dr.line([a, b], fill=(24, 26, 34), width=1)
    a = px(-70, m); b = px(70, m)
    dr.line([a, b], fill=(24, 26, 34), width=1)

# الممر
pts = [px(x, z) for x, z in d["path"]]
dr.line(pts, fill=(70, 62, 48), width=int(3.2 * SCALE))
dr.line(pts, fill=(120, 106, 80), width=3)

def dot(x, z, r, col, outline=None):
    a, b = px(x, z)
    dr.ellipse([a - r, b - r, a + r, b + r], fill=col, outline=outline)

for x, z in d.get("field", []):
    dot(x, z, 4, (16, 34, 25))
for x, z in d["trees"]:
    dot(x, z, 7, (28, 62, 42), (60, 120, 80))
for x, z in d["rocks"]:
    dot(x, z, 4, (52, 54, 62))
for x, z in d["walls"]:
    a, b = px(x, z)
    dr.rectangle([a - 3 * SCALE, b - 0.6 * SCALE, a + 3 * SCALE, b + 0.6 * SCALE],
                 fill=(60, 62, 72))
for x, z in d["gate"]:
    a, b = px(x, z)
    dr.rectangle([a - 3.6 * SCALE, b - SCALE, a + 3.6 * SCALE, b + SCALE],
                 outline=(200, 30, 45), width=3)
    dr.text((a - 18, b - 26), "GATE", fill=(220, 60, 70))
for x, z in d["lanterns"]:
    dot(x, z, 9, (255, 176, 90), (255, 220, 160))
for x, z, nm in d["items"]:
    dot(x, z, 7, (120, 200, 255), (220, 240, 255))
    dr.text(px(x + 1.0, z - 0.6), nm.replace("Pickup_", "").replace("Note", "N:"),
            fill=(150, 200, 240))
for x, z in d["player"]:
    a, b = px(x, z)
    dr.ellipse([a - 8, b - 8, a + 8, b + 8], fill=(230, 40, 55))
    dr.text((a + 12, b - 6), "START", fill=(240, 90, 100))

dr.text((16, 16), "THE LAST MEMORY — Chapter 1 top-down (1 cell = 10 m)", fill=(190, 185, 175))
dr.text((16, 36), "dark green=forest  bright green=solid trees  grey=rocks  orange=lanterns  blue=interactables", fill=(120, 118, 112))
img.save(OUT)
print("map:", OUT, img.size)

# تحقق عددي: لا شجرة على الممر
import math
def seg_dist(p, a, b):
    ax, az = a; bx, bz = b; px_, pz = p
    dx, dz = bx - ax, bz - az
    L = dx * dx + dz * dz
    t = 0 if L == 0 else max(0, min(1, ((px_ - ax) * dx + (pz - az) * dz) / L))
    return math.hypot(px_ - (ax + t * dx), pz - (az + t * dz))

path = d["path"]
worst = 99
bad = 0
for x, z in d["trees"] + d.get("field", []):
    dmin = min(seg_dist((x, z), path[i], path[i + 1]) for i in range(len(path) - 1))
    worst = min(worst, dmin)
    if dmin < 2.6:
        bad += 1
print(f"أقرب شجرة إلى الممر: {worst:.2f} م  |  أشجار تسدّ الممر (<2.6م): {bad}")

lan = [min(seg_dist((x, z), path[i], path[i+1]) for i in range(len(path)-1))
       for x, z in d["lanterns"]]
print("مسافة الفوانيس عن الممر:", " ".join(f"{v:.1f}" for v in lan))
items = [(nm, min(seg_dist((x, z), path[i], path[i+1]) for i in range(len(path)-1)))
         for x, z, nm in d["items"]]
for nm, v in items:
    print(f"  {nm:22s} {v:5.1f} م عن الممر")
