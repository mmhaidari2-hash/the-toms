import 'dart:io';

/// Downloads Arrival Pack clips into a local folder so Android can play them offline.
Future<int> warmArrivalAudio(
  List<String> keys, {
  void Function(double progress, int done, int total)? onProgress,
  bool Function()? shouldCancel,
}) async {
  const remote = 'https://mmhaidari2-hash.github.io/the-toms/assets/assets/audio';
  final dir = Directory('${Directory.systemTemp.path}/newlifeuk_arrival');
  await dir.create(recursive: true);
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
  final total = keys.length;
  var done = 0, ok = 0;
  try {
    for (final k in keys) {
      if (shouldCancel?.call() == true) break;
      final file = File('${dir.path}/$k.mp3');
      try {
        if (!await file.exists() || await file.length() < 64) {
          final req = await client.getUrl(Uri.parse('$remote/$k.mp3'));
          final res = await req.close().timeout(const Duration(seconds: 20));
          if (res.statusCode >= 200 && res.statusCode < 300) {
            final bytes = await res.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
            if (bytes.length > 64) {
              await file.writeAsBytes(bytes, flush: true);
              ok++;
            }
          }
        } else {
          ok++;
        }
      } catch (_) {}
      done++;
      onProgress?.call(done / total, done, total);
    }
  } finally {
    client.close(force: true);
  }
  return ok;
}
