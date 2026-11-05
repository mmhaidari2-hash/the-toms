import 'package:british_life/core/i18n/helper_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../shared/nav.dart';
import 'grammar_data.dart';

/// "Common mistakes of Persian speakers": ten short lessons from Mrs Ellis,
/// always open (no class ladder), each with practice and a mini test.
class MistakesScreen extends ConsumerWidget {
  const MistakesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(mistakesProvider).value;
    ref.watch(progressProvider);
    if (topics == null) return const NavLoading();
    final ctrl = ref.read(progressProvider.notifier);
    final done = topics.where((t) => ctrl.grammarPassed(t.id)).length;
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: BL.cream,
      body: ListView(
        key: const ValueKey('mistakes-list'),
        padding: EdgeInsets.fromLTRB(20, pad.top + 6, 20, pad.bottom + 32),
        children: [
          const Row(children: [NavBack(fallback: '/school'), SizedBox(width: 10), Expanded(child: Text('COMMON MISTAKES', style: TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w800, color: BL.red)))]),
          const SizedBox(height: 12),
          Text('Mistakes Persian speakers often make', style: BL.display(24)),
          Text(hl('اشتباهات رایج فارسی‌زبان‌ها در انگلیسی'), textDirection: helperDir, style: BL.fa(14, color: BL.muted)),
          const SizedBox(height: 6),
          Text(hl('Short lessons on the mistakes that come from Persian: articles, he/she, word order, sounds and more. $done of ${topics.length} passed.'), key: const ValueKey('mistakes-progress'), style: const TextStyle(fontSize: 13.5, height: 1.35, color: BL.ink)),
          Text(hl('درس‌های کوتاه دربارهٔ اشتباه‌هایی که از فارسی می‌آیند: حرف تعریف، he/she، ترتیب کلمات، تلفظ و… $done از ${topics.length} گذرانده شده.'), textDirection: helperDir, style: BL.fa(12, color: BL.muted)),
          const SizedBox(height: 16),
          for (final (n, t) in topics.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: BL.paper,
                borderRadius: BorderRadius.circular(16),
                child: ListTile(
                  key: ValueKey('mistake-${t.id}'),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: CircleAvatar(
                    backgroundColor: ctrl.grammarPassed(t.id) ? BL.green : BL.mist,
                    child: ctrl.grammarPassed(t.id) ? const Icon(Icons.check_rounded, color: Colors.white) : Text('${n + 1}', style: const TextStyle(fontWeight: FontWeight.w800, color: BL.ink)),
                  ),
                  title: Text(hl(t.title), style: const TextStyle(fontWeight: FontWeight.w800, color: BL.ink, fontSize: 14.5)),
                  subtitle: Text(hl(t.titleFa), textDirection: helperDir, style: BL.fa(12, color: BL.muted)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: BL.muted),
                  onTap: () => context.push('/grammar/${t.id}'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
