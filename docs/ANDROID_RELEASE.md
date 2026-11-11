# Android release (New Life UK)

- App id `app.thetoms.newlifeuk`, label "New Life UK", version from pubspec (`1.0.0+1`), minSdk 24, target/compile 36.
- Only permission: `INTERNET` (voice clips stream from the site; the ~44k mp3s, 567 MB, are not packed into the APK).
- Native audio: `lib/core/platform/speech_io.dart` (audioplayers). Speech recognition/recording are web-only for now.
- Icon: adaptive (`mipmap-anydpi-v26`), foreground = the glass icon art, background `#061A42`, monochrome themed layer.
- Signing: the upload keystore and `key.properties` stay outside the repo. Never commit them.
  Gradle reads `NEWLIFE_KEY_PROPERTIES`, or `/home/box/keys/key.properties` when that variable is unset (`app/android/app/build.gradle.kts`).
  A normal release stops when that file is absent. Tasks whose names start with `assemble` or `bundle` and contain `Release` throw `Release build needs the upload key (NEWLIFE_KEY_PROPERTIES).`
  Debug signing happens only when the existing variable `ALLOW_DEBUG_SIGNED_RELEASE` is exactly `1`. That variable is not a store identity and not release readiness. This guide does not set it and does not use it.
- امضا: کلید بارگذاری و `key.properties` بیرون از مخزن می‌مانند و commit نمی‌شوند.
  Gradle متغیر `NEWLIFE_KEY_PROPERTIES` را می‌خواند، و اگر تنظیم نشده باشد مسیر `/home/box/keys/key.properties`.
  ساخت عادی release وقتی این فایل نباشد متوقف می‌شود. وظیفهٔ `assemble` یا `bundle` که نامش `Release` دارد همان استثنا را می‌دهد.
  امضای debug فقط وقتی است که متغیر موجود `ALLOW_DEBUG_SIGNED_RELEASE` دقیقاً `1` باشد. این متغیر هویت فروشگاه نیست و آمادگی انتشار نیست. این راهنما آن را روشن نمی‌کند و از آن استفاده نمی‌کند.
- Build: `bash tool/build_android.sh` (copies the app to /workspace/android_build without voice mp3s, then builds APK + AAB).
