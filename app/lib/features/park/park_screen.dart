import 'package:british_life/core/i18n/helper_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../grammar/grammar_data.dart';
import '../library/library_data.dart';
import '../shared/nav.dart';
import 'park_data.dart';

const parkGreen = Color(0xFF3C7A3E), parkBg = Color(0xFFF1F5EC);
const gameIcons = {'match': Icons.timer_rounded, 'listen': Icons.hearing_rounded, 'spell': Icons.spellcheck_rounded, 'odd': Icons.category_rounded, 'build': Icons.view_week_rounded};

/// Park games hub: pick a level, then one of five quick games. Best scores per level.
class ParkScreen extends ConsumerWidget {
  const ParkScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    final topics = ref.watch(grammarProvider).value, content = ref.watch(contentProvider).value;
    if (topics == null || content == null) return const NavLoading();
    final gate = ParkGate(ctrl, content, topics, unlockAll: ref.read(progressProvider).unlockAll);
    var level = ctrl.pref('parkLevel', 'A1');
    if (!gate.levelOpen(level)) level = 'A1';
    final pw = ParkWords.of(ctrl, content.course, level);
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: parkBg,
      body: ListView(
        key: const ValueKey('park-hub'),
        padding: EdgeInsets.fromLTRB(16, pad.top + 6, 16, pad.bottom + 32),
        children: [
          const Row(
            children: [
              NavButtons(),
              SizedBox(width: 10),
              Icon(Icons.park_rounded, size: 16, color: parkGreen),
              SizedBox(width: 4),
              Text(
                'THE PARK',
                style: TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w800, color: parkGreen),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Park games', style: BL.display(30)),
          Text(
            hl('بازی‌های پارک · مرور سریع کلمه‌های درس‌هایت'),
            textDirection: helperDir,
            style: BL.fa(13, color: BL.muted),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final lv in Library.levels)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      key: ValueKey('park-level-${lv.code}'),
                      selected: lv.code == level,
                      showCheckmark: false,
                      avatar: gate.levelOpen(lv.code) ? null : const Icon(Icons.lock_rounded, size: 14, color: BL.muted),
                      label: Text(hl(lv.code)),
                      selectedColor: parkGreen,
                      backgroundColor: Colors.white,
                      side: BorderSide.none,
                      labelStyle: TextStyle(color: lv.code == level ? Colors.white : (gate.levelOpen(lv.code) ? BL.ink : BL.muted), fontWeight: FontWeight.w800),
                      onSelected: (_) {
                        if (gate.levelOpen(lv.code)) {
                          ctrl.setPref('parkLevel', lv.code);
                        } else {
                          final (en, fa) = ParkGate.why(lv.code);
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 4),
                                content: Text(hl('$en\n$fa'), key: const ValueKey('park-locked-snack')),
                              ),
                            );
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hl(pw.fromOpen >= pw.words.length ? '${pw.words.length} words from your $level lessons' : '${pw.fromOpen} words from your $level lessons + ${pw.words.length - pw.fromOpen} coming up next'),
            key: const ValueKey('park-words'),
            style: const TextStyle(fontSize: 12.5, color: BL.muted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          for (final g in Park.games) _GameCard(g: g, level: level, best: ctrl.parkBest(level, g.id)),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final ParkGame g;
  final String level;
  final int? best;
  const _GameCard({required this.g, required this.level, required this.best});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: ValueKey('park-game-${g.id}'),
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/park/$level/${g.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: parkGreen.withValues(alpha: .12),
                child: Icon(gameIcons[g.id], color: parkGreen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hl(g.name), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(hl(g.blurb), style: const TextStyle(fontSize: 12.5, color: BL.muted)),
                    Text(
                      hl(g.nameFa),
                      textDirection: helperDir,
                      style: BL.fa(12, color: BL.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Text(
                    hl(best == null ? '–' : '$best%'),
                    key: ValueKey('park-best-${g.id}'),
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: (best ?? 0) >= Park.pass ? parkGreen : BL.muted),
                  ),
                  const Text('best', style: TextStyle(fontSize: 10.5, color: BL.muted)),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
