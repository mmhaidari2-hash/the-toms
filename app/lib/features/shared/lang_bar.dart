import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/i18n/strings.dart';

/// Helper-language selector: every language whose UI strings AND lesson glosses are complete, shown the same way.
/// A language only appears here once it fully works (see [readyLanguages]).
class HelperLangBar extends ConsumerWidget {
  /// Light text for dark backgrounds (onboarding); dark text on cream (settings).
  final bool dark;
  /// Onboarding keeps the choice locally until the learner finishes; settings save straight away.
  final String? selected;
  final ValueChanged<String>? onPick;
  const HelperLangBar({super.key, this.dark = false, this.selected, this.onPick});

  static List<Lang> get languages => [for (final l in helperLanguages) if (readyLanguages.contains(l.code)) l];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cur = selected ?? ref.watch(progressProvider).lang;
    return SingleChildScrollView(
      key: const ValueKey('lang-bar'),
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final l in languages)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              key: ValueKey('lang-${l.code}'),
              onTap: () => onPick != null ? onPick!(l.code) : ref.read(progressProvider.notifier).setLang(l.code),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: cur == l.code ? BL.gold : (dark ? Colors.white.withValues(alpha: .08) : Colors.white),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: cur == l.code ? BL.gold : (dark ? Colors.white24 : const Color(0x22000000))),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (cur == l.code) const Padding(padding: EdgeInsets.only(right: 5), child: Icon(Icons.check_rounded, size: 16, color: BL.ink)),
                  Text('${l.native} · ${l.name}', style: TextStyle(color: cur == l.code ? BL.ink : (dark ? Colors.white : BL.ink), fontWeight: FontWeight.w700, fontSize: 13.5)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}
