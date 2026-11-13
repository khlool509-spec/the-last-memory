# إعداد الهاتف — أوامر جاهزة للنسخ

## المهمة 0.10 — Termux و Git

ثبّت Termux من **F-Droid** لا من Google Play (نسخة Play مهجورة ولا تُحدَّث).

ثم في Termux:

```bash
pkg update -y && pkg upgrade -y
pkg install -y git gh openssh
git config --global user.name "novence974"
git config --global user.email "novence974@users.noreply.github.com"
git config --global init.defaultBranch main
termux-setup-storage
```

الأمر الأخير يطلب إذن الوصول للتخزين، ويُنشئ `~/storage`. وافق عليه.

## تسجيل الدخول إلى GitHub

```bash
gh auth login
```

اختر: `GitHub.com` ← `HTTPS` ← `Login with a web browser`.
سيعطيك رمزاً من ثمانية محارف. افتح الرابط الذي يظهر، الصق الرمز، وافق.

ثم تحقق:

```bash
gh auth status
```

## المهمة 0.12 — استنساخ المشروع

```bash
cd ~/storage/shared/Documents
gh repo clone novence974/the-last-memory
cd the-last-memory
ls -la
```

يجب أن ترى `project.godot` و `README.md` و `src/`.

## الحلقة اليومية بعد ذلك

عندما أدفع تعديلاً:

```bash
cd ~/storage/shared/Documents/the-last-memory
git pull
```

ثم افتح Godot — سيلتقط التغييرات.

إذا عدّلت أنت شيئاً داخل Godot وأردت أن أراه:

```bash
git add -A
git commit -m "وصف قصير لما غيّرته"
git push
```

## المسار الذي ستحتاجه في Godot

```
/storage/emulated/0/Documents/the-last-memory/project.godot
```
