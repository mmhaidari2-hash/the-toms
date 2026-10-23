import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/platform/asset_text.dart';

/// Role-play missions per building (assets/data/roleplays.json, built by tool/make_roleplays.py):
/// a short in-app dialogue with a town character. Three goals, a hint per turn, normal + slow replay,
/// Persian on demand and a report card at the end. Practice only: nothing is recorded.
typedef Tr = ({String en, String fa});
Tr _tr(Map j) => (en: j['en'] as String, fa: j['fa'] as String);

class RpOption {
  /// 2 = natural and polite, 1 = works but blunt or unclear, 0 = doesn't fit (try again).
  final int q;
  /// Goal this answer completes (index into [Roleplay.goals]), or -1.
  final int goal;
  final String en, fa;
  final Tr fb;
  const RpOption(this.q, this.goal, this.en, this.fa, this.fb);
}

class RpTurn {
  final Tr npc, hint;
  final List<RpOption> opts;
  const RpTurn(this.npc, this.hint, this.opts);
  RpOption get best => opts.firstWhere((o) => o.q == 2);
}

class Roleplay {
  final String id, level, spot, sp, npc, title, titleFa;
  final Tr intro, end;
  final List<Tr> goals;
  final List<RpTurn> turns;
  const Roleplay({required this.id, required this.level, required this.spot, required this.sp, required this.npc, required this.title, required this.titleFa, required this.intro, required this.end, required this.goals, required this.turns});
  String get icon => 'assets/spots/$spot.webp';
  factory Roleplay.fromJson(Map<String, dynamic> j) => Roleplay(
        id: j['id'],
        level: j['level'],
        spot: j['spot'],
        sp: j['sp'],
        npc: j['npc'],
        title: j['title'],
        titleFa: j['titleFa'],
        intro: _tr(j['intro']),
        end: _tr(j['end']),
        goals: [for (final g in j['goals'] as List) _tr(g)],
        turns: [
          for (final t in j['turns'] as List)
            RpTurn(_tr(t['npc']), _tr(t['hint']), [for (final o in t['opts'] as List) RpOption(o['q'], o['g'], o['en'], o['fa'], _tr(o['fb']))]),
        ],
      );

  static List<Roleplay> parse(String raw) => [for (final r in (jsonDecode(raw) as Map)['roleplays'] as List) Roleplay.fromJson(r)];

  /// Stars for a finished role-play: natural answers count double, every wrong try or hint costs one.
  static int stars({required int turns, required int natural, required int wrong, required int hints}) {
    final s = natural * 2 - wrong - hints;
    return s >= turns * 2 ? 3 : (s >= turns ? 2 : 1);
  }

  static int xp(int stars) => 5 + 5 * stars;
}

final roleplaysProvider = FutureProvider<List<Roleplay>>((ref) async => Roleplay.parse(await loadAssetText('assets/data/roleplays.json')));

extension RoleplayProgress on ProgressController {
  /// Best stars so far (0 = not finished yet).
  int roleplayStars(String id) => int.tryParse(pref('rp:$id')) ?? 0;
  /// Saves the result (keeps the best) and awards XP for this run.
  XpAward finishRoleplay(String id, int stars) {
    if (stars > roleplayStars(id)) setPref('rp:$id', '$stars');
    return awardXp(Roleplay.xp(stars));
  }
}
