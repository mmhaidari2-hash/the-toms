import 'package:audioplayers/audioplayers.dart';
import 'package:british_life/core/platform/speech_io.dart';
import 'package:flutter_test/flutter_test.dart';

/// Android build: voice clips stream from the site (not packed in the APK), effects play from the bundle,
/// and off Android (tests) nothing tries to touch a media player.
void main() {
  test('voice clips stream from the site, sfx and silence come from the APK', () {
    final v = SpeechInput.sourceFor('assets/audio/00044fa2def99c4a.mp3');
    expect(v, isA<UrlSource>());
    expect((v as UrlSource).url, 'https://mmhaidari2-hash.github.io/the-toms/assets/assets/audio/00044fa2def99c4a.mp3');
    final fx = SpeechInput.sourceFor('assets/sfx/ding.mp3');
    expect(fx, isA<AssetSource>());
    expect((fx as AssetSource).path, 'sfx/ding.mp3');
    expect(SpeechInput.sourceFor('assets/audio/silence.mp3'), isA<AssetSource>());
  });

  test('off Android it behaves like the stub', () async {
    expect(SpeechInput.sttSupported, isFalse);
    expect(SpeechInput.recordSupported, isFalse);
    expect(await SpeechInput.playClip('assets/audio/x.mp3', 1), isFalse);
    SpeechInput.stopClip();
    SpeechInput.playFx('assets/sfx/ding.mp3');
  });
}
