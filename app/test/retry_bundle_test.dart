import 'dart:convert';

import 'package:british_life/core/platform/retry_bundle.dart';
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fake extends CachingAssetBundle {
  final Map<String, List<int>> m;
  _Fake(this.m);
  @override
  Future<ByteData> load(String key) async {
    final v = m[key];
    if (v == null) throw FlutterError('missing $key');
    return ByteData.sublistView(Uint8List.fromList(v));
  }
}

void main() {
  final webp = [0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50, 1, 2];
  test('real pictures pass straight through', () async {
    final b = RetryAssetBundle(_Fake({'assets/a.webp': webp}));
    expect((await b.load('assets/a.webp')).lengthInBytes, webp.length);
  });
  test('a cached HTML page is not taken for a picture', () {
    expect(RetryAssetBundle.looksLikeImage(ByteData.sublistView(Uint8List.fromList(utf8.encode('<!DOCTYPE html><html>')))), isFalse);
  });
  test('a missing picture still errors off the web', () async {
    expect(() => RetryAssetBundle(_Fake({})).load('assets/x.png'), throwsA(isA<FlutterError>()));
  });
  test('non-image assets are untouched', () async {
    expect(await RetryAssetBundle(_Fake({'a.json': utf8.encode('{}')})).loadString('a.json'), '{}');
  });
}
