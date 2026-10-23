import 'package:british_life/core/i18n/helper_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/data/repository.dart';
import '../shared/nav.dart';
import '../shared/widgets.dart';
import 'grammar_data.dart';

const chalk = Color(0xFF24443A), chalkLight = Color(0xFF2F5A4B), wood = Color(0xFF8A5A2E);

/// Unlocking: A1 is always open; a class opens when the previous class is passed, or when the
/// learner's course has already reached that level (placement); topics open one after another.
class GrammarGate {
  final ProgressController ctrl;
  final bool unlockAll;
  final ContentBundle? content;
  final List<GTopic> topics;
  GrammarGate(this.ctrl, this.content, this.topics, {this.unlockAll = false});
  List<GTopic> of(String code) => topics.where((t) => t.level == code).toList();
  bool classDone(String code) => of(code).isNotEmpty && of(code).every((t) => ctrl.grammarPassed(t.id));
  bool classOpen(String code) {
    if (of(code).isEmpty) return false;
    final i = Grammar.classes.indexWhere((c) => c.code == code);
    if (i <= 0 || unlockAll) return true;
    if (of(code).any((t) => ctrl.grammarPassed(t.id))) return true;
    if (classDone(Grammar.classes[i - 1].code)) return true;
    final c = content?.course;
    if (c == null) return false;
    final lv = Grammar.courseLevel(code);
    for (var u = 0; u < c.units.length; u++) {
      if (c.units[u].level >= lv && ctrl.unitOpen(c, u)) return true;
    }
    return false;
  }

  bool topicOpen(GTopic t) {
    if (!classOpen(t.level)) return false;
    final l = of(t.level), i = l.indexOf(t);
    return i == 0 || unlockAll || ctrl.grammarPassed(t.id) || ctrl.grammarPassed(l[i - 1].id);
  }
}

class SchoolScreen extends ConsumerWidget {
  /// Opened from the college on the map: B1–C1 are listed first.
  final bool college;
  const SchoolScreen({super.key, this.college = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(grammarProvider).value;
    final content = ref.watch(contentProvider).value;
    ref.watch(progressProvider);
    if (topics == null || content == null) return const NavLoading();
    final g = GrammarGate(ref.read(progressProvider.notifier), content, topics, unlockAll: ref.read(progressProvider).unlockAll);
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: BL.cream,
      body: ListView(
        key: const ValueKey('school-list'),
        padding: EdgeInsets.fromLTRB(20, pad.top + 6, 20, pad.bottom + 32),
        children: [
          const Row(children: [NavButtons(), SizedBox(width: 10), Text('GRAMMAR SCHOOL', style: TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w800, color: BL.red))]),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Avatar(content.character('ellis'), size: 58),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: BL.paper, borderRadius: const BorderRadius.only(topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)), boxShadow: BL.shadow()),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Mrs Ellis', style: TextStyle(fontWeight: FontWeight.w800, color: BL.green, fontSize: 13)),
                  const Text('Welcome to my classroom! Short lessons, lots of practice, and a mini test at the end of each topic.', style: TextStyle(fontSize: 13.5, height: 1.35, color: BL.ink)),
                  Text(hl('به کلاس من خوش آمدید! درس‌های کوتاه، تمرین زیاد و یک آزمونک در پایان هر موضوع.'), textDirection: helperDir, style: BL.fa(12)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 18),
          for (final c in [...Grammar.classes.where((c) => Grammar.atCollege(c.code) == college), ...Grammar.classes.where((c) => Grammar.atCollege(c.code) != college)]) ...[
            if (c.code == 'A1') ...[if (college) const SizedBox(height: 8), const _Campus("St Mary's School · Classes A1–A2", 'مدرسهٔ سنت مری · کلاس‌های A1 تا A2', key: ValueKey('campus-school'))],
            if (c.code == 'B1') ...[if (!college) const SizedBox(height: 8), const _Campus('Riverside Adult College · Classes B1–C1', 'کالج بزرگسالان ریورساید · کلاس‌های B1 تا C1', key: ValueKey('campus-college'))],
            _ClassCard(c, g),
          ],
        ],
      ),
    );
  }
}

class _Campus extends StatelessWidget {
  final String en, fa;
  const _Campus(this.en, this.fa, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
        child: Row(children: [
          const Icon(Icons.account_balance_rounded, color: BL.green, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(en, style: const TextStyle(fontWeight: FontWeight.w800, color: BL.green, fontSize: 14)),
              Text(hl(fa), textDirection: helperDir, style: BL.fa(11.5)),
            ]),
          ),
        ]),
      );
}

class _ClassCard extends StatelessWidget {
  final GClass c;
  final GrammarGate g;
  const _ClassCard(this.c, this.g);
  @override
  Widget build(BuildContext context) {
    final ts = g.of(c.code), soon = ts.isEmpty, open = g.classOpen(c.code);
    final done = ts.where((t) => g.ctrl.grammarPassed(t.id)).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: open ? 1 : .55,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('class-${c.code}'),
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              if (open) {
                context.push('/school/${c.code}');
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
                content: Text(hl(soon ? 'Class ${c.code} is coming soon · به‌زودی' : 'Pass Class ${Grammar.classes[Grammar.classes.indexOf(c) - 1].code} first, or reach this level in the course.')),
              ));
            },
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [chalkLight, chalk]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: wood, width: 5),
                boxShadow: BL.shadow(.15),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(hl('Class ${c.code} · ${c.nameFa}'), style: BL.display(22, color: Colors.white)),
                    Text(hl(c.name), style: const TextStyle(color: Color(0xFFCFE3D6), fontWeight: FontWeight.w700, fontSize: 12.5)),
                    const SizedBox(height: 6),
                    Text(hl(c.blurb), style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.3)),
                    const SizedBox(height: 8),
                    Text(hl(soon ? 'Coming soon · به‌زودی' : '$done of ${ts.length} topics passed'), style: const TextStyle(color: BL.gold, fontWeight: FontWeight.w800, fontSize: 12)),
                  ]),
                ),
                const SizedBox(width: 8),
                Icon(open ? (done == ts.length && !soon ? Icons.verified_rounded : Icons.chevron_right_rounded) : Icons.lock_rounded, color: open ? BL.gold : Colors.white70, size: 30),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// One classroom: its topics in order, with locks, ticks and best scores.
class ClassScreen extends ConsumerWidget {
  final String code;
  const ClassScreen({super.key, required this.code});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(grammarProvider).value;
    final content = ref.watch(contentProvider).value;
    ref.watch(progressProvider);
    if (topics == null || content == null) return const NavLoading();
    final g = GrammarGate(ref.read(progressProvider.notifier), content, topics, unlockAll: ref.read(progressProvider).unlockAll);
    final c = Grammar.classes.firstWhere((x) => x.code == code, orElse: () => Grammar.classes.first);
    final ts = g.of(c.code);
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: BL.cream,
      body: ListView(
        key: ValueKey('class-list-${c.code}'),
        padding: EdgeInsets.fromLTRB(20, pad.top + 6, 20, pad.bottom + 32),
        children: [
          const Row(children: [NavBack(fallback: '/school'), SizedBox(width: 10), Text('GRAMMAR SCHOOL', style: TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w800, color: BL.red))]),
          const SizedBox(height: 14),
          Text(hl('Class ${c.code} · ${c.nameFa}'), style: BL.display(28)),
          Text(hl(c.name), style: const TextStyle(color: BL.muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          for (var i = 0; i < ts.length; i++)
            Builder(builder: (_) {
              final t = ts[i], open = g.topicOpen(t), s = g.ctrl.grammarScore(t.id), passed = g.ctrl.grammarPassed(t.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: BL.paper,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: BL.mist)),
                  child: ListTile(
                    key: ValueKey('topic-${t.id}'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    leading: CircleAvatar(
                      backgroundColor: passed ? BL.green : (open ? chalk : BL.mist),
                      child: passed ? const Icon(Icons.check_rounded, color: Colors.white) : Text(hl('${i + 1}'), style: TextStyle(color: open ? Colors.white : BL.muted, fontWeight: FontWeight.w800)),
                    ),
                    title: Text(hl(t.title), style: TextStyle(fontWeight: FontWeight.w800, color: open ? BL.ink : BL.muted)),
                    subtitle: Text(hl(t.titleFa), textDirection: helperDir, style: BL.fa(12.5)),
                    trailing: open ? (s == null ? const Icon(Icons.play_circle_fill_rounded, color: BL.red, size: 30) : Text(hl('$s%'), style: TextStyle(fontWeight: FontWeight.w800, color: passed ? BL.green : BL.red))) : const Icon(Icons.lock_rounded, color: BL.muted),
                    onTap: () {
                      if (open) {
                        context.push('/grammar/${t.id}');
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, duration: Duration(seconds: 2), content: Text(hl('Pass the topic before this one first · اول موضوع قبلی را قبول شو'))));
                      }
                    },
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
