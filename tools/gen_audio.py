#!/usr/bin/env python3
"""يولّد كل أصوات اللعبة رياضياً بـ numpy.

لا يُنزَّل أي ملف ولا يُستخدم أي أصل خارجي: كل موجة تُحسب هنا،
فالترخيص ملك المشروع بالكامل. 22050Hz أحادي 16-bit لتصغير الـ APK.
"""
import numpy as np, wave, struct
from pathlib import Path

SR = 22050
ROOT = Path(__file__).resolve().parent.parent

def write_wav(path: Path, data: np.ndarray) -> int:
    data = np.clip(data, -1.0, 1.0)
    pcm = (data * 32767.0).astype(np.int16)
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    return path.stat().st_size

def t(dur): return np.linspace(0, dur, int(SR * dur), endpoint=False)

def lowpass(x, cutoff, order=4):
    """مرشّح تمرير منخفض بسيط بالتكرار الأسّي (بلا scipy)."""
    a = np.exp(-2.0 * np.pi * cutoff / SR)
    y = x.copy()
    for _ in range(order):
        out = np.empty_like(y); acc = 0.0
        for i in range(len(y)):
            acc = (1 - a) * y[i] + a * acc
            out[i] = acc
        y = out
    return y

def lowpass_fft(x, cutoff):
    """نسخة سريعة عبر FFT — تُستخدم للمقاطع الطويلة."""
    n = len(x)
    f = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(n, 1.0 / SR)
    f *= 1.0 / (1.0 + (freqs / max(cutoff, 1.0)) ** 2)
    return np.fft.irfft(f, n)

def highpass_fft(x, cutoff):
    n = len(x)
    f = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(n, 1.0 / SR)
    r = freqs / max(cutoff, 1.0)
    f *= (r ** 2) / (1.0 + r ** 2)
    return np.fft.irfft(f, n)

def fade(x, ms=12):
    n = int(SR * ms / 1000.0)
    if n * 2 >= len(x): n = len(x) // 4
    if n <= 0: return x
    ramp = np.linspace(0, 1, n)
    x = x.copy(); x[:n] *= ramp; x[-n:] *= ramp[::-1]
    return x

def loopable(x, cross_ms=400):
    """يجعل المقطع قابلاً للتكرار: يمزج ذيله مع رأسه."""
    n = int(SR * cross_ms / 1000.0)
    if n * 2 >= len(x): return fade(x)
    head, tail = x[:n], x[-n:]
    ramp = np.linspace(0, 1, n)
    x = x[:-n].copy()
    x[:n] = tail * (1 - ramp) + head * ramp
    return x

rng = np.random.default_rng(20261114)

# ---------- أجواء الغابة: ريح + حفيف + صرير خشب ----------
def ambient_forest(dur=22.0):
    ts = t(dur)
    noise = rng.standard_normal(len(ts))
    wind = lowpass_fft(noise, 260.0)
    # تنفّس بطيء يمنع الملل
    breath = 0.55 + 0.45 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.055 * ts + 0.7))
    breath *= 0.8 + 0.2 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.021 * ts))
    wind = wind / (np.max(np.abs(wind)) + 1e-9) * breath * 0.34

    # حفيف أوراق أعلى تردداً، متقطّع
    leaves = highpass_fft(rng.standard_normal(len(ts)), 1800.0)
    gate = np.clip(np.sin(2 * np.pi * 0.17 * ts + 1.3), 0, 1) ** 2
    leaves = leaves / (np.max(np.abs(leaves)) + 1e-9) * gate * 0.07

    # درون منخفض: يعطي ثقلاً ليلياً
    drone = (np.sin(2 * np.pi * 54.0 * ts) * 0.5
             + np.sin(2 * np.pi * 81.0 * ts + 1.1) * 0.25
             + np.sin(2 * np.pi * 40.5 * ts + 2.2) * 0.3)
    drone *= 0.055 * (0.7 + 0.3 * np.sin(2 * np.pi * 0.033 * ts))

    out = wind + leaves + drone

    # صرير خشب متباعد
    for _ in range(5):
        start = rng.integers(0, len(ts) - int(SR * 1.6))
        d = rng.uniform(0.5, 1.2)
        n = int(SR * d)
        ct = np.linspace(0, d, n, endpoint=False)
        f0 = rng.uniform(150, 330)
        creak = np.sin(2 * np.pi * (f0 + 26 * np.sin(2 * np.pi * 5.5 * ct)) * ct)
        creak *= np.exp(-2.6 * ct) * rng.uniform(0.05, 0.1)
        out[start:start + n] += creak
    return loopable(out, 700)

# ---------- موسيقى القائمة: درون حزين ----------
def menu_drone(dur=34.0):
    ts = t(dur)
    out = np.zeros(len(ts))
    # ثلاثي صغير معلّق: D - F - A  (طابع حزين بلا اقتباس من أي لحن)
    for f, amp, det in [(73.42, 0.30, 0.0), (87.31, 0.22, 0.4),
                        (110.0, 0.18, -0.3), (146.83, 0.12, 0.6),
                        (220.0, 0.06, 0.2)]:
        swell = 0.55 + 0.45 * np.sin(2 * np.pi * (0.021 + f * 1e-5) * ts + f)
        out += np.sin(2 * np.pi * (f + det) * ts + f) * amp * swell
    # هالة عالية خافتة
    shimmer = lowpass_fft(rng.standard_normal(len(ts)), 900.0)
    shimmer = shimmer / (np.max(np.abs(shimmer)) + 1e-9)
    out += shimmer * 0.05 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.047 * ts))
    out = lowpass_fft(out, 3200.0)
    out = out / (np.max(np.abs(out)) + 1e-9) * 0.52
    return loopable(out, 900)

# ---------- خطوات ----------
def footstep(seed):
    r = np.random.default_rng(seed)
    d = 0.19
    ts = t(d)
    n = r.standard_normal(len(ts))
    body = lowpass_fft(n, r.uniform(380, 620))
    crisp = highpass_fft(n, 2600.0) * 0.35
    env = np.exp(-r.uniform(26, 38) * ts)
    thump = np.sin(2 * np.pi * r.uniform(58, 78) * ts) * np.exp(-42 * ts) * 0.5
    x = (body * 1.0 + crisp) * env + thump
    x = x / (np.max(np.abs(x)) + 1e-9) * r.uniform(0.5, 0.68)
    return fade(x, 4)

# ---------- التقاط ----------
def pickup():
    d = 1.0
    ts = t(d)
    out = np.zeros(len(ts))
    for i, (f, a, dec) in enumerate([(880.0, 0.5, 4.5), (1318.5, 0.32, 5.5),
                                     (1760.0, 0.2, 7.0), (2637.0, 0.1, 9.0)]):
        delay = int(SR * 0.012 * i)
        env = np.exp(-dec * ts)
        tone = np.sin(2 * np.pi * f * ts) * a * env
        out[delay:] += tone[:len(ts) - delay]
    air = highpass_fft(rng.standard_normal(len(ts)), 4000.0) * np.exp(-28 * ts) * 0.08
    out = (out + air)
    return fade(out / (np.max(np.abs(out)) + 1e-9) * 0.6, 6)

def note_rustle():
    d = 0.75
    ts = t(d)
    n = rng.standard_normal(len(ts))
    x = highpass_fft(n, 1500.0)
    grain = (0.4 + 0.6 * np.abs(np.sin(2 * np.pi * 13.0 * ts + np.sin(2 * np.pi * 3.0 * ts))))
    env = np.exp(-4.2 * ts) * (1 - np.exp(-60 * ts))
    x = x * grain * env
    return fade(x / (np.max(np.abs(x)) + 1e-9) * 0.42, 8)

def ui_tick(low=False):
    d = 0.14
    ts = t(d)
    f = 320.0 if low else 740.0
    x = np.sin(2 * np.pi * f * ts) * np.exp(-34 * ts)
    x += np.sin(2 * np.pi * f * 2.02 * ts) * np.exp(-48 * ts) * 0.35
    click = highpass_fft(rng.standard_normal(len(ts)), 3500.0) * np.exp(-110 * ts) * 0.3
    x = x + click
    return fade(x / (np.max(np.abs(x)) + 1e-9) * 0.4, 4)

def gate_rumble():
    d = 2.6
    ts = t(d)
    n = rng.standard_normal(len(ts))
    low = lowpass_fft(n, 110.0)
    low = low / (np.max(np.abs(low)) + 1e-9)
    env = (1 - np.exp(-6 * ts)) * np.exp(-1.1 * ts)
    sub = np.sin(2 * np.pi * 38.0 * ts) * 0.5 + np.sin(2 * np.pi * 27.0 * ts) * 0.3
    grind = lowpass_fft(rng.standard_normal(len(ts)), 900.0)
    grind = grind / (np.max(np.abs(grind)) + 1e-9) * 0.22 * np.clip(np.sin(2 * np.pi * 1.7 * ts), 0, 1)
    x = (low * 0.75 + sub * 0.5 + grind) * env
    return fade(x / (np.max(np.abs(x)) + 1e-9) * 0.7, 20)

def heartbeat():
    d = 1.25
    ts = t(d)
    x = np.zeros(len(ts))
    for off, amp in [(0.0, 1.0), (0.33, 0.62)]:
        i = int(SR * off)
        seg = np.linspace(0, d - off, len(ts) - i, endpoint=False)
        thump = np.sin(2 * np.pi * 48.0 * seg) * np.exp(-14 * seg)
        thump += np.sin(2 * np.pi * 32.0 * seg) * np.exp(-11 * seg) * 0.6
        x[i:] += thump * amp
    return fade(x / (np.max(np.abs(x)) + 1e-9) * 0.55, 10)


# ---------- جريان الماء ----------
def river_flow(dur=18.0):
    ts = t(dur)
    n = rng.standard_normal(len(ts))
    # الماء: ضجيج عريض مرشّح، مع تموّج بطيء يوحي بالتيار
    body = highpass_fft(lowpass_fft(n, 2600.0), 320.0)
    body /= (np.max(np.abs(body)) + 1e-9)
    swell = 0.62 + 0.38 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.09 * ts + 0.4))
    swell *= 0.85 + 0.15 * np.sin(2 * np.pi * 0.23 * ts)
    out = body * swell * 0.40
    # خرير فوق الحصى: نبضات عالية متفرقة
    gurgle = highpass_fft(rng.standard_normal(len(ts)), 1700.0)
    gate = np.clip(np.sin(2 * np.pi * 1.9 * ts + np.sin(2 * np.pi * 0.37 * ts) * 2.2), 0, 1) ** 3
    out += gurgle / (np.max(np.abs(gurgle)) + 1e-9) * gate * 0.13
    # ثقل منخفض
    out += lowpass_fft(n, 190.0) / (np.max(np.abs(n)) + 1e-9) * 0.09
    return loopable(out, 600)

# ---------- طيور ليلية متفرقة ----------
def night_birds(dur=26.0):
    ts = t(dur)
    out = np.zeros(len(ts))
    r = np.random.default_rng(515)
    for _ in range(14):
        start = r.integers(0, len(ts) - int(SR * 1.5))
        d = r.uniform(0.12, 0.42)
        n = int(SR * d)
        ct = np.linspace(0, d, n, endpoint=False)
        f0 = r.uniform(900, 2600)
        sweep = f0 * (1.0 + r.uniform(-0.35, 0.45) * ct / max(d, 1e-6))
        call = np.sin(2 * np.pi * sweep * ct)
        call += np.sin(2 * np.pi * sweep * 2.01 * ct) * 0.3
        env = np.sin(np.pi * np.clip(ct / d, 0, 1)) ** 1.6
        out[start:start + n] += call * env * r.uniform(0.06, 0.16)
    # بومة بعيدة
    for _ in range(3):
        start = r.integers(0, len(ts) - int(SR * 2.0))
        d = 0.9
        n = int(SR * d)
        ct = np.linspace(0, d, n, endpoint=False)
        hoot = np.sin(2 * np.pi * 330.0 * ct) * 0.6 + np.sin(2 * np.pi * 165.0 * ct) * 0.4
        env = np.exp(-3.0 * ct) * (1 - np.exp(-40 * ct))
        out[start:start + n] += lowpass_fft(hoot * env, 800.0) * 0.14
    return loopable(out, 700)

# ---------- داخل المباني ----------
def indoor_room(dur=16.0):
    ts = t(dur)
    n = rng.standard_normal(len(ts))
    hum = lowpass_fft(n, 140.0)
    hum /= (np.max(np.abs(hum)) + 1e-9)
    out = hum * 0.16 * (0.75 + 0.25 * np.sin(2 * np.pi * 0.04 * ts))
    # طقطقة خشب متباعدة
    r = np.random.default_rng(828)
    for _ in range(7):
        start = r.integers(0, len(ts) - int(SR * 0.5))
        d = r.uniform(0.05, 0.16)
        nn = int(SR * d)
        ct = np.linspace(0, d, nn, endpoint=False)
        crack = np.sin(2 * np.pi * r.uniform(180, 520) * ct) * np.exp(-28 * ct)
        out[start:start + nn] += crack * r.uniform(0.05, 0.12)
    return loopable(out, 500)

# ---------- خطوات على أسطح مختلفة ----------
def footstep_surface(seed, kind):
    """خطوة واقعية: لا مُذبذب ولا نغمة.

    الخطوة الحقيقية صوت اصطدام لا آلة موسيقية. النسخة السابقة كانت
    تضيف موجة جيبية نقية (52-190 هرتز) فوق الضجيج، فكانت كل خطوة
    تحمل نغمة صافية تُسمع أزيزاً — وهو ما شكا منه اللاعب.

    البناء هنا فيزيائي: نبضة ضجيج منخفضة للارتطام، ونبضة أعلى
    ترددياً للسطح تتأخّر عنها قليلاً كما يتأخّر احتكاك النعل عن
    وقع الكعب، وكلتاهما مغلّفة بهجوم فوري وانحدار أسّي قصير.
    """
    r = np.random.default_rng(seed)
    d = r.uniform(0.085, 0.135)        # خطوة حقيقية: أقل من سُبع ثانية
    ts = t(d)
    n = len(ts)

    # الارتطام: ضجيج منخفض ينحدر بسرعة — كتلة الجسم على الأرض
    imp = r.standard_normal(n)
    if kind == "wood":
        body = lowpass_fft(imp, 520.0)
        decay = 46.0
    elif kind == "stone":
        body = lowpass_fft(imp, 380.0)
        decay = 72.0
    elif kind == "water":
        body = lowpass_fft(imp, 300.0)
        decay = 38.0
    else:                               # عشب وتراب
        body = lowpass_fft(imp, 440.0)
        decay = 58.0
    body *= np.exp(-decay * ts)

    # السطح: احتكاك النعل. نطاق تردّدي يميّز المادة، ويتأخّر 6-14 ملّي
    surf_n = r.standard_normal(n)
    if kind == "grass":
        surf = highpass_fft(lowpass_fft(surf_n, 6500.0), 1600.0)
        s_dec, s_amp = 34.0, 0.52
    elif kind == "wood":
        surf = highpass_fft(lowpass_fft(surf_n, 3400.0), 700.0)
        s_dec, s_amp = 40.0, 0.34
    elif kind == "stone":
        surf = highpass_fft(lowpass_fft(surf_n, 9000.0), 2600.0)
        s_dec, s_amp = 66.0, 0.46
    else:                               # ماء: رذاذ أعرض وأبطأ انحداراً
        surf = highpass_fft(lowpass_fft(surf_n, 7500.0), 900.0)
        s_dec, s_amp = 19.0, 0.62
    lag = int(SR * r.uniform(0.006, 0.014))
    s_env = np.exp(-s_dec * ts) * (1.0 - np.exp(-260.0 * ts))
    surf = np.concatenate([np.zeros(lag), surf[:n - lag]]) * s_env * s_amp

    x = body / (np.max(np.abs(body)) + 1e-9) + surf
    x /= (np.max(np.abs(x)) + 1e-9)
    # هجوم فوري بلا نقرة رقمية: ملّي ثانية واحدة تكفي
    atk = int(SR * 0.001)
    x[:atk] *= np.linspace(0.0, 1.0, atk)
    return fade(x * r.uniform(0.42, 0.56), 3)


FILES = [
    ("assets/audio/ambient/forest_night.wav", ambient_forest),
    ("assets/audio/ambient/river_flow.wav", river_flow),
    ("assets/audio/ambient/night_birds.wav", night_birds),
    ("assets/audio/ambient/indoor_room.wav", indoor_room),
    ("assets/audio/music/menu_drone.wav", menu_drone),
    ("assets/audio/sfx/footstep_1.wav", lambda: footstep(11)),
    ("assets/audio/sfx/footstep_2.wav", lambda: footstep(22)),
    ("assets/audio/sfx/footstep_3.wav", lambda: footstep(33)),
    ("assets/audio/sfx/footstep_4.wav", lambda: footstep(44)),
    ("assets/audio/sfx/step_grass_1.wav", lambda: footstep_surface(901, "grass")),
    ("assets/audio/sfx/step_grass_2.wav", lambda: footstep_surface(902, "grass")),
    ("assets/audio/sfx/step_wood_1.wav", lambda: footstep_surface(911, "wood")),
    ("assets/audio/sfx/step_wood_2.wav", lambda: footstep_surface(912, "wood")),
    ("assets/audio/sfx/step_stone_1.wav", lambda: footstep_surface(921, "stone")),
    ("assets/audio/sfx/step_stone_2.wav", lambda: footstep_surface(922, "stone")),
    ("assets/audio/sfx/step_water_1.wav", lambda: footstep_surface(931, "water")),
    ("assets/audio/sfx/step_water_2.wav", lambda: footstep_surface(932, "water")),
    ("assets/audio/sfx/pickup.wav", pickup),
    ("assets/audio/sfx/note.wav", note_rustle),
    ("assets/audio/sfx/ui_click.wav", lambda: ui_tick(False)),
    ("assets/audio/sfx/ui_back.wav", lambda: ui_tick(True)),
    ("assets/audio/sfx/gate_rumble.wav", gate_rumble),
    ("assets/audio/sfx/heartbeat.wav", heartbeat),
]

if __name__ == "__main__":
    total = 0
    for rel, fn in FILES:
        size = write_wav(ROOT / rel, fn())
        total += size
        print(f"{rel:48s} {size/1024:8.1f} KB")
    print(f"{'المجموع':48s} {total/1024/1024:8.2f} MB")
