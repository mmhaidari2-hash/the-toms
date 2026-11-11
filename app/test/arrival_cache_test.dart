import 'dart:io';

import 'package:british_life/core/platform/audio_ver.g.dart';
import 'package:british_life/core/platform/speech_io.dart';
import 'package:british_life/features/arrival/arrival_prefetch_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const key = 'q29_local_fixture';

  test('arrival warmer fills the player cache for the same version', () async {
    SpeechInput.debugSetVer('q29cache');
    final cache = await SpeechInput.clipCacheDirectory();
    final cached = File('${cache.path}/$key.mp3');
    final stray = File('${Directory.systemTemp.path}/newlifeuk_arrival/$key.mp3');
    await cached.writeAsBytes(List<int>.filled(80, 7), flush: true);
    if (await stray.exists()) await stray.delete();
    addTearDown(() async {
      SpeechInput.debugSetVer(kAudioCacheVer);
      if (await cached.exists()) await cached.delete();
      if (await stray.exists()) await stray.delete();
    });

    final n = await warmArrivalAudio([key]);

    expect(cache.path, endsWith('/newlifeuk_audio/nl_audio_q29cache'));
    expect(n, 1);
    expect(await cached.exists(), isTrue);
    expect(await cached.length(), greaterThan(64));
    expect(await stray.exists(), isFalse);
  });
}
