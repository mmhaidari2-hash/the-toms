import '../data/repository.dart';
import '../models/dialogue_node.dart';
import 'pronunciation.dart';
import 'understand.dart';

/// One part the learner can take in a scene (owner t310, MASTERBOOK_GAPS item 2).
class RoleOption {
  final String id;
  /// The learner's usual part in this scene (the guest / "You", or the authored role of a variant scene).
  final bool usual;
  final bool playable;
  /// Lines the learner says in this role on the scene's path (0 for the usual part: they reply instead).
  final int lines;
  /// Lines other people say before this role's first line (0: the role opens the scene).
  final int before;
  /// Authored variant of the scene for this role (`<scene>__as_<role>`), used instead of the live swap.
  final String? variant;
  /// Why the role is hidden (EN, FA); null when playable.
  final (String, String)? reason;
  /// Hidden because the character does not speak in this scene at all.
  final bool absent;
  const RoleOption(this.id, {this.usual = false, required this.playable, this.lines = 0, this.before = 0, this.variant, this.reason, this.absent = false});
}

/// The path a scene takes when the learner plays [role]: every other part answers with its best (success-first)
/// reply, exactly as the conversation screen does it.
class RoleWalk {
  final List<DialogueNode> nodes;
  final int mine, before;
  final bool loops;
  const RoleWalk(this.nodes, this.mine, this.before, this.loops);
}

/// Full role switching: play as any family member (or anyone else who speaks) in any scene. The chosen
/// character's lines become what the learner says; everyone else, including the usual guest, speaks their own
/// recorded lines. Pure functions so every scene × role can be swept in a test.
abstract final class RoleSwitch {
  /// Who the learner usually is in [s].
  static String usualOf(Scene s) => s.playAs ?? s.guest ?? 'learner';

  /// The reply the usual part gives to [n] when the learner plays someone else.
  static Branch? partnerBranch(DialogueNode n) => n.branches.isEmpty ? null : n.branches.firstWhere((b) => b.success, orElse: () => n.branches.first);

  static RoleWalk walk(Scene s, String role, {int cap = 400}) {
    final out = <DialogueNode>[];
    final seen = <String>{};
    var mine = 0, before = -1;
    var n = s.nodes[s.start];
    while (n != null) {
      if (!seen.add(n.id) || out.length >= cap) return RoleWalk(out, mine, before < 0 ? 0 : before, true);
      out.add(n);
      if (n.speaker == role) {
        mine++;
        if (before < 0) before = out.length - 1;
      }
      final b = partnerBranch(n);
      n = b?.next == null ? null : s.nodes[b!.next];
    }
    return RoleWalk(out, mine, before < 0 ? 0 : before, false);
  }

  /// Speakers in [s] in the order they first talk (across every node, not only the main path).
  static List<String> speakers(Scene s) {
    final seen = <String>{};
    final order = <String>[];
    void add(String id) {
      if (seen.add(id)) order.add(id);
    }
    for (final n in walk(s, '').nodes) {
      add(n.speaker);
    }
    for (final n in s.nodes.values) {
      add(n.speaker);
    }
    return order;
  }

  /// Every part for [s]: the usual part first, then each speaker, then any family member who is not in the scene
  /// (hidden, with the reason). Hidden roles are never offered in the scene; the lesson card lists the reason.
  static List<RoleOption> optionsOf(Scene s, ContentBundle c) {
    final usual = usualOf(s);
    final out = <RoleOption>[RoleOption(usual, usual: true, playable: true)];
    final sp = speakers(s);
    final family = [for (final ch in c.characters) if (ch.family) ch.id];
    for (final id in {...sp, ...family}) {
      if (id == usual) continue;
      final known = id == 'learner' || c.characterOrNull(id) != null;
      final name = known ? (id == 'learner' ? 'You' : c.characterOrNull(id)!.name) : id;
      if (!known) {
        out.add(RoleOption(id, playable: false, reason: ('$id is not a character in the app', '$id در اپ شخصیت نیست')));
        continue;
      }
      if (!sp.contains(id)) {
        out.add(RoleOption(id, playable: false, absent: true, reason: ('$name is not in this scene', '$name در این صحنه نیست')));
        continue;
      }
      final w = walk(s, id);
      if (w.loops) {
        out.add(RoleOption(id, playable: false, reason: ('This scene goes round in a loop when $name is played', 'در نقش $name این صحنه دور خودش می‌چرخد')));
        continue;
      }
      if (w.mine == 0) {
        out.add(RoleOption(id, playable: false, reason: ('$name only speaks on a path you can\'t reach as $name', '$name فقط در مسیری حرف می‌زند که در این نقش به آن نمی‌رسی')));
        continue;
      }
      final variant = s.baseId == null && c.scenes.containsKey('${s.id}__as_$id') ? '${s.id}__as_$id' : null;
      out.add(RoleOption(id, playable: true, lines: w.mine, before: w.before, variant: variant));
    }
    return out;
  }

  /// One short EN+FA line for the hidden parts ("Not in this story: Ryan, Nicola…" plus any other reason).
  static (String, String)? hiddenSummary(List<RoleOption> options, ContentBundle c) {
    final absent = [for (final o in options) if (!o.playable && o.absent) c.characterOrNull(o.id)?.name ?? o.id];
    final other = [for (final o in options) if (!o.playable && !o.absent) o.reason!];
    if (absent.isEmpty && other.isEmpty) return null;
    return (
      [if (absent.isNotEmpty) 'Not in this story: ${absent.join(', ')}', ...other.map((r) => r.$1)].join('. '),
      [if (absent.isNotEmpty) 'در این داستان نیستند: ${absent.join('، ')}', ...other.map((r) => r.$2)].join('. '),
    );
  }

  static List<RoleOption> playable(Scene s, ContentBundle c) => [for (final o in optionsOf(s, c)) if (o.playable && !o.usual) o];

  /// Did the learner say [target] (the character's line)? Word-level pronunciation first; if that is short, the
  /// same tolerant offline understanding used for free replies (contractions, digits, UK/US spelling, slips, at
  /// least two distinctive words of the line, negation must agree).
  static (bool, int) judge(String target, String said) {
    final score = Pronunciation.bestOf([target], [said])?.$2.score ?? 0;
    if (score >= 60) return (true, score);
    final probe = DialogueNode(id: 'role', speaker: 'role', text: '', translations: const {}, newWords: const [], branches: [
      Branch(keywords: const [], suggestion: target, suggestionFa: '', trustDelta: 0, next: null),
    ]);
    final m = Understand.match(probe, said);
    return (m.branch != null && m.specific, score);
  }

  static String progressKey(Scene s, String role) => 'role:${s.baseId ?? s.id}:$role';
  static String trustKey(String role) => 'roleTrust:$role';

  /// "best%|runs" for this scene and role.
  static (int, int) readProgress(String raw) {
    final p = raw.split('|');
    return (int.tryParse(p.first) ?? 0, p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
  }

  /// Saves one finished run in a role (per profile, through the progress prefs): best score, runs, and trust as
  /// that character (one point per line said well).
  static void record(Scene s, String role, int ok, int total, String Function(String) pref, void Function(String, String) setPref) {
    if (total <= 0) return;
    final pct = (100 * ok / total).round();
    final (best, runs) = readProgress(pref(progressKey(s, role)));
    setPref(progressKey(s, role), '${pct > best ? pct : best}|${runs + 1}');
    setPref(trustKey(role), '${(int.tryParse(pref(trustKey(role))) ?? 0) + ok}');
  }
}
