set -eo pipefail
export JAVA_HOME=/home/box/jdk/17 ANDROID_HOME=/home/box/android-sdk ANDROID_SDK_ROOT=/home/box/android-sdk
export PATH=/home/box/flutter/bin:$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH
flutter config --android-sdk $ANDROID_HOME --jdk-dir $JAVA_HOME >/dev/null
B=/workspace/android_build
mkdir -p $B
# Same app, but voice mp3s stay on the site (streamed); index.json + silence.mp3 bundled.
rsync -a --delete --exclude build/ --exclude .dart_tool/ --exclude 'assets/audio/*.mp3' --include 'assets/audio/silence.mp3' /workspace/british-life/app/ $B/
cp /workspace/british-life/app/assets/audio/silence.mp3 $B/assets/audio/ 2>/dev/null || true
cd $B
rm -f android/local.properties
flutter pub get >/dev/null
yes | $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --licenses >/dev/null || true
flutter build apk --release
flutter build appbundle --release
ls -la build/app/outputs/flutter-apk/app-release.apk build/app/outputs/bundle/release/app-release.aab
