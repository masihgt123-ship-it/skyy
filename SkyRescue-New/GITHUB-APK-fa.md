# ساخت APK در GitHub

این بسته تنظیمات ساخت دارد؛ APK هنوز ساخته یا روی گوشی تست نشده است. اولین Release به‌صورت prerelease منتشر می‌شود.

۱. یک مخزن GitHub بسازید. محتویات پوشهٔ SkyRescue-New را در ریشهٔ آن قرار دهید؛ project.godot و .github باید کنار هم باشند. پوشهٔ مخفی .github را جا نیندازید. فایل ZIP را به‌تنهایی آپلود نکنید.
۲. اگر کلید امضای قبلی دارید، همان را استفاده کنید. برای برنامهٔ تازه می‌توانید روی رایانه با JDK اجرا کنید:

```sh
keytool -genkeypair -v -keystore skyrescue-release.keystore -alias skyrescue -keyalg RSA -keysize 2048 -validity 10000
```

رمز keystore و رمز alias را یکسان بگذارید. فایل کلید و رمز را خارج از مخزن در جای امن پشتیبان بگیرید؛ برای به‌روزرسانی برنامه لازم‌اند. آن‌ها را در چت ارسال نکنید.

۳. فایل کلید را Base64 کنید. در PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path .\skyrescue-release.keystore))) | Set-Clipboard
```

در Linux:

```sh
base64 -w0 skyrescue-release.keystore
```

۴. در Settings → Secrets and variables → Actions سه Repository secret بسازید:
- ANDROID_KEYSTORE_BASE64: متن Base64 کلید
- ANDROID_KEY_ALIAS: نام alias، مثلاً skyrescue
- ANDROID_KEY_PASSWORD: رمز یکسان کلید و keystore

۵. در Actions → Android APK → Run workflow ساخت را دستی اجرا کنید. پس از موفقیت، فایل SkyRescue-APK را از Artifacts بگیرید و APK درونش را روی گوشی تست کنید.
۶. برای انتشار، یک tag مثل v1.0.0 بسازید (از Releases → Draft a new release هم می‌شود). ساخت روی tag اجرا می‌شود و APK را به Release اضافه می‌کند. در هر نسخه version/code در export_presets.cfg را افزایش دهید و version/name را تغییر دهید.

شناسهٔ فعلی: com.skyrescue.guardian؛ پیش از اولین انتشار اگر لازم است تغییر دهید، سپس برای به‌روزرسانی‌ها ثابت نگه دارید. کلید هم باید ثابت بماند.

در صورت خطای ساخت، اولین بخش قرمز لاگ Actions را بفرستید، نه اطلاعات امضا.
پیش از انتشار عمومی: گوشی واقعی، متن فارسی، صدا، عملکرد مراحل سنگین و صفحهٔ لمسی تست شود؛ فایل‌های مجوز و اعتبار Michel Baradari / CC BY 3.0 بررسی و همراه توزیع حفظ شوند.
