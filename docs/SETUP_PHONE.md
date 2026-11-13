# إعداد الهاتف — أوامر جاهزة للنسخ

> مبني على توثيق Godot الرسمي وتقارير أخطاء موثقة، لا على اختبار ميداني.
> صحّح أي خطوة تفشل عندك وأبلغ بها.

---

## أ — تثبيت Termux

ثبّته من **F-Droid** لا من Google Play — نسخة Play مهجورة ولا تُحدَّث.

Termux ليس ضرورياً للاستيراد لمرة واحدة، لكنه ضروري لحلقة `git pull`
المستمرة. وتوثيق Godot يوصي به تحديداً لمزامنة المشاريع عبر Git.

```bash
pkg update -y && pkg upgrade -y
pkg install -y git gh
termux-setup-storage
```

`termux-setup-storage` يمنح Termux الوصول للتخزين المشترك وينشئ `~/storage`.

### إذا لم يطلب الأمر أي إذن (مشكلة موثقة على Android 15)

1. الإعدادات ← التطبيقات ← **Termux** ← الأذونات ← الملفات والوسائط
2. اختر **رفض**، ثم ارجع واختر **سماح**
3. أعد تشغيل Termux وأعد الأمر

تحقق من النجاح:

```bash
ls ~/storage/shared
```

يجب أن ترى `Documents` و `Download` و `DCIM`.

---

## ب — إعداد git (مرة واحدة)

```bash
git config --global user.name "novence974"
git config --global user.email "novence974@users.noreply.github.com"
git config --global init.defaultBranch main
git config --global core.fileMode false
```

**السطر الأخير مهم:** التخزين المشترك في أندرويد لا يحفظ بتات أذونات
الملفات كما يفعل لينكس. بدون هذا السطر سيرى git تغيّرات أذونات وهمية
ويعتبرها تعديلات في كل مرة.

---

## ج — تسجيل الدخول إلى GitHub

```bash
gh auth login
```

اختر: `GitHub.com` ← `HTTPS` ← `Login with a web browser`.
سيعطيك رمزاً من ثمانية محارف. افتح الرابط الظاهر، الصق الرمز، وافق.

تحقق:

```bash
gh auth status
```

---

## د — استنساخ المشروع

```bash
cd ~/storage/shared/Documents
gh repo clone novence974/the-last-memory
cd the-last-memory && ls
```

يجب أن ترى `project.godot` و `src/` و `README.md`.

### لماذا هذا المسار تحديداً

المسار الكامل: `/storage/emulated/0/Documents/the-last-memory`

- التخزين المشترك هو المكان الوحيد الذي تراه التطبيقات الأخرى. لو
  استنسخت داخل مجلد Termux الخاص (`$HOME`) فلن يرى Godot شيئاً.
- `Documents` ثابت ولا تمسحه منظفات التخزين، بخلاف `Download`.

المشروع نصي بالكامل، بلا روابط رمزية ولا ملفات تنفيذية، فقيود التخزين
المشترك على بتات التنفيذ والروابط لا تمسّه.

---

## هـ — أذونات Godot

قبل الاستيراد، امنح المحرر **إذن الوصول لكل الملفات**:

الإعدادات ← التطبيقات ← **Godot** ← الأذونات
أو: الإعدادات ← التطبيقات ← الوصول الخاص للتطبيقات ← **الوصول لكل الملفات**

| الإذن | متى | إلزامي؟ |
|---|---|---|
| All files access | الآن، قبل الاستيراد | ✅ نعم |
| REQUEST_INSTALL_PACKAGES | يُطلب عند تصدير APK (المهمة 0.8) | عند الحاجة |
| RECORD_AUDIO | لا نستخدمه | ❌ لا |

---

## و — الاستيراد في Godot

1. افتح Godot ← **Import**
2. وجّهه إلى:
   `/storage/emulated/0/Documents/the-last-memory/project.godot`
3. **Import & Edit**

عند أول فتح سيولّد Godot مجلد `.godot/` ويعيد كتابة `project.godot`
بصيغته الكاملة. سلوك طبيعي، و`.godot/` مستثنى من المستودع.

---

## الحلقة اليومية

عند وصول تعديل جديد:

```bash
cd ~/storage/shared/Documents/the-last-memory
git pull
```

ثم افتح Godot — سيلتقط التغييرات.

وإذا عدّلت أنت شيئاً داخل Godot وأردت دفعه:

```bash
cd ~/storage/shared/Documents/the-last-memory
git add -A
git commit -m "وصف قصير لما غيّرته"
git push
```
