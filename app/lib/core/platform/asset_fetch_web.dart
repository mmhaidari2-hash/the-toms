import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

/// Re-fetch an asset straight from the network with a cache-busting query (skips stale caches).
Future<ByteData?> fetchFresh(String key) async {
  try {
    final url = '${ui_web.assetManager.getAssetUrl(key)}?v=${DateTime.now().millisecondsSinceEpoch}';
    final res = await web.window.fetch(url.toJS, web.RequestInit(cache: 'reload')).toDart;
    if (!res.ok) return null;
    final buf = (await res.arrayBuffer().toDart).toDart;
    return ByteData.view(buf);
  } catch (_) {
    return null;
  }
}
