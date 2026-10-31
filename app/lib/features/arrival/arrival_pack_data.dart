import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/asset_text.dart';

class ArrivalPhrase {
  final String id, en, fa, sp;
  const ArrivalPhrase({required this.id, required this.en, required this.fa, required this.sp});
  factory ArrivalPhrase.fromJson(Map j) => ArrivalPhrase(
        id: j['id'] as String,
        en: j['en'] as String,
        fa: j['fa'] as String,
        sp: j['sp'] as String? ?? 'narrator',
      );
}

class ArrivalUnitRef {
  final String id, title, titleFa;
  final List<String> sceneIds;
  const ArrivalUnitRef({required this.id, required this.title, required this.titleFa, required this.sceneIds});
  factory ArrivalUnitRef.fromJson(Map j) => ArrivalUnitRef(
        id: j['id'] as String,
        title: j['title'] as String,
        titleFa: j['titleFa'] as String,
        sceneIds: [for (final s in (j['sceneIds'] as List? ?? const [])) s as String],
      );
}

class ArrivalPack {
  final String id, title, titleFa, tagline, taglineFa, disclaimer, disclaimerFa;
  final List<ArrivalUnitRef> units;
  final bool formsLab;
  final List<ArrivalPhrase> phrases;
  final List<String> sceneIds;
  final List<String> audioKeys;
  final double approxAudioMb;
  const ArrivalPack({
    required this.id,
    required this.title,
    required this.titleFa,
    required this.tagline,
    required this.taglineFa,
    required this.disclaimer,
    required this.disclaimerFa,
    required this.units,
    required this.formsLab,
    required this.phrases,
    required this.sceneIds,
    required this.audioKeys,
    required this.approxAudioMb,
  });
  factory ArrivalPack.fromJson(Map j) => ArrivalPack(
        id: j['id'] as String,
        title: j['title'] as String,
        titleFa: j['titleFa'] as String,
        tagline: j['tagline'] as String,
        taglineFa: j['taglineFa'] as String,
        disclaimer: j['disclaimer'] as String,
        disclaimerFa: j['disclaimerFa'] as String,
        units: [for (final u in (j['units'] as List? ?? const [])) ArrivalUnitRef.fromJson(u as Map)],
        formsLab: j['formsLab'] as bool? ?? true,
        phrases: [for (final p in (j['phrases'] as List? ?? const [])) ArrivalPhrase.fromJson(p as Map)],
        sceneIds: [for (final s in (j['sceneIds'] as List? ?? const [])) s as String],
        audioKeys: [for (final k in (j['audioKeys'] as List? ?? const [])) k as String],
        approxAudioMb: (j['approxAudioMb'] as num?)?.toDouble() ?? 0,
      );
  static ArrivalPack parse(String raw) => ArrivalPack.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

final arrivalPackProvider =
    FutureProvider<ArrivalPack>((ref) async => ArrivalPack.parse(await loadAssetText('assets/data/arrival_pack.json')));
