import 'dart:convert';
import 'dart:math';

import '../models/dialogue_node.dart';

/// One multiple-choice question of the progress check.
class CheckItem {
  final int level; // 1–5 (A1 … C1)
  final String prompt; // English line to read (and hear, when [speaker] has a clip)
  final String? speaker;
  final String answer;
  final List<String> choices;
  final String kind; // 'reply' (best reply in a real scene) or 'placement'
  const CheckItem({required this.level, required this.prompt, required this.answer, required this.choices, required this.kind, this.speaker});
}

/// One saved result.
class CheckResult {
  final String day; // yyyy-mm-dd
  final int level;
  final int right, total;
  const CheckResult(this.day, this.level, this.right, this.total);
  Map<String, dynamic> toJson() => {'d': day, 'l': level, 'r': right, 't': total};
  factory CheckResult.fromJson(Map<String, dynamic> j) => CheckResult(j['d'] as String, (j['l'] as num).toInt(), (j['r'] as num? ?? 0).toInt(), (j['t'] as num? ?? 0).toInt());
}

/// Repeatable progress check with an UNOFFICIAL level estimate (owner t306 item 5).
///
/// Every run draws new questions: "best reply" items from the app's own scenes at each level (the authored reply
/// against replies from other scenes of the same level), plus a rotating placement question. Adaptive like the
/// placement test: start at A2, climb on ≥70 %, stop on a miss (drop to A1 if A2 is missed). It is an estimate
/// from a short quiz — not a CEFR certificate and not equivalent to IELTS, an SELT or Life in the UK.
abstract final class ProgressCheck {
  static const perLevel = 5;
  static const historyKey = 'check:history';
  static const maxHistory = 30;

  static int levelOfCefr(String c) => switch (c.toUpperCase()) {
        'A0' || 'A1' => 1,
        'A2' => 2,
        'B1' => 3,
        'B2' => 4,
        _ => 5,
      };

  static bool _usable(String s) => s.trim().length >= 3 && !s.contains('{') && !s.contains('…');

  /// Builds [perLevel] questions per level from [scenes] (and [placement] items of the form (level, prompt, answer,
  /// choices)), different for each [seed].
  static Map<int, List<CheckItem>> build(Iterable<Scene> scenes, {List<CheckItem> placement = const [], required int seed}) {
    final rnd = Random(seed);
    final byLevel = <int, List<(Scene, DialogueNode, Branch)>>{};
    // Every reply ever authored for a given line (the same line can appear in several scenes).
    final repliesTo = <String, Set<String>>{};
    for (final s in scenes) {
      for (final n in s.nodes.values) {
        (repliesTo[n.text.toLowerCase()] ??= {}).addAll(n.branches.map((b) => b.suggestion.toLowerCase()));
      }
    }
    for (final s in scenes) {
      if (s.id.contains('__as_')) continue;
      final lv = levelOfCefr(s.level);
      for (final n in s.nodes.values) {
        if (n.speaker == 'learner' || n.speaker == 'me' || !_usable(n.text)) continue;
        final ok = n.branches.where((b) => b.success && _usable(b.suggestion)).toList();
        if (ok.isEmpty) continue;
        byLevel.putIfAbsent(lv, () => []).add((s, n, ok[rnd.nextInt(ok.length)]));
      }
    }
    final out = <int, List<CheckItem>>{};
    for (var lv = 1; lv <= 5; lv++) {
      final pool = [...?byLevel[lv]]..shuffle(rnd);
      final items = <CheckItem>[];
      final pl = placement.where((p) => p.level == lv).toList();
      if (pl.isNotEmpty) items.add(pl[rnd.nextInt(pl.length)]);
      for (final (s, n, b) in pool) {
        if (items.length >= perLevel) break;
        // Distractors: success replies from OTHER scenes of the same level (never this scene, never the same text).
        final others = [
          for (final (s2, _, b2) in pool)
            if (s2.id != s.id && b2.suggestion.toLowerCase() != b.suggestion.toLowerCase() && !(repliesTo[n.text.toLowerCase()]?.contains(b2.suggestion.toLowerCase()) ?? false)) b2.suggestion,
        ];
        if (others.length < 2) continue;
        final d = <String>{};
        while (d.length < 2) {
          d.add(others[rnd.nextInt(others.length)]);
        }
        final choices = [b.suggestion, ...d]..shuffle(rnd);
        items.add(CheckItem(level: lv, prompt: n.text, speaker: n.speaker, answer: b.suggestion, choices: choices, kind: 'reply'));
      }
      items.shuffle(rnd);
      out[lv] = items;
    }
    return out;
  }

  static List<CheckResult> history(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      return [for (final e in jsonDecode(raw) as List) CheckResult.fromJson(Map<String, dynamic>.from(e as Map))];
    } catch (_) {
      return const [];
    }
  }

  static String addResult(String? raw, CheckResult r) {
    final h = [...history(raw), r];
    final keep = h.length > maxHistory ? h.sublist(h.length - maxHistory) : h;
    return jsonEncode([for (final e in keep) e.toJson()]);
  }

  /// "Before → now" line (EN, FA) comparing with the previous result.
  static (String, String) compare(List<CheckResult> h, String Function(int) cefr) {
    if (h.isEmpty) return ('', '');
    final now = h.last;
    if (h.length == 1) return ('First check: ${cefr(now.level)} (estimate). Take it again in a few weeks to see your progress.', 'اولین سنجش: ${cefr(now.level)} (تخمینی). چند هفته بعد دوباره بزن تا پیشرفتت را ببینی.');
    final prev = h[h.length - 2];
    if (now.level > prev.level) return ('Up from ${cefr(prev.level)} to ${cefr(now.level)} since ${prev.day}. Well done!', 'از ${cefr(prev.level)} به ${cefr(now.level)} رسیدی (از ${prev.day}). آفرین!');
    if (now.level < prev.level) return ('${cefr(now.level)} today (${cefr(prev.level)} on ${prev.day}). Short quizzes vary — keep going and check again.', 'امروز ${cefr(now.level)} (در ${prev.day}: ${cefr(prev.level)}). آزمون کوتاه نوسان دارد — ادامه بده و دوباره بسنج.');
    return ('Steady at ${cefr(now.level)} (same as ${prev.day}).', 'ثابت در ${cefr(now.level)} (مثل ${prev.day}).');
  }
}
