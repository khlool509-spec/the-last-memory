#!/usr/bin/env python3
"""خريطة العالم الكاملة: إغاثة + ماء + طرق + نبات + مبانٍ."""
import json, math
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

UD = Path("/root/.local/share/godot/app_userdata/THE LAST MEMORY")
prof = json.loads((UD / "profile_dump.json").read_text())
cont = json.loads((UD / "content_dump.json").read_text())
N, HALF, WATER = prof["n"], prof["half"], prof["water"]
H = np.array(prof["heights"], np.float32).reshape(N, N)
cell = (HALF * 2.0) / (N - 1)

gz, gx = np.gradient(H, cell)
slope = np.arctan(np.hypot(gx, gz))
aspect = np.arctan2(-gz, gx)
az, alt = np.radians(315.0), np.radians(45.0)
shade = np.clip(np.sin(alt)*np.cos(slope) + np.cos(alt)*np.sin(slope)*np.cos(az-aspect), 0, 1)

lo, hi = H.min(), H.max()
t = np.clip((H - lo) / max(1e-6, hi - lo), 0, 1)
base = np.stack([np.full_like(H, 30), np.full_like(H, 38), np.full_like(H, 27)], -1).astype(np.float32)
high = np.array([96, 92, 80], np.float32)
rgb = base + (high - base) * (t ** 1.4)[..., None]
rgb *= (0.46 + 0.72 * shade)[..., None]
wet = H < WATER
depth = np.clip((WATER - H) / 4.0, 0, 1)
rgb[wet] = np.stack([26+12*(1-depth), 62+42*(1-depth), 96+50*(1-depth)], -1)[wet]

SZ = 1400
img = Image.fromarray(np.clip(rgb,0,255).astype(np.uint8),"RGB").resize((SZ,SZ), Image.LANCZOS)
dr = ImageDraw.Draw(img, "RGBA")
S = SZ / (HALF*2.0)
def px(x,z): return (SZ/2 + x*S, SZ/2 + z*S)

for s in prof["road_segments"]:
    dr.line([px(s[0],s[1]), px(s[2],s[3])], fill=(188,164,116,150), width=max(2,int(s[4]*S*0.85)))

STYLE = {
 "pine":((26,74,48),2.3),"spruce":((20,62,44),2.3),"oak":((54,96,40),2.6),
 "birch":((120,150,86),2.2),"willow":((70,118,78),2.6),"dead":((126,112,92),2.0),
 "bush":((34,64,36),1.0),"fern":((40,74,42),0.7),"grass":((52,78,40),0.35),
 "rock_s":((96,96,100),0.9),"rock_l":((126,126,130),2.0),"log":((110,94,74),1.2),
 "branch":((92,80,64),0.6),"root":((70,58,46),0.7),"mushroom":((170,120,96),0.5),
}
order = ["grass","fern","branch","root","mushroom","bush","rock_s","log","rock_l",
         "dead","birch","willow","oak","spruce","pine"]
counts={}
for sp in order:
    pts = cont["species"].get(sp, [])
    counts[sp]=len(pts)
    col, r = STYLE.get(sp, ((200,200,200),1.0))
    a = 110 if sp in ("grass","fern") else 215
    for x,z,sc in pts:
        a2,b2 = px(x,z)
        rr = r * (0.7 + 0.5*min(sc/10.0,1.6)) if sp in ("pine","spruce","oak","birch","willow","dead") else r
        dr.ellipse([a2-rr,b2-rr,a2+rr,b2+rr], fill=col+(a,))

for k,(x,z,y) in cont["poi"].items():
    a,b = px(x,z)
    dr.rectangle([a-7,b-7,a+7,b+7], fill=(214,54,64), outline=(255,235,230))
    dr.text((a+11,b-7), f"{k}  {y:.1f}m", fill=(255,240,228))

dr.text((14,12), "THE LAST MEMORY — world map  400 x 400 m", fill=(238,233,222))
dr.text((14,30), f"height {lo:.1f}..{hi:.1f} m   water {WATER} m   {sum(counts.values())} instances", fill=(186,182,172))
img.save("/tmp/world_map.png")
print("map: /tmp/world_map.png")
for k in order: print(f"  {k:10s} {counts[k]:6d}")
