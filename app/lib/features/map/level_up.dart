import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/models/course.dart';
import '../shared/widgets.dart';

/// Celebration shown once when the learner moves up a level (level test passed or every unit finished).
Future<void> showLevelUp(BuildContext context, int level) {
  final info = Course.levelInfo[level];
  final cefr = ProgressController.cefrOf(level);
  final prev = ProgressController.cefrOf(level - 1);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Level up',
    barrierColor: const Color(0xCC0B0806),
    pageBuilder: (ctx, _, _) => Stack(children: [
      const Positioned.fill(child: Confetti()),
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Material(
            key: ValueKey('level-up-$level'),
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFBF3E4), Color(0xFFF0DFC0)]),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: BL.gold, width: 2),
                boxShadow: BL.shadow(.5),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('🎉', style: TextStyle(fontSize: 46)),
                Text('Level up!', style: BL.display(32, color: BL.red)),
                Text('سطحت بالا رفت!', textDirection: TextDirection.rtl, style: BL.fa(15, color: BL.muted)),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _chip(prev, false),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Icon(Icons.arrow_forward_rounded, color: BL.ink)),
                  _chip(cefr, true),
                ]),
                const SizedBox(height: 14),
                Text("You passed $prev. ${info?.$2 ?? ''} is now open on the map, and your path continues at $cefr.",
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 14.5, height: 1.35, color: BL.ink, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('سطح $prev را گذراندی. ${info?.$3 ?? ''} روی نقشه باز شد و مسیرت از $cefr ادامه پیدا می‌کند.',
                    textAlign: TextAlign.center, textDirection: TextDirection.rtl, style: BL.fa(12.5, color: BL.muted)),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('level-up-go'),
                    style: FilledButton.styleFrom(backgroundColor: BL.red, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99))),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      context.push('/course?level=$level');
                    },
                    child: Text('Start $cefr', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ),
                TextButton(key: const ValueKey('level-up-later'), onPressed: () => Navigator.of(ctx).pop(), child: const Text('Back to the map')),
              ]),
            ),
          ),
        ),
      ),
    ]),
  );
}

Widget _chip(String t, bool on) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  decoration: BoxDecoration(color: on ? BL.red : const Color(0x22000000), borderRadius: BorderRadius.circular(14)),
  child: Text(t, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: on ? Colors.white : BL.muted)),
);
