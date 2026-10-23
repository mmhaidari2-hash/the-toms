import 'package:british_life/core/i18n/helper_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../shared/nav.dart';
import 'library_data.dart';
import 'library_gate.dart';
import '../grammar/grammar_data.dart';

const _wall = Color(0xFFF3E9D8), _wood = Color(0xFF8A5A2E), _woodDark = Color(0xFF5E3B1C);

/// The Library: painted wooden shelves, one per CEFR level; tap a book for its card, then read.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lib = ref.watch(libraryProvider);
    ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    final pad = MediaQuery.paddingOf(context);
    final books = lib.value, topics = ref.watch(grammarProvider).value, content = ref.watch(contentProvider).value;
    if (books == null || topics == null || content == null) return const NavLoading();
    final gate = LibraryGate(ctrl, content, topics, books, unlockAll: ref.read(progressProvider).unlockAll);
    return Scaffold(
      backgroundColor: _wall,
      body: ListView(
        key: const ValueKey('library-list'),
        padding: EdgeInsets.fromLTRB(0, pad.top + 6, 0, pad.bottom + 32),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [NavButtons(), SizedBox(width: 10), Text('THE LIBRARY', style: TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w800, color: BL.red))]),
              const SizedBox(height: 10),
              Text('Graded readers', style: BL.display(28)),
              Text(hl('کتاب‌های درجه‌بندی‌شده · داستان‌های کوتاه بریتانیایی با صدای راوی'), textDirection: helperDir, style: BL.fa(13)),
              const SizedBox(height: 6),
              Text(hl('${ctrl.booksDone} of ${books.length} books finished  ·  tap any word for its meaning'), style: const TextStyle(color: BL.muted, fontWeight: FontWeight.w600, fontSize: 12.5)),
            ]),
          ),
          for (final lv in Library.levels) _Shelf(level: lv, books: books.where((b) => b.level == lv.code).toList(), open: gate.shelfOpen(lv.code)),
        ],
      ),
    );
  }
}

class _Shelf extends ConsumerWidget {
  final LibraryLevel level;
  final List<Book> books;
  final bool open;
  const _Shelf({required this.level, required this.books, this.open = true});
  void _locked(BuildContext context) => _shelfLockedSnack(context, level.code);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(progressProvider.notifier);
    final empty = books.isEmpty;
    return Padding(
      key: ValueKey('shelf-${level.code}'),
      padding: const EdgeInsets.only(top: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(color: empty || !open ? BL.muted : BL.navy, borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (!open && !empty) const Padding(padding: EdgeInsets.only(right: 3), child: Icon(Icons.lock_rounded, size: 12, color: Colors.white)),
                Text(hl(level.code), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
              ]),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: hl(level.name), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: BL.ink)),
                  const TextSpan(text: '  '),
                  TextSpan(text: hl(level.nameFa), style: BL.fa(13)),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Text(hl(empty ? 'Coming soon · به‌زودی' : !open ? 'Locked · قفل' : '${books.where((b) => ctrl.bookDone(b.id)).length}/${books.length}'), key: ValueKey('shelf-status-${level.code}'), style: const TextStyle(color: BL.muted, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 172,
          child: Stack(children: [
            // the plank the books stand on
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 16,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFA9733F), _wood, _woodDark]),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 8, offset: const Offset(0, 5))],
                ),
              ),
            ),
            ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              children: [
                if (empty)
                  for (var i = 0; i < 6; i++) _Spine(i)
                else
                  for (final b in books)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: open
                          ? BookCover(b, done: ctrl.bookDone(b.id), onTap: () => showBookSheet(context, ref, b))
                          : Stack(alignment: Alignment.center, children: [
                              Opacity(opacity: .45, child: BookCover(b, onTap: () => _locked(context))),
                              const IgnorePointer(child: Icon(Icons.lock_rounded, color: Colors.white, size: 30)),
                            ]),
                    ),
              ],
            ),
          ]),
        ),
      ]),
    );
  }
}

void _shelfLockedSnack(BuildContext context, String code) {
  final (en, fa) = LibraryGate.why(code);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 4), content: Text(hl('$en\n$fa'), key: const ValueKey('shelf-locked-snack'))));
}

/// Placeholder spine for a shelf that is still being written.
class _Spine extends StatelessWidget {
  final int i;
  const _Spine(this.i);
  @override
  Widget build(BuildContext context) {
    const cols = [Color(0xFF9DB0A3), Color(0xFFC7A27C), Color(0xFF9AA4BF), Color(0xFFBF9A9A), Color(0xFFB8B08A), Color(0xFFA5A0B8)];
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: 30 + (i % 3) * 4.0,
        height: 120 + (i * 7 % 30),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(color: cols[i % cols.length].withValues(alpha: .55), borderRadius: BorderRadius.circular(3)),
      ),
    );
  }
}

/// A painted cover: a crop of a scene painting, the title on a band, a ribbon once finished.
class BookCover extends StatelessWidget {
  final Book book;
  final bool done;
  final VoidCallback? onTap;
  final double width;
  const BookCover(this.book, {super.key, this.done = false, this.onTap, this.width = 106});
  @override
  Widget build(BuildContext context) {
    final h = width * 1.48;
    return Align(
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        key: ValueKey('book-${book.id}'),
        onTap: onTap,
        child: Container(
          width: width,
          height: h,
          decoration: BoxDecoration(borderRadius: const BorderRadius.horizontal(left: Radius.circular(3), right: Radius.circular(8)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .28), blurRadius: 6, offset: const Offset(2, 3))]),
          clipBehavior: Clip.antiAlias,
          child: Stack(fit: StackFit.expand, children: [
            Image.asset(book.coverAsset, fit: BoxFit.cover, alignment: Alignment.center, errorBuilder: (_, _, _) => Container(color: BL.navy)),
            // spine shading
            const Positioned(left: 0, top: 0, bottom: 0, width: 9, child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0x66000000), Color(0x00000000)])))),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 18, 8, 8),
                decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0xE6142038)])),
                child: Text(hl(book.title), maxLines: 3, overflow: TextOverflow.ellipsis, style: BL.display(width / 8.2, color: Colors.white, w: FontWeight.w700).copyWith(height: 1.1)),
              ),
            ),
            Positioned(
              top: 6,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: BL.cream.withValues(alpha: .92), borderRadius: BorderRadius.circular(5)),
                child: Text(hl(book.level), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: BL.navy)),
              ),
            ),
            if (done)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  key: ValueKey('finished-${book.id}'),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: BL.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                  child: const Icon(Icons.check_rounded, size: 13, color: Colors.white),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

Future<void> showBookSheet(BuildContext context, WidgetRef ref, Book b) {
  final ctrl = ref.read(progressProvider.notifier);
  final next = ctrl.nextChapter(b.id, b.chapters.length);
  final started = ctrl.readScore(b.id, 0) != null;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: BL.cream,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        key: ValueKey('booksheet-${b.id}'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            BookCover(b, width: 84, done: ctrl.bookDone(b.id)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(hl(b.title), style: BL.display(21)),
                Text(hl(b.titleFa), textDirection: helperDir, style: BL.fa(14)),
                const SizedBox(height: 6),
                Text(hl('${b.level}  ·  ${b.chapters.length} chapters  ·  ${b.words} words  ·  ~${(b.words / 60).ceil()} min'), style: const TextStyle(color: BL.muted, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Text(hl(b.blurb), style: const TextStyle(fontSize: 15, height: 1.35, color: BL.ink)),
          const SizedBox(height: 4),
          Align(alignment: Alignment.centerRight, child: Text(hl(b.blurbFa), textDirection: helperDir, style: BL.fa(13.5))),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('book-read'),
              onPressed: () {
                Navigator.of(sheet).pop();
                context.push('/read/${b.id}?ch=$next');
              },
              style: FilledButton.styleFrom(backgroundColor: BL.red, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
              icon: const Icon(Icons.auto_stories_rounded),
              label: Text(hl(ctrl.bookDone(b.id) ? 'Read again' : (started ? 'Continue · chapter ${next + 1}' : 'Start reading')), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < b.chapters.length; i++)
            ListTile(
              key: ValueKey('chapter-$i'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(radius: 14, backgroundColor: BL.mist, child: Text(hl('${i + 1}'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: BL.ink))),
              title: Text(hl(b.chapters[i].title), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(hl(b.chapters[i].titleFa), textDirection: helperDir, style: BL.fa(12)),
              trailing: Builder(builder: (_) {
                final s = ctrl.readScore(b.id, i);
                if (s == null) return const Icon(Icons.chevron_right_rounded, color: BL.muted);
                return Text(hl('$s%'), style: TextStyle(fontWeight: FontWeight.w800, color: s >= Library.pass ? BL.green : BL.red));
              }),
              onTap: () {
                Navigator.of(sheet).pop();
                context.push('/read/${b.id}?ch=$i');
              },
            ),
        ]),
      ),
    ),
  );
}
