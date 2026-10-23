import 'dart:convert';

import 'package:flutter/services.dart';

import 'asset_fetch_stub.dart' if (dart.library.js_interop) 'asset_fetch_web.dart';

/// Text from the asset bundle, robustly. rootBundle.loadString caches a failed future for good (so "Try again"
/// could never recover), and a flaky phone network or stale offline cache can hand back a cut-off file. So:
/// read the raw bytes (not cached), check they decode (and parse, for .json), and on any failure retry with a
/// fresh network fetch, up to 4 tries.
Future<String> loadAssetText(String key, [AssetBundle? b]) async {
  final bundle = b ?? rootBundle;
  Object? err;
  for (var i = 0; i < 4; i++) {
    try {
      final d = i == 0 ? await bundle.load(key) : (await fetchFresh(key) ?? await bundle.load(key));
      final s = utf8.decode(Uint8List.sublistView(d));
      if (key.endsWith('.json')) jsonDecode(s);
      return s;
    } catch (e) {
      err = e;
      if (i < 3) await Future.delayed(Duration(milliseconds: 250 * (i + 1)));
    }
  }
  throw err!;
}
