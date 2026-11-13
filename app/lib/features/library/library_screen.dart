import 'package:british_life/core/i18n/helper_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../grammar/grammar_data.dart';
import '../shared/nav.dart';
import 'library_data.dart';
import 'library_gate.dart';
import 'library_walk.dart';
import 'reading_state.dart';
import 'word_card.dart';

const _wall = Color(0xFFF3E9D8), _woodDark = Color(0xFF5E3B1C);

/// Spine-label colour per CEFR level (like the coloured dots on a public-library spine label).
Color levelColor(String level) => switch (level) {
  'A1' => const Color(0xFF2E8B57),
  'A2' => const Color(0xFF14869A),
  'B1' => const Color(0xFF2F5DA8),
  'B2' => const Color(0xFF7A3FA0),
  _ => const Color(0xFFB0283A),
};

const _spineCols = [
  Color(0xFF7B2D26),
  Color(0xFF1F4E5F),
  Color(0xFF3D5A3A),
  Color(0xFF5B3A6B),
  Color(0xFF8C6A2F),
  Color(0xFF2C3E66),
  Color(0xFF6E3B2A),
  Color(0xFF34584F),
  Color(0xFF7A4B5E),
  Color(0xFF4A4A6A),
];

/// Zero-duration when the OS asks for reduced motion (accessibility).
Duration libraryMotion(BuildContext context, [int ms = 420]) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: ms);

/// Shelf height grows a little with large text, but stays on the shelf plank.
double libraryShelfHeight(BuildContext context) {
  final s = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.55);
  return (168 * s).clamp(148.0, 250.0);
}

const libraryArt = 'assets/library';

/// Painted aisle backdrop for a section (fiction, science, …).
String libraryAisleArt(String sectionId) => '$libraryArt/aisle_$sectionId.webp';

Alignment libraryParallax(
  BuildContext context,
  double pixels, {
  double factor = 0.00085,
}) {
  if (MediaQuery.disableAnimationsOf(context)) return Alignment.center;
  return Alignment(0, (pixels * factor).clamp(-0.42, 0.48));
}

/// The Library: a British public library you walk through. Front desk (continue reading, new arrivals, your
/// loans), section signs as a mini-map, one aisle per section (Dewey-style order) with a bookcase whose shelves
/// are arranged by level; tap a spine and the book slides out. A plain searchable list is one tap away.
/// Everything is data-driven: sections = [Library.categories], books = assets/data/library.json.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});
  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  // list view filters
  String query = '', status = 'all', sort = 'level';
  String? section, level;

  @override
  Widget build(BuildContext context) {
    final lib = ref.watch(libraryProvider);
    ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    final pad = MediaQuery.paddingOf(context);
    final books = lib.value,
        topics = ref.watch(grammarProvider).value,
        content = ref.watch(contentProvider).value;
    if (books == null || topics == null || content == null)
      return const NavLoading();
    final gate = LibraryGate(
      ctrl,
      content,
      topics,
      books,
      unlockAll: ref.read(progressProvider).gatesOpen,
    );
    final listMode = ctrl.pref('libView', 'hall') == 'list';
    final sections = [
      for (final s in Library.categories)
        if (books.any((b) => b.category == s.id)) s,
    ];
    if (listMode) {
      return Scaffold(
        backgroundColor: _wall,
        body: CustomScrollView(
          key: const ValueKey('library-list'),
          cacheExtent: 900,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, pad.top + 6, 12, 0),
                child: Row(
                  children: [
                    const NavButtons(),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'THE LIBRARY',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w800,
                          color: BL.red,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('library-view-toggle'),
                      tooltip: 'Walk the library',
                      onPressed: () => ctrl.setPref('libView', 'hall'),
                      icon: const Icon(
                        Icons.account_balance_rounded,
                        color: BL.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: _filters(sections)),
            _results(books, gate, pad.bottom),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF140E0A),
      body: LibraryWalk(
        books: books,
        sections: sections,
        gate: gate,
        onListView: () => ctrl.setPref('libView', 'list'),
        onOpenBook: (b) => showBookPullOut(context, ref, b),
        bookcase: (section, aisleBooks, {required scrollShelves}) => _Aisle(
          section: section,
          books: aisleBooks,
          gate: gate,
          scrollShelves: scrollShelves,
        ),
      ),
    );
  }

  Widget _filters(List<LibraryCategory> sections) {
    Widget chip(String label, bool on, VoidCallback tap, String key) => Padding(
      padding: const EdgeInsetsDirectional.only(end: 6),
      child: FilterChip(
        key: ValueKey(key),
        label: Text(hl(label)),
        selected: on,
        onSelected: (_) => tap(),
        showCheckmark: false,
        selectedColor: BL.navy.withValues(alpha: .15),
      ),
    );
    return Padding(
      key: const ValueKey('library-list-view'),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('library-search'),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: hl('Search title, author or topic · جستجو'),
              filled: true,
              fillColor: BL.paper,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => setState(() => query = v.trim().toLowerCase()),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                chip(
                  'All levels · همه',
                  level == null,
                  () => setState(() => level = null),
                  'f-level-all',
                ),
                for (final l in Library.levels)
                  chip(
                    l.code,
                    level == l.code,
                    () =>
                        setState(() => level = level == l.code ? null : l.code),
                    'f-level-${l.code}',
                  ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                chip(
                  'All sections · همهٔ بخش‌ها',
                  section == null,
                  () => setState(() => section = null),
                  'f-sec-all',
                ),
                for (final s in sections)
                  chip(
                    '${s.name} · ${s.nameFa}',
                    section == s.id,
                    () =>
                        setState(() => section = section == s.id ? null : s.id),
                    'f-sec-${s.id}',
                  ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (id, label) in const [
                  ('all', 'Any · همه'),
                  ('unread', 'Unread · نخوانده'),
                  ('reading', 'Reading · در حال خواندن'),
                  ('finished', 'Finished · تمام‌شده'),
                ])
                  chip(
                    label,
                    status == id,
                    () => setState(() => status = id),
                    'f-status-$id',
                  ),
                const SizedBox(width: 6),
                PopupMenuButton<String>(
                  key: const ValueKey('f-sort'),
                  initialValue: sort,
                  onSelected: (v) => setState(() => sort = v),
                  itemBuilder: (_) => [
                    for (final (id, label) in const [
                      ('level', 'Level · سطح'),
                      ('short', 'Shortest · کوتاه‌ترین'),
                      ('long', 'Longest · بلندترین'),
                      ('title', 'A–Z · الفبا'),
                    ])
                      PopupMenuItem(
                        value: id,
                        key: ValueKey('sort-$id'),
                        child: Text(hl(label)),
                      ),
                  ],
                  child: Chip(
                    avatar: const Icon(Icons.sort_rounded, size: 18),
                    label: Text(hl('Sort · مرتب‌سازی')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _results(List<Book> books, LibraryGate gate, double bottom) {
    final ctrl = ref.read(progressProvider.notifier);
    final list = filterBooks(
      books,
      ctrl,
      query: query,
      level: level,
      section: section,
      status: status,
      sort: sort,
    );
    if (list.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            hl('No books match · کتابی پیدا نشد'),
            key: const ValueKey('no-results'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, bottom + 24),
      sliver: SliverList.builder(
        itemCount: list.length,
        itemBuilder: (_, i) =>
            _BookRow(book: list[i], above: gate.aboveLevel(list[i])),
      ),
    );
  }
}

/// Search / filter / sort for the list view (pure, unit-tested).
List<Book> filterBooks(
  List<Book> books,
  ProgressController ctrl, {
  String query = '',
  String? level,
  String? section,
  String status = 'all',
  String sort = 'level',
}) {
  final q = query.toLowerCase();
  final out = books.where((b) {
    if (level != null && b.level != level) return false;
    if (section != null && b.category != section) return false;
    if (q.isNotEmpty) {
      final hay =
          '${b.title} ${b.titleFa} ${b.author} ${b.blurb} ${Library.category(b.category).name}'
              .toLowerCase();
      if (!hay.contains(q)) return false;
    }
    final done = ctrl.bookDone(b.id), started = ctrl.bookStarted(b);
    return switch (status) {
      'unread' => !started,
      'reading' => started && !done,
      'finished' => done,
      _ => true,
    };
  }).toList();
  int byLevel(Book a, Book b) => a.levelIndex.compareTo(b.levelIndex);
  out.sort(switch (sort) {
    'short' => (a, b) => a.words.compareTo(b.words),
    'long' => (a, b) => b.words.compareTo(a.words),
    'title' => (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    _ => (
      a,
      b,
    ) => byLevel(a, b) != 0 ? byLevel(a, b) : a.title.compareTo(b.title),
  });
  return out;
}

/// The library's painted front: a generated Edwardian civic facade you walk up to.
class _Aisle extends ConsumerWidget {
  final LibraryCategory section;
  final List<Book> books;
  final LibraryGate gate;
  final bool scrollShelves;
  const _Aisle({
    required this.section,
    required this.books,
    required this.gate,
    this.scrollShelves = false,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(progressProvider.notifier);
    final levels = [
      for (final l in Library.levels)
        if (books.any((b) => b.level == l.code)) l,
    ];
    final plate = Container(
      height: (44 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4))
          .clamp(44.0, 64.0),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          colors: [Color(0xFFCBA45A), Color(0xFFF1D58E), Color(0xFFB88C3A)],
        ),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: hl(section.name),
              style: BL.display(16, color: _woodDark, w: FontWeight.w800),
            ),
            const TextSpan(text: '   '),
            TextSpan(
              text: hl(section.nameFa),
              style: BL.fa(13, color: _woodDark, w: FontWeight.w700),
            ),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
    final shelves = [
      for (final l in levels)
        _Shelf(
          level: l,
          books: books.where((b) => b.level == l.code).toList(),
          gate: gate,
          ctrl: ctrl,
        ),
    ];
    final caseBody = scrollShelves
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              plate,
              Expanded(
                child: ListView(
                  key: ValueKey('aisle-scroll-${section.id}'),
                  padding: EdgeInsets.zero,
                  children: shelves,
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [plate, ...shelves],
          );
    return Semantics(
      label:
          '${section.name} aisle, ${section.nameFa}. Walk between the shelves.',
      child: Padding(
        key: ValueKey('aisle-${section.id}'),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  libraryAisleArt(section.id),
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, 0.15),
                  filterQuality: FilterQuality.medium,
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x33000000),
                        Color(0x66000000),
                        Color(0x99000000),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                child: caseBody,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Shelf extends ConsumerWidget {
  final LibraryLevel level;
  final List<Book> books;
  final LibraryGate gate;
  final ProgressController ctrl;
  const _Shelf({
    required this.level,
    required this.books,
    required this.gate,
    required this.ctrl,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final above = !gate.shelfOpen(level.code);
    return SizedBox(
      key: ValueKey('shelf-${books.first.category}-${level.code}'),
      height: libraryShelfHeight(context),
      child: Stack(
        children: [
          // back panel
          Positioned.fill(
            top: 8,
            bottom: 14,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF3E2714),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          // plank
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                image: const DecorationImage(
                  image: AssetImage('assets/library/shelf_wood.webp'),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .3),
                    blurRadius: 4,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
          // level label plate on the plank edge
          Positioned(
            left: 6,
            bottom: 1,
            child: Container(
              key: ValueKey(
                'shelf-label-${books.first.category}-${level.code}',
              ),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: levelColor(level.code),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                hl('${level.code} · ${level.name}${above ? '  ↑' : ''}'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Positioned.fill(
            bottom: 16,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
              children: [
                for (final b in books)
                  _Spine(
                    book: b,
                    done: ctrl.bookDone(b.id),
                    started: ctrl.bookStarted(b),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A book spine on the shelf: width from length, colour from the id, a coloured level sticker at the foot.
class _Spine extends ConsumerWidget {
  final Book book;
  final bool done, started;
  const _Spine({required this.book, this.done = false, this.started = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = book.id.hashCode.abs();
    final w = (24 + book.chapters.length * 3.0 + book.words / 600).clamp(
      26.0,
      48.0,
    );
    final ht = 112.0 + h % 22;
    final col = _spineCols[h % _spineCols.length];
    final all = ref.watch(libraryProvider).value ?? const <Book>[];
    final locked =
        all.isNotEmpty &&
        LibraryGate.isPremiumLocked(
          ref.read(progressProvider.notifier),
          book,
          all,
        );
    return Semantics(
      button: true,
      label:
          '${book.title}, ${book.level}, ${book.minutes} minutes${done ? ', finished' : ''}${locked ? ', Premium' : ''}',
      child: GestureDetector(
        key: ValueKey('book-${book.id}'),
        onTap: () => showBookPullOut(context, ref, book),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: w,
            height: ht,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: LinearGradient(
                colors: [
                  Color.lerp(col, Colors.black, .25)!,
                  col,
                  Color.lerp(col, Colors.white, .12)!,
                  col,
                  Color.lerp(col, Colors.black, .3)!,
                ],
                stops: const [0, .15, .45, .8, 1],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .35),
                  blurRadius: 2,
                  offset: const Offset(1, 1),
                ),
              ],
            ),
            child: Column(
              children: [
                if (locked)
                  Container(
                    key: ValueKey('lock-${book.id}'),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    decoration: const BoxDecoration(
                      color: Color(0xFFC9A44A),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(3),
                      ),
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      size: 9,
                      color: Color(0xFF1A1630),
                    ),
                  )
                else
                  Container(
                    height: 5,
                    margin: const EdgeInsets.only(top: 8),
                    color: const Color(0xFFD4B26A).withValues(alpha: .8),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        hl(book.title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: BL.display(
                          11.5,
                          color: const Color(0xFFF7E7C1),
                          w: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                if (done)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 13,
                    color: Color(0xFF9BE3B5),
                  )
                else if (started)
                  Container(width: 6, height: 12, color: BL.gold),
                // library spine label: white sticker with a coloured level band
                Container(
                  margin: const EdgeInsets.fromLTRB(3, 4, 3, 6),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                    border: Border(
                      top: BorderSide(color: levelColor(book.level), width: 4),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    hl(book.level),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: levelColor(book.level),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// List-view row: cover, title, author, level, minutes, chapters, progress.
class _BookRow extends ConsumerWidget {
  final Book book;
  final bool above;
  const _BookRow({required this.book, required this.above});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(progressProvider.notifier);
    final pct = ctrl.readPercent(book);
    return Card(
      key: ValueKey('row-${book.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      color: BL.paper,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showBookPullOut(context, ref, book),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              BookCover(
                book,
                width: 56,
                done: ctrl.bookDone(book.id),
                keyPrefix: 'rowcover',
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hl(book.title),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: BL.ink,
                      ),
                    ),
                    if (book.author.isNotEmpty)
                      Text(
                        hl(book.author),
                        style: const TextStyle(fontSize: 12, color: BL.muted),
                      ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _LevelBadge(book.level),
                        Text(
                          hl(
                            '${book.minutes} min · ${book.chapters.length} ch · ${Library.category(book.category).name}',
                          ),
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: BL.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (above)
                          Text(
                            hl('Above your level · بالاتر از سطح تو'),
                            style: const TextStyle(
                              fontSize: 11,
                              color: BL.red,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        if (LibraryGate.isPremiumLocked(
                          ctrl,
                          book,
                          ref.watch(libraryProvider).value ?? const <Book>[],
                        ))
                          Text(
                            key: ValueKey('row-lock-${book.id}'),
                            hl(
                              '${LibraryGate.premiumRibbon.$1} · ${LibraryGate.premiumRibbon.$2}',
                            ),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF8C6A2F),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                    if (pct > 0) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: pct / 100,
                          minHeight: 4,
                          color: BL.green,
                          backgroundColor: BL.mist,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  final String level;
  const _LevelBadge(this.level);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: levelColor(level),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      hl(level),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

/// A painted cover: a crop of a scene painting, the title on a band, the level, a tick once finished.
class BookCover extends StatelessWidget {
  final Book book;
  final bool done;
  final VoidCallback? onTap;
  final double width;
  final String keyPrefix;
  const BookCover(
    this.book, {
    super.key,
    this.done = false,
    this.onTap,
    this.width = 106,
    this.keyPrefix = 'cover',
  });
  @override
  Widget build(BuildContext context) {
    final h = width * 1.48;
    return GestureDetector(
      key: ValueKey('$keyPrefix-${book.id}'),
      onTap: onTap,
      child: Container(
        width: width,
        height: h,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(3),
            right: Radius.circular(8),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .28),
              blurRadius: 6,
              offset: const Offset(2, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              book.coverAsset,
              fit: BoxFit.cover,
              cacheWidth: (width * 3).round(),
              errorBuilder: (_, _, _) => Container(color: BL.navy),
            ),
            const Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 9,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0x66000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
            if (width >= 70)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 18, 8, 8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0xE6142038)],
                    ),
                  ),
                  child: Text(
                    hl(book.title),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: BL
                        .display(
                          width / 8.2,
                          color: Colors.white,
                          w: FontWeight.w700,
                        )
                        .copyWith(height: 1.1),
                  ),
                ),
              ),
            Positioned(top: 4, left: 8, child: _LevelBadge(book.level)),
            if (done)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  key: ValueKey('finished-${book.id}'),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: BL.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 11,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tap a spine: the book slides out of the shelf (pull-out with a turn), showing its cover, blurb, level,
/// length, progress and new words; then open it to read.
Future<void> showBookPullOut(BuildContext context, WidgetRef ref, Book b) {
  final reduce = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: .45),
    transitionDuration: reduce
        ? Duration.zero
        : const Duration(milliseconds: 420),
    pageBuilder: (ctx, _, _) => _PullOut(book: b),
    transitionBuilder: (ctx, anim, _, child) {
      if (reduce) return child;
      final t = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return AnimatedBuilder(
        animation: t,
        builder: (_, _) => Opacity(
          opacity: t.value.clamp(0, 1),
          child: Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()
              ..setEntry(3, 2, .0012)
              ..translateByDouble(0, (1 - t.value) * 160, 0, 1)
              ..rotateY((1 - t.value) * 1.1)
              ..scaleByDouble(.6 + .4 * t.value, .6 + .4 * t.value, 1, 1),
            child: child,
          ),
        ),
      );
    },
  );
}

class _PullOut extends ConsumerWidget {
  final Book book;
  const _PullOut({required this.book});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(progressProvider);
    final b = book;
    final ctrl = ref.read(progressProvider.notifier);
    final pos = ctrl.readPos(b.id);
    final started = ctrl.bookStarted(b), done = ctrl.bookDone(b.id);
    final pct = ctrl.readPercent(b);
    final all = ref.watch(libraryProvider).value ?? const <Book>[];
    final locked = all.isNotEmpty && LibraryGate.isPremiumLocked(ctrl, b, all);
    final media = MediaQuery.sizeOf(context);
    return SafeArea(
      child: Center(
        child: Material(
          key: ValueKey('booksheet-${b.id}'),
          color: BL.cream,
          elevation: 16,
          shadowColor: Colors.black54,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: media.width.clamp(0, 520) - 28,
            constraints: BoxConstraints(
              maxHeight: media.height * (media.height < 500 ? .94 : .86),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BookCover(b, width: 92, done: done, keyPrefix: 'pull'),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hl(b.title),
                              style: BL.display(21),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              hl(b.titleFa),
                              textDirection: helperDir,
                              style: BL.fa(14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (b.author.isNotEmpty)
                              Text(
                                hl(b.author),
                                key: const ValueKey('book-author'),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: BL.muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _LevelBadge(b.level),
                                Text(
                                  hl(
                                    '${b.chapters.length} chapters · ${b.words} words · ~${b.minutes} min',
                                  ),
                                  key: const ValueKey('book-meta'),
                                  style: const TextStyle(
                                    color: BL.muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hl(
                                '${Library.category(b.category).name} · ${Library.category(b.category).nameFa}',
                              ),
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: BL.muted,
                              ),
                            ),
                            Text(
                              hl(
                                b.deviceVoice
                                    ? 'Audio: device voice · صدای دستگاه'
                                    : 'Audio: recorded British voices · صدای ضبط‌شده',
                              ),
                              key: const ValueKey('book-audio'),
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: BL.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    hl(b.blurb),
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      color: BL.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hl(b.blurbFa),
                    textDirection: helperDir,
                    style: BL.fa(13.5),
                  ),
                  if (b.original || b.source.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      hl(
                        b.original
                            ? 'Original text (unabridged) · متن اصلی'
                            : 'Graded adaptation · بازنویسی ساده‌شده',
                      ),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: BL.navy,
                      ),
                    ),
                  ],
                  if (started) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: pct / 100,
                              minHeight: 5,
                              color: BL.green,
                              backgroundColor: BL.mist,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          hl('$pct%'),
                          key: const ValueKey('book-pct'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: BL.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  NewWordsCard(book: b),
                  if (locked) ...[
                    Text(
                      key: const ValueKey('premium-notice'),
                      hl(LibraryGate.premiumNotice.$1),
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: BL.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hl(LibraryGate.premiumNotice.$2),
                      textDirection: helperDir,
                      style: BL.fa(13),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: const ValueKey('premium-cta'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.push('/premium?reason=library');
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFC9A44A),
                        foregroundColor: const Color(0xFF1A1630),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: const Icon(Icons.lock_rounded),
                      label: Text(
                        hl(
                          '${LibraryGate.premiumRibbon.$1} · ${LibraryGate.premiumRibbon.$2}',
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ] else ...[
                    FilledButton.icon(
                      key: const ValueKey('book-read'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.push(
                          done || pos == null
                              ? '/read/${b.id}?ch=0'
                              : '/read/${b.id}',
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: BL.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: const Icon(Icons.auto_stories_rounded),
                      label: Text(
                        hl(
                          done
                              ? 'Read again'
                              : (pos != null
                                    ? 'Continue · chapter ${pos.$1 + 1}'
                                    : 'Start reading'),
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < b.chapters.length; i++)
                      ListTile(
                        key: ValueKey('chapter-$i'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: BL.mist,
                          child: Text(
                            hl('${i + 1}'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: BL.ink,
                            ),
                          ),
                        ),
                        title: Text(
                          hl(b.chapters[i].title),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          hl(b.chapters[i].titleFa),
                          textDirection: helperDir,
                          style: BL.fa(12),
                        ),
                        trailing: Builder(
                          builder: (_) {
                            final s = ctrl.readScore(b.id, i);
                            if (s == null)
                              return const Icon(
                                Icons.chevron_right_rounded,
                                color: BL.muted,
                              );
                            return Text(
                              hl('$s%'),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: s >= Library.pass ? BL.green : BL.red,
                              ),
                            );
                          },
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          context.push('/read/${b.id}?ch=$i');
                        },
                      ),
                  ],
                  if (b.source.isNotEmpty)
                    Text(
                      hl('Source: ${b.source}'),
                      key: const ValueKey('book-source'),
                      style: const TextStyle(fontSize: 10.5, color: BL.muted),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
