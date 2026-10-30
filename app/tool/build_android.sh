set -eo pipefail
export JAVA_HOME=/home/box/jdk/17 ANDROID_HOME=/home/box/android-sdk ANDROID_SDK_ROOT=/home/box/android-sdk
export PATH=/home/box/flutter/bin:$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:/usr/bin:/bin
flutter config --android-sdk $ANDROID_HOME --jdk-dir $JAVA_HOME >/dev/null
SRC=${NEWLIFE_SRC:-/workspace/british-life/app}
B=/workspace/android_build
export NEWLIFE_SRC="$SRC"
python3 - <<'PY'
import json, os, shutil
from pathlib import Path
SRC = Path(os.environ['NEWLIFE_SRC'])
B = Path('/workspace/android_build')
B.mkdir(parents=True, exist_ok=True)

def ignore(dir, names):
    drop = set()
    if Path(dir).name == 'audio' and Path(dir).parent.name == 'assets':
        for n in names:
            if n.endswith('.mp3') and n != 'silence.mp3':
                drop.add(n)
    if 'build' in names: drop.add('build')
    if '.dart_tool' in names: drop.add('.dart_tool')
    return drop

# Fresh copy of app (excluding bulk mp3s)
if B.exists():
    # Remove stale bundled mp3s first so we don't keep old keys
    aud = B/'assets'/'audio'
    if aud.exists():
        for p in aud.glob('*.mp3'):
            if p.name != 'silence.mp3':
                p.unlink()
# copytree into existing: use manual walk
for root, dirs, files in os.walk(SRC):
    rel = Path(root).relative_to(SRC)
    # skip
    parts = set(rel.parts)
    if 'build' in parts or '.dart_tool' in parts: 
        dirs[:] = []
        continue
    dest_dir = B/rel
    dest_dir.mkdir(parents=True, exist_ok=True)
    for f in files:
        if rel.parts[:2] == ('assets','audio') and f.endswith('.mp3') and f != 'silence.mp3':
            continue
        s = Path(root)/f
        d = dest_dir/f
        if not d.exists() or s.stat().st_mtime > d.stat().st_mtime or s.stat().st_size != d.stat().st_size:
            shutil.copy2(s, d)

# Ensure meta + silence
for name in ['silence.mp3','index.json','bundled.json','ver.json']:
    shutil.copy2(SRC/'assets'/'audio'/name, B/'assets'/'audio'/name)

keys = json.loads((SRC/'assets'/'audio'/'bundled.json').read_text())
n = 0
for k in keys:
    s = SRC/'assets'/'audio'/f'{k}.mp3'
    if s.exists():
        shutil.copy2(s, B/'assets'/'audio'/f'{k}.mp3'); n += 1
print(f'synced app; bundled {n}/{len(keys)} early-lesson clips into APK tree')
PY
cd $B
rm -f android/local.properties
flutter pub get >/dev/null
yes | $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --licenses >/dev/null || true
flutter build apk --release
flutter build appbundle --release
ls -la build/app/outputs/flutter-apk/app-release.apk build/app/outputs/bundle/release/app-release.aab
