# مراجعة بصرية — v0.7.0 (الأرض والسماء والإضاءة)

الصور في هذا المجلد **مُصيَّرة من المشروع الجاري كما هو**. لم يُغيَّر
أي إعداد بيئة أو خامة أو إضاءة لالتقاطها؛ أُضيفت أداة التقاط فقط
(`tools/shots/review.gd` + `.tscn`) تفتح `chapter_one.tscn`، تخفي
طبقات الواجهة، تضع كاميرا، وتحفظ ما يراه المصيّر.

نُقطة الالتزام: `c83f1a9` (v0.7.0). الشجر مُطفأ (`show_vegetation=false`)
وملفاته و52,524 نسخة توزيع محفوظة كاملة.

## الملفات

| الملف | المحتوى |
|---|---|
| `A_wide_environment__forward_plus.png` | منظر عريض: تضاريس، سماء، أفق، تكوين |
| `B_terrain_closeup__forward_plus.png` | الأرض عن قرب: جودة PBR، مقياس الخامة، تنوّع السطح |
| `C_sky_horizon__forward_plus.png` | السماء والأفق: عمق الجوّ وتدرّج الإضاءة |
| `D_lighting_shadows__forward_plus.png` | الإضاءة: ظلال، استجابة الخامات، إضاءة محيطة |
| `*__mobile.png` | المجموعة نفسها بمصيّر Mobile — وهو ما يعمل على الجوال فعلاً |

## كيف التُقطت بالضبط

لا يوجد كرت رسوميات في هذه البيئة، فيُستعمل **تصيير برمجي**:
Xvfb يوفّر شاشة افتراضية، وMesa lavapipe يوفّر Vulkan برمجياً.
هذه إطارات حقيقية خرجت من مسار التصيير نفسه الذي يعمل على الجهاز،
لا معاينة ولا تركيب.

```bash
export VK_ICD_FILENAMES=/opt/lavapipe/lvp_icd.json
export VK_DRIVER_FILES=/opt/lavapipe/lvp_icd.json
godot --headless --import --path .            # إلزامي: المحرك لا يعيد استيراد خامة تغيّرت

REVIEW_TAG=forward_plus xvfb-run -a -s "-screen 0 1920x1080x24" \
  godot --path . --rendering-driver vulkan --rendering-method forward_plus \
  --resolution 1920x1080 res://tools/shots/review.tscn

REVIEW_TAG=mobile xvfb-run -a -s "-screen 0 1920x1080x24" \
  godot --path . --rendering-driver vulkan --rendering-method mobile \
  --resolution 1920x1080 res://tools/shots/review.tscn
```

كل لقطة: 30 إطار تهيئة ثم 16 إطار استقرار بعد ضبط الكاميرا، ثم
`RenderingServer.frame_post_draw` قبل `get_image()`. وتُقاس نسبة
البكسلات غير السوداء في كل لقطة لكشف إطار فارغ يُحفظ بصمت.

المحوّل المُبلَّغ من المحرك: `llvmpipe (LLVM 20.1.2, 256 bits)`.

## الإعدادات الفعلية وقت الالتقاط

مقروءة من المشهد الجاري بـ`tools/diag/env_probe.gd` (قراءة فقط):

```
tonemap=ACES  exposure=1.161  white=5.00
ambient_source=SKY  sky_contribution=1.00  ambient_energy=0.55
reflected_light=BG   glow=true
ssao=false  ssil=false  sdfgi=false          ← لا حجب محيطي ولا إضاءة غير مباشرة
fog=DEPTH density=0.00059 aerial=0.35 sky_affect=0.08 begin=110م end=460م
volumetric_fog=false (مُطفأ نهاراً عمداً)
adjustment: saturation=1.04 contrast=1.08
sky = ShaderMaterial (assets/shaders/sky.gdshader)

شمس: energy=1.65  color=(1.00,0.953,0.871)  shadow=on  max_dist=150م
     bias=0.045  normal_bias=1.40  blur=1.00  angular_distance=0.00  ← ظل حادّ تماماً
     splits=0.10/0.20/0.50  pancake=20
مصابيح نقطية: 18

إعدادات المشروع:
  directional_shadow/size = 4096
  soft_shadow_filter_quality = 2
  msaa_3d = 0                      ← بلا إزالة تسنّن
  screen_space_aa = 0
  scaling_3d = bilinear @ 1.0
  anisotropic_filtering_level = 2  (4×)
  renderer/rendering_method = "mobile"   ← إعداد المشروع لم يُغيَّر
```

## الخامات المستعملة في هذه اللقطات

كلها من [Poly Haven](https://polyhaven.com) برخصة
[CC0 1.0](https://polyhaven.com/license) — بلا نسب مطلوب، تجاري مسموح.
البصمات والمصادر في `assets/textures/pbr/MANIFEST.json`.

| الخامة | الدور | بلاطة واقعية | الدقة |
|---|---|---|---|
| [forest_ground_04](https://polyhaven.com/a/forest_ground_04) | تفصيل أ: تربة وحصى | 3.15 م | 2048² |
| [forrest_ground_01](https://polyhaven.com/a/forrest_ground_01) | تفصيل ب: أرض بعشب | 2.00 م | 2048² |
| [rocky_terrain_02](https://polyhaven.com/a/rocky_terrain_02) | طبقة النطاق الواسع والقناع | 90 م | 2048² |
| [aerial_rocks_02](https://polyhaven.com/a/aerial_rocks_02) | صخر المنحدرات | 50 م | 2048² |
| [weathered_plank_siding](https://polyhaven.com/a/weathered_plank_siding) | جدران خشبية | 1.57 م | 2048² |
| [weathered_planks](https://polyhaven.com/a/weathered_planks) | أرضيات وأسطح | 2.00 م | 2048² |
| [lichen_rock](https://polyhaven.com/a/lichen_rock) | حجر | 2.00 م | 2048² |
| [roof_07](https://polyhaven.com/a/roof_07) | أسقف | 2.00 م | 2048² |

كل خامة: Diffuse + nor_gl + arm (أحمر=حجب، أخضر=خشونة، أزرق=معدنية)،
صيغة JPG، مستوردة بضغط VRAM مع mipmaps.

## الأدوات الخارجية

- [Godot Engine 4.7.2](https://godotengine.org) — `ed1daf0bf`
- [Mesa lavapipe](https://docs.mesa3d.org/drivers/llvmpipe.html) — Vulkan برمجي
- [Xvfb](https://www.x.org/releases/current/doc/man/man1/Xvfb.1.xhtml) — شاشة افتراضية
