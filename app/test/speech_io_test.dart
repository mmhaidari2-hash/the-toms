import 'package:audioplayers/audioplayers.dart';
import 'package:british_life/core/platform/audio_ver.g.dart';
import 'package:british_life/core/platform/speech_io.dart';
import 'package:flutter_test/flutter_test.dart';

/// Android build: Azure clips only (never device TTS). Early lessons are bundled; the rest
/// stream with a cache-busting ?v= and audio/mpeg mime, then play from an on-device file cache.
void main() {
  test('voice clips use cache-busted HTTPS URL with audio/mpeg mime', () {
    SpeechInput.debugSetBundled({});
    SpeechInput.debugSetVer(kAudioCacheVer);
    final v = SpeechInput.sourceFor('assets/audio/00044fa2def99c4a.mp3');
    expect(v, isA<UrlSource>());
    final u = v as UrlSource;
    expect(u.url, startsWith('https://mmhaidari2-hash.github.io/the-toms/assets/assets/audio/00044fa2def99c4a.mp3?v='));
    expect(u.url, contains('v=$kAudioCacheVer'));
    expect(u.mimeType, 'audio/mpeg');
  });

  test('bundled early-lesson clips play from the APK, not the network', () {
    SpeechInput.debugSetBundled({'00044fa2def99c4a'});
    final v = SpeechInput.sourceFor('assets/audio/00044fa2def99c4a.mp3');
    expect(v, isA<AssetSource>());
    expect((v as AssetSource).path, 'audio/00044fa2def99c4a.mp3');
    expect(v.mimeType, 'audio/mpeg');
  });

  test('sfx and silence come from the APK', () {
    final fx = SpeechInput.sourceFor('assets/sfx/ding.mp3');
    expect(fx, isA<AssetSource>());
    expect((fx as AssetSource).path, 'sfx/ding.mp3');
    expect(SpeechInput.sourceFor('assets/audio/silence.mp3'), isA<AssetSource>());
  });

  test('off Android it behaves like the stub (no TTS, no player)', () async {
    expect(SpeechInput.sttSupported, isFalse);
    expect(SpeechInput.recordSupported, isFalse);
    expect(await SpeechInput.playClip('assets/audio/x.mp3', 1), isFalse);
    SpeechInput.stopClip();
    SpeechInput.playFx('assets/sfx/ding.mp3');
  });

  test('remoteUrlFor always points at the live Azure clip host', () {
    SpeechInput.debugSetVer('abc123');
    expect(
      SpeechInput.remoteUrlFor('assets/audio/deadbeef.mp3'),
      'https://mmhaidari2-hash.github.io/the-toms/assets/assets/audio/deadbeef.mp3?v=abc123',
    );
  });
}
