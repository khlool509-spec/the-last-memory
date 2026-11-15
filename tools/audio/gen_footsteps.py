#!/usr/bin/env python3
"""توليد أصوات خطوات واقعية.

الخطوة الحقيقية ليست نبرة بل حدث فيزيائي من ثلاث طبقات متراكبة:

  ١. الصدمة  — دفعة عريضة الطيف طولها 4-10 مللي ثانية: لحظة ملامسة
                 الكعب للأرض. هي ما يجعل الصوت «ضربة» لا «نفخة».
  ٢. الجسم   — ضجيج مرشَّح يتلاشى أسّياً خلال 60-160 مللي. نطاقه
                 التردّدي هو ما يميّز العشب عن الحجر عن الخشب.
  ٣. الاحتكاك — ذيل عالي التردّد: حفيف العشب أو رشّ الماء. يغيب على
                 الحجر لأن الحذاء لا يجرف شيئاً.

ما كان يجعل الأصوات القديمة مزعجة: ذروة عند 49% من المدى وغلاف بلا
صدمة حادّة، فتُسمع كطنين متواصل لا كوقع قدم. وكلّها بنفس البذرة
فتتكرّر مطابقة — والأذن تكشف التكرار الآلي فوراً.
"""

import array
import math
import random
import struct
import wave

SR = 22050


def one_pole_lp(x, cutoff, sr=SR):
    """مرشّح تمرير منخفض بقطب واحد — يكفي لتشكيل نطاق الضجيج."""
    a = math.exp(-2.0 * math.pi * cutoff / sr)
    y, prev = [], 0.0
    for s in x:
        prev = (1.0 - a) * s + a * prev
        y.append(prev)
    return y


def one_pole_hp(x, cutoff, sr=SR):
    lp = one_pole_lp(x, cutoff, sr)
    return [s - l for s, l in zip(x, lp)]


def noise(n, rng):
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def env_exp(n, attack_ms, decay_ms, sr=SR):
    """غلاف بهجوم سريع وتلاشٍ أسّي — شكل كل صوت صدمة في الطبيعة."""
    at = max(1, int(sr * attack_ms / 1000.0))
    out = []
    for i in range(n):
        if i < at:
            a = i / at
        else:
            a = math.exp(-4.0 * (i - at) / (sr * decay_ms / 1000.0))
        out.append(a)
    return out


def thump(n, freq, decay_ms, rng, sr=SR):
    """ضربة منخفضة: جيب يتلاشى بسرعة. وزن الجسم على الأرض."""
    out = []
    ph = rng.uniform(0, math.tau)
    for i in range(n):
        a = math.exp(-5.0 * i / (sr * decay_ms / 1000.0))
        out.append(math.sin(ph + math.tau * freq * i / sr) * a)
    return out


SURFACES = {
    # قطع منخفض، قطع عالٍ، مدّة، تردّد الضربة، قوّة الاحتكاك
    "grass": {"lo": 5200, "hi": 320, "ms": 150, "thump": 92, "scuff": 0.55,
              "thump_amp": 0.30},
    "stone": {"lo": 8500, "hi": 900, "ms": 95,  "thump": 118, "scuff": 0.10,
              "thump_amp": 0.42},
    "wood":  {"lo": 4200, "hi": 180, "ms": 135, "thump": 165, "scuff": 0.22,
              "thump_amp": 0.50},
    "water": {"lo": 7000, "hi": 420, "ms": 230, "thump": 70,  "scuff": 0.85,
              "thump_amp": 0.22},
}

PEAK = 0.34       # ذروة معتدلة: الخطوة حدث خلفي لا حدث رئيسي


def make_step(surface, seed):
    sp = SURFACES[surface]
    rng = random.Random(seed)
    n = int(SR * sp["ms"] / 1000.0)

    # تذبذب طفيف في كل نسخة: خطوتان متطابقتان تماماً تفضحان الآلة
    lo = sp["lo"] * rng.uniform(0.86, 1.16)
    ms = sp["ms"] * rng.uniform(0.90, 1.12)

    body = one_pole_lp(noise(n, rng), lo)
    body = one_pole_hp(body, sp["hi"])
    e = env_exp(n, 1.5, ms * 0.55)
    body = [b * a for b, a in zip(body, e)]

    # الصدمة: دفعة قصيرة جداً تعطي الحافّة التي تُسمع كـ«وقع»
    imp_n = int(SR * 0.008)
    imp = one_pole_hp(noise(imp_n, rng), 1800)
    ie = env_exp(imp_n, 0.4, 5.0)
    imp = [v * a * 0.85 for v, a in zip(imp, ie)]

    th = thump(n, sp["thump"] * rng.uniform(0.9, 1.1), ms * 0.42, rng)

    # الاحتكاك: ذيل عالٍ متأخّر قليلاً — الحذاء يجرف السطح بعد الوقع
    scuff = one_pole_hp(noise(n, rng), 3200)
    se = env_exp(n, 18.0, ms * 0.85)
    scuff = [v * a for v, a in zip(scuff, se)]

    mix = []
    for i in range(n):
        v = body[i]
        v += th[i] * sp["thump_amp"]
        v += scuff[i] * sp["scuff"] * 0.45
        if i < imp_n:
            v += imp[i]
        mix.append(v)

    peak = max(abs(v) for v in mix) or 1.0
    g = PEAK / peak
    return array.array("h", [int(max(-1.0, min(1.0, v * g)) * 32767) for v in mix])


def write(path, samples):
    w = wave.open(path, "wb")
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(samples.tobytes())
    w.close()


if __name__ == "__main__":
    import os
    out = "assets/audio/sfx"
    os.makedirs(out, exist_ok=True)
    made = []
    for surf in SURFACES:
        for k in (1, 2):
            s = make_step(surf, hash((surf, k)) & 0xFFFF)
            p = f"{out}/step_{surf}_{k}.wav"
            write(p, s)
            made.append((p, len(s), max(abs(v) for v in s)))
    for p, n, pk in made:
        print(f"  {p}  {n} إطار  {n / SR * 1000:.0f} مللي  ذروة {pk / 32767:.2f}")
