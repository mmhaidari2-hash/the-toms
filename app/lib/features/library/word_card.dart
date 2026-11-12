import 'package:british_life/core/i18n/helper_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/models/dialogue_node.dart';
import '../../core/platform/device_tts.dart';
import 'library_data.dart';

/// Words in [b] worth learning that are not in the learner's own words (Leitner box) yet.
List<String> newWordsFor(WidgetRef ref, Book b) {
  final box = ref.read(progressProvider).leitnerBox;
  return [for (final k in b.vocab) if (!box.containsKey(k) && (b.gloss[k] ?? '').isNotEmpty) k];
}

/// How many of [b]'s words are in the learner's Leitner box.
int savedFrom(WidgetRef ref, Book b) {
  final box = ref.read(progressProvider).leitnerBox;
  return b.vocab.where(box.containsKey).length;
}

/// Puts every new word of [b] in the Leitner box (box 1, due now). Returns how many were added.
int sendAllToLeitner(WidgetRef ref, Book b) {
  final words = newWordsFor(ref, b);
  ref.read(progressProvider.notifier).seeWords([for (final k in words) NewWord(k, b.gloss[k]!)]);
  return words.length;
}

/// Speaks a single word with the device voice (no recorded word clips exist); labelled as a device voice.
Future<void> sayWord(BuildContext context, String word) async {
  final ok = await DeviceTts.available && await DeviceTts.speak(word, rate: .85);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(hl('No device voice on this device · این دستگاه صدای متن‌خوان ندارد'))));
  }
}

/// Dictionary card for a tapped word: Persian, part of speech, simple English definition, example,
/// pronunciation (device voice) and "Add to Leitner box".
Future<void> showWordCard(BuildContext context, WidgetRef ref, {required Book book, required String surface, required String key, required String sentence, VoidCallback? onHearSentence}) {
  final fa = book.gloss[key] ?? '';
  final head = key.contains(' ') ? key : surface.replaceAll(RegExp(r"^\W+|\W+$"), '');
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: BL.cream,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheet) => Consumer(builder: (ctx, ref, _) {
      ref.watch(progressProvider);
      final senses = ref.watch(libraryDictProvider).value?.of(key) ?? const <DictSense>[];
      final saved = ref.read(progressProvider).leitnerBox.containsKey(key);
      final ctrl = ref.read(progressProvider.notifier);
      final canSave = !saved && fa.isNotEmpty && !fa.startsWith('اسم:');
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * .8),
          child: SingleChildScrollView(
            key: const ValueKey('word-sheet'),
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text(hl(head), style: BL.display(28))),
                IconButton.filledTonal(key: const ValueKey('word-say'), tooltip: 'Pronounce (device voice)', onPressed: () => sayWord(ctx, head), icon: const Icon(Icons.volume_up_rounded)),
              ]),
              if (senses.isNotEmpty) Text(hl(senses.map((s) => s.pos).toSet().join(' · ')), key: const ValueKey('word-pos'), style: const TextStyle(fontStyle: FontStyle.italic, color: BL.muted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(hl(fa.isEmpty ? '—' : fa), key: const ValueKey('word-fa'), textDirection: helperDir, textAlign: helperRtl ? TextAlign.right : TextAlign.left, style: BL.fa(20, color: BL.ink, w: FontWeight.w600)),
              for (final (n, s) in senses.indexed) ...[
                const SizedBox(height: 10),
                Text(hl('${s.pos}: ${s.def}'), key: ValueKey('word-def-$n'), style: const TextStyle(fontSize: 14.5, height: 1.35, color: BL.ink)),
                if (s.example.isNotEmpty) Text(hl('“${s.example}”'), style: const TextStyle(fontSize: 13.5, fontStyle: FontStyle.italic, color: BL.muted)),
              ],
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: BL.mist, borderRadius: BorderRadius.circular(12)),
                child: Text(hl(sentence), key: const ValueKey('word-context'), style: const TextStyle(fontSize: 13.5, height: 1.35, color: BL.ink)),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const ValueKey('word-save'),
                onPressed: canSave
                    ? () {
                        ctrl.addToLeitner(key, fa, ex: sentence, src: 'library:${book.id}');
                        Navigator.of(sheet).pop();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                          content: Text(hl('“$key” saved to your words · به واژه‌هایت اضافه شد')),
                        ));
                      }
                    : null,
                style: FilledButton.styleFrom(backgroundColor: BL.green, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                icon: Icon(saved ? Icons.check_rounded : Icons.bookmark_add_rounded),
                label: Text(hl(saved ? 'Already in your Leitner box · در جعبهٔ لایتنر هست' : 'Add to Leitner box · افزودن به جعبهٔ لایتنر'), style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              if (onHearSentence != null)
                TextButton.icon(
                  key: const ValueKey('word-hear-sentence'),
                  onPressed: () {
                    Navigator.of(sheet).pop();
                    onHearSentence();
                  },
                  icon: const Icon(Icons.record_voice_over_rounded),
                  label: Text(hl('Hear the sentence · شنیدن جمله')),
                ),
              if (senses.isNotEmpty) Text(hl(LibraryDict.attribution), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: BL.muted)),
            ]),
          ),
        ),
      );
    }),
  );
}

/// "You'll learn N new words" with the list and one tap to send them all to the Leitner box.
class NewWordsCard extends ConsumerWidget {
  final Book book;
  final bool dark;
  const NewWordsCard({super.key, required this.book, this.dark = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(progressProvider);
    final words = newWordsFor(ref, book);
    final fg = dark ? const Color(0xFFE8E2D4) : BL.ink;
    return Container(
      key: const ValueKey('new-words'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(color: BL.green.withValues(alpha: dark ? .22 : .10), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(Icons.auto_awesome_rounded, color: dark ? BL.gold : BL.green),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(hl(words.isEmpty ? 'All this book\'s words are in your Leitner box' : 'You\'ll learn ${words.length} new words'), key: const ValueKey('new-words-count'), style: TextStyle(fontWeight: FontWeight.w800, color: fg)),
            Text(hl(words.isEmpty ? 'همهٔ واژه‌های این کتاب در جعبهٔ لایتنر توست' : '${words.length} واژهٔ تازه یاد می‌گیری'), textDirection: helperDir, style: BL.fa(12.5, color: fg)),
          ]),
        ),
        if (words.isNotEmpty) TextButton(key: const ValueKey('new-words-open'), onPressed: () => showNewWords(context, ref, book), child: Text(hl('See list · فهرست'))),
      ]),
    );
  }
}

Future<void> showNewWords(BuildContext context, WidgetRef ref, Book b) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BL.cream,
      showDragHandle: true,
      builder: (sheet) => Consumer(builder: (ctx, ref, _) {
        ref.watch(progressProvider);
        final words = newWordsFor(ref, b);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * .8),
            child: Column(key: const ValueKey('new-words-sheet'), mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(hl('New words in ${b.title} · واژه‌های تازهٔ کتاب'), style: BL.display(20)),
              ),
              Flexible(
                child: ListView(shrinkWrap: true, padding: const EdgeInsets.symmetric(horizontal: 20), children: [
                  for (final k in words)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        Expanded(child: Text(hl(k), style: const TextStyle(fontWeight: FontWeight.w700, color: BL.ink))),
                        Flexible(child: Text(hl(b.gloss[k]), textDirection: helperDir, style: BL.fa(13.5))),
                      ]),
                    ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton.icon(
                  key: const ValueKey('send-all'),
                  onPressed: words.isEmpty
                      ? null
                      : () {
                          final n = sendAllToLeitner(ref, b);
                          Navigator.of(sheet).pop();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(hl('$n words sent to your Leitner box · $n واژه به جعبهٔ لایتنر رفت'))));
                        },
                  style: FilledButton.styleFrom(backgroundColor: BL.green, padding: const EdgeInsets.symmetric(vertical: 13)),
                  icon: const Icon(Icons.inventory_2_rounded),
                  label: Text(hl('Send all to Leitner box · همه به جعبهٔ لایتنر'), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ]),
          ),
        );
      }),
    );
