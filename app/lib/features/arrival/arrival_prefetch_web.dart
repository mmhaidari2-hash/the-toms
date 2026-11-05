import 'dart:js_interop';

import 'package:web/web.dart' as web;

@JS('fetch')
external JSPromise<web.Response> _fetch(JSAny url);

/// GETs each clip so the PWA service worker stores it in the audio cache.
Future<int> warmArrivalAudio(
  List<String> keys, {
  void Function(double progress, int done, int total)? onProgress,
  bool Function()? shouldCancel,
}) async {
  final total = keys.length;
  var done = 0, ok = 0;
  // Relative to the deployed base href (/the-toms/).
  const prefix = 'assets/assets/audio';
  for (final k in keys) {
    if (shouldCancel?.call() == true) break;
    try {
      final res = await _fetch('$prefix/$k.mp3'.toJS).toDart;
      if (res.status == 200) {
        // Drain the complete response: an HTML fallback, truncated stream or
        // partial Range response must not be reported as downloaded speech.
        final bytes = (await res.arrayBuffer().toDart).toDart.asUint8List();
        final expected = int.tryParse(res.headers.get('content-length') ?? '');
        final mp3 =
            bytes.length >= 64 &&
            ((bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) ||
                (bytes[0] == 0xff && (bytes[1] & 0xe0) == 0xe0));
        if (mp3 && (expected == null || expected == bytes.length)) ok++;
      }
    } catch (_) {}
    done++;
    onProgress?.call(done / total, done, total);
  }
  return ok;
}
