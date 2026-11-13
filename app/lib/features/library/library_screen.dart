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
import 'reading_state.dart';
import 'word_card.dart';

const _wall = Color(0xFFF3E9D8),
    _wood = Color(0xFF8A5A2E),
    _woodDark = Color(0xFF5E3B1C),
    _woodLight = Color(0xFFA9733F);

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
  final _pages = PageController();
  final _aisleBox = GlobalKey();
  final _scroll = ValueNotifier<double>(0);
  int aisle = 0;
  DateTime? _aisleSwipeAt;
  // list view filters
  String query = '', status = 'all', sort = 'level';
  String? section, level;

  @override
  void dispose() {
    _pages.dispose();
    _scroll.dispose();
    super.dispose();
  }

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
    return Scaffold(
      backgroundColor: _wall,
      bottomNavigationBar: listMode
          ? null
          : Material(
              color: const Color(0xF21F3B2E),
              elevation: 10,
              child: Padding(
                padding: EdgeInsets.fromLTRB(8, 6, 8, pad.bottom + 6),
                child: _AisleWalkBar(
                  sections: sections,
                  current: aisle,
                  onPrev: aisle > 0 ? () => _walkToAisle(aisle - 1) : null,
                  onNext: aisle < sections.length - 1
                      ? () => _walkToAisle(aisle + 1)
                      : null,
                  onEnter: () => _enterAisleBook(books, sections),
                ),
              ),
            ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.depth == 0 && n.metrics.axis == Axis.vertical)
            _scroll.value = n.metrics.pixels;
          if (n is OverscrollNotification)
            _onAisleOverscroll(n, sections.length);
          return false;
        },
        child: CustomScrollView(
          key: const ValueKey('library-list'),
          cacheExtent: 900,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, pad.top + 6, 12, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                          tooltip: listMode
                              ? 'Walk the library'
                              : 'List view (search & filter)',
                          onPressed: () => ctrl.setPref(
                            'libView',
                            listMode ? 'hall' : 'list',
                          ),
                          icon: Icon(
                            listMode
                                ? Icons.account_balance_rounded
                                : Icons.view_list_rounded,
                            color: BL.ink,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _Facade(
                booksDone: ctrl.booksDone,
                total: books.length,
                scroll: _scroll,
                onEnter: () => _walkToAisle(aisle),
              ),
            ),
            if (!listMode) ...[
              // Signs sit just after the street facade so the aisle map stays on a phone screen.
              SliverToBoxAdapter(
                child: _AisleSigns(
                  sections: sections,
                  current: aisle,
                  onTap: (i) => _walkToAisle(i),
                ),
              ),
              SliverToBoxAdapter(
                child: _FrontDesk(
                  books: books,
                  compact: MediaQuery.sizeOf(context).height < 520,
                  scroll: _scroll,
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  key: _aisleBox,
                  height: _aislePaneHeight(context, books, sections),
                  child: PageView(
                    key: const ValueKey('aisles'),
                    controller: _pages,
                    onPageChanged: (i) => setState(() => aisle = i),
                    children: [
                      for (final s in sections)
                        _Aisle(
                          section: s,
                          books: books
                              .where((b) => b.category == s.id)
                              .toList(),
                          gate: gate,
                          scrollShelves: _aisleNeedsInnerScroll(
                            context,
                            books,
                            sections,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: pad.bottom + 28)),
            ] else ...[
              SliverToBoxAdapter(child: _filters(sections)),
              _results(books, gate, pad.bottom),
            ],
          ],
        ),
      ),
    );
  }

  void _walkToAisle(int i) {
    final d = libraryMotion(context);
    // animateTo / ensureVisible assert duration > Duration.zero.
    if (_pages.hasClients) {
      if (d == Duration.zero) {
        _pages.jumpToPage(i);
      } else {
        _pages.animateToPage(i, duration: d, curve: Curves.easeOutCubic);
      }
    }
    void showAisle() {
      final ctx = _aisleBox.currentContext;
      if (ctx == null || !ctx.mounted) return;
      if (d == Duration.zero) {
        Scrollable.ensureVisible(ctx, alignment: 0.06);
      } else {
        Scrollable.ensureVisible(
          ctx,
          duration: d,
          curve: Curves.easeOutCubic,
          alignment: 0.06,
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showAisle();
      WidgetsBinding.instance.addPostFrameCallback((_) => showAisle());
    });
  }

  void _onAisleOverscroll(OverscrollNotification n, int count) {
    if (n.metrics.axis != Axis.horizontal) return;
    final now = DateTime.now();
    if (_aisleSwipeAt != null &&
        now.difference(_aisleSwipeAt!) < const Duration(milliseconds: 320))
      return;
    var dest = aisle;
    if (n.overscroll > 24 || n.velocity > 350) {
      dest = aisle + 1;
    } else if (n.overscroll < -24 || n.velocity < -350) {
      dest = aisle - 1;
    } else {
      return;
    }
    if (dest < 0 || dest >= count) return;
    _aisleSwipeAt = now;
    _walkToAisle(dest);
  }

  void _enterAisleBook(List<Book> books, List<LibraryCategory> sections) {
    if (aisle < 0 || aisle >= sections.length) return;
    final id = sections[aisle].id;
    final inAisle = books.where((b) => b.category == id).toList()
      ..sort((a, b) {
        final byLevel = a.levelIndex.compareTo(b.levelIndex);
        return byLevel != 0 ? byLevel : a.title.compareTo(b.title);
      });
    if (inAisle.isEmpty) return;
    showBookPullOut(context, ref, inAisle.first);
  }

  int _shelfCount(List<Book> books, List<LibraryCategory> sections) {
    var most = 1;
    for (final s in sections) {
      final n = Library.levels
          .where(
            (l) => books.any((b) => b.category == s.id && b.level == l.code),
          )
          .length;
      if (n > most) most = n;
    }
    return most;
  }

  double _aisleContentHeight(
    BuildContext context,
    List<Book> books,
    List<LibraryCategory> sections,
  ) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4);
    return 64 * scale +
        _shelfCount(books, sections) * libraryShelfHeight(context) +
        26;
  }

  /// Height reserved for the bookcase "room" on this screen.
  double _aisleRoomHeight(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final pad = MediaQuery.paddingOf(context);
    return (h - pad.top - pad.bottom - 24).clamp(240.0, h);
  }

  /// Cap the aisle to the phone viewport so walking stays on screen; shelves scroll inside.
  bool _aisleNeedsInnerScroll(
    BuildContext context,
    List<Book> books,
    List<LibraryCategory> sections,
  ) {
    return _aisleContentHeight(context, books, sections) >
        _aislePaneHeight(context, books, sections) + 0.5;
  }

  double _aislePaneHeight(
    BuildContext context,
    List<Book> books,
    List<LibraryCategory> sections,
  ) {
    final content = _aisleContentHeight(context, books, sections);
    final room = _aisleRoomHeight(context);
    if (content > room * 0.78) return (room * 0.78).clamp(220.0, content);
    return content;
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
class _Facade extends StatelessWidget {
  final int booksDone, total;
  final ValueNotifier<double> scroll;
  final VoidCallback onEnter;
  const _Facade({
    required this.booksDone,
    required this.total,
    required this.scroll,
    required this.onEnter,
  });
  @override
  Widget build(BuildContext context) {
    final short = MediaQuery.sizeOf(context).height < 500;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Semantics(
        button: true,
        label:
            'New Life Public Library, $total books, $booksDone finished. Walk in from the street.',
        child: GestureDetector(
          key: const ValueKey('library-enter'),
          onTap: onEnter,
          child: SizedBox(
            height: short
                ? 110
                : (MediaQuery.sizeOf(context).height < 740 ? 168 : 220),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: ValueListenableBuilder<double>(
                valueListenable: scroll,
                builder: (context, px, _) => Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      '$libraryArt/facade.webp',
                      key: const ValueKey('library-facade-art'),
                      fit: BoxFit.cover,
                      alignment: libraryParallax(context, px),
                      filterQuality: FilterQuality.medium,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x33000000),
                            Color(0x00000000),
                            Color(0xCC2A1A10),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, short ? 8 : 16, 16, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Spacer(),
                          Text(
                            'NEW LIFE PUBLIC LIBRARY',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BL
                                .display(
                                  short ? 15 : 20,
                                  color: const Color(0xFFF7E7C1),
                                  w: FontWeight.w700,
                                )
                                .copyWith(
                                  letterSpacing: 1.1,
                                  shadows: const [
                                    Shadow(
                                      color: Color(0xAA000000),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                          ),
                          Text(
                            hl('کتابخانهٔ عمومی'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: helperDir,
                            style: BL
                                .fa(
                                  short ? 12 : 14,
                                  color: const Color(0xFFF7E7C1),
                                )
                                .copyWith(
                                  shadows: const [
                                    Shadow(
                                      color: Color(0xAA000000),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hl('$total books · $booksDone finished'),
                            key: const ValueKey('library-count'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFEBD9B4),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (!short) ...[
                            const SizedBox(height: 4),
                            Text(
                              hl('Walk in · بفرمایید داخل'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFF7E7C1),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
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
          ),
        ),
      ),
    );
  }
}

/// Front desk: continue reading, new arrivals, your loans (in progress + finished).
class _FrontDesk extends ConsumerWidget {
  final List<Book> books;
  final bool compact;
  final ValueNotifier<double> scroll;
  const _FrontDesk({
    required this.books,
    required this.scroll,
    this.compact = false,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(progressProvider.notifier);
    final last = books.where((b) => b.id == ctrl.lastBook).firstOrNull;
    final arrivals = books
        .where(
          (b) =>
              b.audio == 'device' ||
              b.category != 'fiction' &&
                  b.category != 'children' &&
                  b.category != 'uklife',
        )
        .take(10)
        .toList();
    final loans = books.where((b) => ctrl.bookStarted(b)).toList()
      ..sort(
        (a, b) => ctrl.bookDone(a.id) ? 1 : (ctrl.bookDone(b.id) ? -1 : 0),
      );
    final hall = SizedBox(
      height: compact ? 88 : 120,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        child: ValueListenableBuilder<double>(
          valueListenable: scroll,
          builder: (context, px, _) => Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                '$libraryArt/hall.webp',
                key: const ValueKey('library-hall-art'),
                fit: BoxFit.cover,
                alignment: libraryParallax(context, px, factor: 0.0006),
                filterQuality: FilterQuality.medium,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x22000000), Color(0x66000000)],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                bottom: 8,
                right: 14,
                child: Text(
                  hl('Front hall · سرسرا'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFF7E7C1),
                    fontWeight: FontWeight.w800,
                    shadows: [Shadow(color: Color(0xAA000000), blurRadius: 6)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Container(
      key: const ValueKey('front-desk'),
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_woodLight, _wood],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .22),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          hall,
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.room_service_rounded,
                      color: Color(0xFFF7E7C1),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        hl('Front desk · میز امانت'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFF7E7C1),
                          fontWeight: FontWeight.w800,
                          letterSpacing: .4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (last != null)
                  _DeskCard(
                    key: const ValueKey('continue-reading'),
                    book: last,
                    label: 'Continue reading · ادامهٔ خواندن',
                    trailing: '${ctrl.readPercent(last)}%',
                    onTap: () => context.push('/read/${last.id}'),
                  )
                else
                  Text(
                    hl(
                      'Pick any book from the shelves below — your place is kept automatically · هر کتابی را از قفسه‌ها بردار؛ جایت خودکار نگه داشته می‌شود',
                    ),
                    maxLines: compact ? 2 : 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFF7E7C1),
                      fontSize: 12.5,
                    ),
                  ),
                if (arrivals.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    hl('New arrivals · تازه‌ها'),
                    style: const TextStyle(
                      color: Color(0xFFF7E7C1),
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 96,
                    child: ListView(
                      key: const ValueKey('new-arrivals'),
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final b in arrivals)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: _MiniCover(book: b),
                          ),
                      ],
                    ),
                  ),
                ],
                if (loans.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    hl(
                      'Your loans · امانت‌های تو (${loans.where((b) => ctrl.bookDone(b.id)).length} finished)',
                    ),
                    style: const TextStyle(
                      color: Color(0xFFF7E7C1),
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 96,
                    child: ListView(
                      key: const ValueKey('your-loans'),
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final b in loans)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: _MiniCover(
                              book: b,
                              done: ctrl.bookDone(b.id),
                              pct: ctrl.readPercent(b),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeskCard extends StatelessWidget {
  final Book book;
  final String label, trailing;
  final VoidCallback onTap;
  const _DeskCard({
    super.key,
    required this.book,
    required this.label,
    required this.trailing,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFFBF3E2),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            BookCover(book, width: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hl(label),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: BL.red,
                    ),
                  ),
                  Text(
                    hl(book.title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: BL.ink,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              hl(trailing),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: BL.green,
              ),
            ),
            const Icon(Icons.play_arrow_rounded, color: BL.ink),
          ],
        ),
      ),
    ),
  );
}

class _MiniCover extends ConsumerWidget {
  final Book book;
  final bool done;
  final int? pct;
  const _MiniCover({required this.book, this.done = false, this.pct});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      BookCover(
        book,
        width: 56,
        done: done,
        keyPrefix: 'desk',
        onTap: () => showBookPullOut(context, ref, book),
      ),
      if (pct != null && !done)
        SizedBox(
          width: 56,
          child: LinearProgressIndicator(
            value: pct! / 100,
            minHeight: 3,
            color: BL.gold,
            backgroundColor: Colors.white24,
          ),
        ),
    ],
  );
}

class _WalkBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool filled;
  const _WalkBtn({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.filled = false,
  });
  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: filled ? const Color(0xFFF1D58E) : Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                icon,
                color: enabled
                    ? (filled ? _woodDark : const Color(0xFFF7E7C1))
                    : const Color(0x66F7E7C1),
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Persistent left / right / enter controls so a phone can walk the aisles without hunting for a swipe.
class _AisleWalkBar extends StatelessWidget {
  final List<LibraryCategory> sections;
  final int current;
  final VoidCallback? onPrev, onNext, onEnter;
  const _AisleWalkBar({
    required this.sections,
    required this.current,
    required this.onPrev,
    required this.onNext,
    required this.onEnter,
  });
  @override
  Widget build(BuildContext context) {
    final s = sections[current];
    return Row(
      children: [
        _WalkBtn(
          key: const ValueKey('aisle-prev'),
          icon: Icons.chevron_left_rounded,
          tooltip: 'Previous aisle · راهروی قبلی',
          onTap: onPrev,
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hl(s.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFF7E7C1),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              Text(
                hl(s.nameFa),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                textDirection: helperDir,
                style: BL.fa(11, color: const Color(0xFFEBD9B4)),
              ),
            ],
          ),
        ),
        _WalkBtn(
          key: const ValueKey('aisle-enter'),
          icon: Icons.auto_stories_rounded,
          tooltip: 'Open a book · باز کردن کتاب',
          onTap: onEnter,
          filled: true,
        ),
        _WalkBtn(
          key: const ValueKey('aisle-next'),
          icon: Icons.chevron_right_rounded,
          tooltip: 'Next aisle · راهروی بعدی',
          onTap: onNext,
        ),
      ],
    );
  }
}

/// Hanging section signs: the mini-map of aisles. Tap one to walk to it.
class _AisleSigns extends StatelessWidget {
  final List<LibraryCategory> sections;
  final int current;
  final ValueChanged<int> onTap;
  const _AisleSigns({
    required this.sections,
    required this.current,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    return SizedBox(
      height: (74 * scale).clamp(74.0, 110.0),
      child: ListView(
        key: const ValueKey('aisle-map'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        children: [
          for (var i = 0; i < sections.length; i++)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Semantics(
                button: true,
                selected: i == current,
                label:
                    'Aisle ${i + 1}: ${sections[i].name}. ${sections[i].nameFa}',
                child: GestureDetector(
                  key: ValueKey('sign-${sections[i].id}'),
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: libraryMotion(context, 250),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: i == current
                          ? const Color(0xFF1F3B2E)
                          : const Color(0xFF2F4F40).withValues(alpha: .75),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFB89B5E),
                        width: i == current ? 2 : 1,
                      ),
                      boxShadow: i == current
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .25),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hl(
                            '${Library.dewey[sections[i].id] ?? ''}  ${sections[i].name}',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFF7E7C1),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          hl(sections[i].nameFa),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection: helperDir,
                          style: BL.fa(10.5, color: const Color(0xFFEBD9B4)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One aisle: the section's bookcase, one shelf per level (colour-coded label plate), books as spines.
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
