# Android release (New Life UK)

- App id `app.thetoms.newlifeuk`, label "New Life UK", version from pubspec (`1.0.0+1`), minSdk 24, target/compile 36.
- Only permission: `INTERNET` (voice clips stream from the site; the ~44k mp3s, 567 MB, are not packed into the APK).
- Native audio: `lib/core/platform/speech_io.dart` (audioplayers). Speech recognition/recording are web-only for now.
- Icon: adaptive (`mipmap-anydpi-v26`), foreground = the glass icon art, background `#061A42`, monochrome themed layer.
- Signing: upload keystore and `key.properties` live OUTSIDE the repo (`/home/box/keys/`, or env `NEWLIFE_KEY_PROPERTIES`).
  Never commit them. Without key.properties the release build falls back to debug keys (local only).
- Build: `bash tool/build_android.sh` (copies the app to /workspace/android_build without voice mp3s, then builds APK + AAB).
