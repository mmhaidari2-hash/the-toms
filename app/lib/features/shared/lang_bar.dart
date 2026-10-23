import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/i18n/strings.dart';

/// Helper-language selector: every helper language, all shown the same way, in order of how many newcomers speak it.
/// Ready languages are plain chips; "beta" ones work but fall back to English where a line is not translated yet;
/// "coming soon" ones are listed but cannot be picked until their translation lands.
class HelperLangBar extends ConsumerStatefulWidget {
  /// Light text for dark backgrounds (onboarding); dark text on cream (settings).
  final bool dark;
  final String? selected;
  final ValueChanged<String>? onPick;
  const HelperLangBar({super.key, this.dark = false, this.selected, this.onPick});

  static List<Lang> get languages => helperLanguages;

  @override
  ConsumerState<HelperLangBar> createState() => _HelperLangBarState();
}

class _HelperLangBarState extends ConsumerState<HelperLangBar> {
  final _current = GlobalKey();

  bool get dark => widget.dark;
  ValueChanged<String>? get onPick => widget.onPick;

  @override
  void initState() {
    super.initState();
    // The chosen language is always in view when the bar opens, wherever it sits in the list.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _current.currentContext;
      if (c != null && mounted) Scrollable.ensureVisible(c, alignment: .3, duration: Duration.zero);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cur = widget.selected ?? ref.watch(progressProvider).lang;
    return SingleChildScrollView(
      key: const ValueKey('lang-bar'),
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final l in HelperLangBar.languages)
          Padding(key: l.code == cur ? _current : null, padding: const EdgeInsets.only(right: 8), child: _chip(context, ref, l, cur)),
      ]),
    );
  }

  Widget _chip(BuildContext context, WidgetRef ref, Lang l, String cur) {
    final st = langStatus(l.code);
    final on = cur == l.code;
    final soon = st == LangStatus.soon;
    final fg = on ? BL.ink : (dark ? Colors.white : BL.ink);
    return Semantics(
      button: !soon,
      enabled: !soon,
      label: '${l.name}${st == LangStatus.beta ? ', beta' : soon ? ', coming soon' : ''}',
      child: GestureDetector(
        key: ValueKey('lang-${l.code}'),
        onTap: soon
            ? () {
                ScaffoldMessenger.maybeOf(context)
                  ?..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text('${l.name} is being translated — coming soon.')));
              }
            : () => onPick != null ? onPick!(l.code) : ref.read(progressProvider.notifier).setLang(l.code),
        child: Opacity(
          opacity: soon ? .5 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: on ? BL.gold : (dark ? Colors.white.withValues(alpha: .08) : Colors.white),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: on ? BL.gold : (dark ? Colors.white24 : const Color(0x22000000))),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (on) const Padding(padding: EdgeInsets.only(right: 5), child: Icon(Icons.check_rounded, size: 16, color: BL.ink)),
              // The native name keeps its own direction; the chip row itself never flips.
              Text(l.native, textDirection: l.rtl ? TextDirection.rtl : TextDirection.ltr, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13.5)),
              Text(' · ${l.name}', textDirection: TextDirection.ltr, style: TextStyle(color: fg.withValues(alpha: .8), fontWeight: FontWeight.w600, fontSize: 12.5)),
              if (st != LangStatus.ready)
                Container(
                  key: ValueKey('lang-${l.code}-${soon ? 'soon' : 'beta'}'),
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: soon ? Colors.transparent : (on ? BL.ink : BL.gold.withValues(alpha: dark ? .9 : .25)),
                    border: soon ? Border.all(color: fg.withValues(alpha: .6), width: .8) : null,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(soon ? 'soon' : 'beta', textDirection: TextDirection.ltr, style: TextStyle(color: soon ? fg : (on ? BL.gold : BL.ink), fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: .3)),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
