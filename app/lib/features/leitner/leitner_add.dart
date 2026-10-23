import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/platform/voice.dart';
import 'glossary.dart';

/// Wraps the whole app: long-press (or drag-select) any text, then "Add to Leitner box" in the menu.
class LeitnerSelect extends StatefulWidget {
  final Widget child;
  const LeitnerSelect({super.key, required this.child});
  @override
  State<LeitnerSelect> createState() => _LeitnerSelectState();
}

class _LeitnerSelectState extends State<LeitnerSelect> {
  String _sel = '';
  late final OverlayEntry _entry = OverlayEntry(builder: (_) => _area());

  @override
  void didUpdateWidget(LeitnerSelect old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entry.markNeedsBuild();
    });
  }

  Widget _area() => SelectionArea(
        onSelectionChanged: (c) => _sel = c?.plainText ?? '',
        contextMenuBuilder: (ctx, st) {
          final text = _sel.trim();
          return AdaptiveTextSelectionToolbar.buttonItems(
            anchors: st.contextMenuAnchors,
            buttonItems: [
              if (text.isNotEmpty && text.length <= 80)
                ContextMenuButtonItem(
                  label: 'Add to Leitner box',
                  onPressed: () {
                    st.hideToolbar();
                    final nav = router.routerDelegate.navigatorKey.currentContext;
                    if (nav != null) showLeitnerSheet(nav, text);
                  },
                ),
              ...st.contextMenuButtonItems,
            ],
          );
        },
        child: widget.child,
      );

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);
}

String _src() {
  try {
    return router.routerDelegate.currentConfiguration.uri.toString();
  } catch (_) {
    return '';
  }
}

/// The add sheet: the phrase, its British audio, Persian meaning and the example line it came from.
Future<void> showLeitnerSheet(BuildContext context, String text, {String ex = '', String exSp = ''}) async {
  await Glossary.load();
  if (!context.mounted) return;
  final g = Glossary.lookup(text);
  final word = g != null && g.word.toLowerCase() == Glossary.clean(text).toLowerCase() ? g.word : Glossary.clean(text);
  final eg = ex.isNotEmpty ? Gloss(word, '', ex, exSp) : (g != null && g.ex.isNotEmpty ? g : Glossary.exampleFor(word));
  final fa = TextEditingController(text: g?.fa ?? '');
  final src = _src();
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: BL.cream,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheet) => Consumer(builder: (sheet, ref, _) {
      final have = ref.watch(progressProvider).leitnerBox[word];
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(sheet).bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.inventory_2_rounded, color: BL.green, size: 18),
              const SizedBox(width: 6),
              Text('LEITNER BOX · جعبهٔ لایتنر', style: BL.fa(11.5, color: BL.green, w: FontWeight.w800)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Text(word, key: const ValueKey('leitner-word'), style: BL.display(24))),
              if (Voice.has('narrator', word))
                IconButton.filledTonal(key: const ValueKey('leitner-say'), onPressed: () => Voice.say('narrator', word), icon: const Icon(Icons.volume_up_rounded)),
            ]),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('leitner-fa'),
              controller: fa,
              textDirection: TextDirection.rtl,
              style: BL.fa(16, color: BL.ink),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                hintText: 'معنی فارسی (اختیاری)',
                hintTextDirection: TextDirection.rtl,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            if (eg != null && eg.ex.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Expanded(child: Text('“${eg.ex}”', key: const ValueKey('leitner-ex'), style: const TextStyle(fontStyle: FontStyle.italic, height: 1.35))),
                  if (Voice.has(eg.exSp, eg.ex)) IconButton(onPressed: () => Voice.say(eg.exSp, eg.ex), icon: const Icon(Icons.play_circle_rounded, color: BL.navy)),
                ]),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('leitner-add'),
                style: FilledButton.styleFrom(backgroundColor: BL.green, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: have != null
                    ? null
                    : () {
                        ref.read(progressProvider.notifier).addToLeitner(word, fa.text, ex: eg?.ex ?? '', exSp: eg?.exSp ?? '', src: src);
                        Navigator.of(sheet).pop();
                        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                          content: Text('“$word” is in box 1 · به جعبهٔ لایتنر اضافه شد'),
                        ));
                      },
                icon: Icon(have != null ? Icons.check_rounded : Icons.add_rounded),
                label: Text(have != null ? 'Already in box ${have.box}' : 'Add to Leitner box', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
        ),
      );
    }),
  );
}
