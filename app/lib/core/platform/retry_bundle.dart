import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';

import 'asset_fetch_stub.dart' if (dart.library.js_interop) 'asset_fetch_web.dart';

/// The asset bundle widgets read through DefaultAssetBundle (Image.asset etc.). Pictures are checked: if a
/// load fails or the bytes aren't a real image (a stale or broken offline cache, seen on iOS home-screen
/// apps), the file is fetched again from the network with a cache-busting query.
class RetryAssetBundle extends CachingAssetBundle {
  final AssetBundle inner;
  RetryAssetBundle([AssetBundle? inner]) : inner = inner ?? rootBundle;

  static final _img = RegExp(r'\.(webp|png|jpe?g|gif)$', caseSensitive: false);

  static bool looksLikeImage(ByteData d) {
    if (d.lengthInBytes < 12) return false;
    final b = Uint8List.sublistView(d, 0, 12);
    final png = b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47;
    final jpg = b[0] == 0xFF && b[1] == 0xD8;
    final gif = b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46;
    final webp = b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 && b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50;
    return png || jpg || gif || webp;
  }

  @override
  Future<ByteData> load(String key) async {
    final isImg = _img.hasMatch(key);
    ByteData? d;
    try {
      d = await inner.load(key);
      if (!isImg || looksLikeImage(d)) return d;
    } catch (_) {}
    final fresh = await fetchFresh(key);
    if (fresh != null && (!isImg || looksLikeImage(fresh))) return fresh;
    if (d != null) return d;
    throw FlutterError('Unable to load asset: $key');
  }

  @override
  Future<ui.ImmutableBuffer> loadBuffer(String key) async {
    if (!_img.hasMatch(key)) return inner.loadBuffer(key);
    final d = await load(key);
    return ui.ImmutableBuffer.fromUint8List(Uint8List.sublistView(d));
  }
}
