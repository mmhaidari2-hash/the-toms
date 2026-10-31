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
      if (res.ok) ok++;
    } catch (_) {}
    done++;
    onProgress?.call(done / total, done, total);
  }
  return ok;
}
