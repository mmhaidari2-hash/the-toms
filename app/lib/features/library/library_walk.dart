import 'package:british_life/core/i18n/helper_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../shared/nav.dart';
import 'library_data.dart';
import 'library_gate.dart';
import 'reading_state.dart';

const _art = 'assets/library';
String _aisleArt(String id) => '$_art/aisle_$id.webp';
Duration _motion(BuildContext context, [int ms = 420]) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: ms);

enum LibraryRoom { street, hall, aisle }

/// First-person walk through the painted library: street door, front hall, then one aisle at a time.
class LibraryWalk extends ConsumerStatefulWidget {
  final List<Book> books;
  final List<LibraryCategory> sections;
  final LibraryGate gate;
  final Widget Function(
    LibraryCategory section,
    List<Book> books, {
    required bool scrollShelves,
  })
  bookcase;
  final void Function(Book book) onOpenBook;
  final VoidCallback onListView;
  const LibraryWalk({
    super.key,
    required this.books,
    required this.sections,
    required this.gate,
    required this.bookcase,
    required this.onOpenBook,
    required this.onListView,
  });
  @override
  ConsumerState<LibraryWalk> createState() => _LibraryWalkState();
}

class _LibraryWalkState extends ConsumerState<LibraryWalk> {
  LibraryRoom room = LibraryRoom.street;
  int aisle = 0;
  bool shelvesOpen = false;
  DateTime? _swipeAt;

  LibraryCategory get _section => widget.sections.isEmpty
      ? Library.categories.first
      : widget.sections[aisle.clamp(0, widget.sections.length - 1)];

  List<Book> get _aisleBooks =>
      widget.books.where((b) => b.category == _section.id).toList();

  Duration _d([int ms = 420]) => _motion(context, ms);

  void _go(LibraryRoom next, {int? toAisle, bool? shelves}) {
    setState(() {
      if (toAisle != null) aisle = toAisle.clamp(0, widget.sections.length - 1);
      room = next;
      shelvesOpen =
          shelves ?? (next == LibraryRoom.aisle ? shelvesOpen : false);
      if (next != LibraryRoom.aisle) shelvesOpen = false;
    });
  }

  void _forward() {
    switch (room) {
      case LibraryRoom.street:
        _go(LibraryRoom.hall);
      case LibraryRoom.hall:
        _go(LibraryRoom.aisle, shelves: false);
      case LibraryRoom.aisle:
        if (!shelvesOpen) {
          setState(() => shelvesOpen = true);
        } else {
          _openFirstBook();
        }
    }
  }

  void _back() {
    if (shelvesOpen) {
      setState(() => shelvesOpen = false);
      return;
    }
    switch (room) {
      case LibraryRoom.aisle:
        _go(LibraryRoom.hall);
      case LibraryRoom.hall:
        _go(LibraryRoom.street);
      case LibraryRoom.street:
        break;
    }
  }

  void _turn(int delta) {
    if (widget.sections.isEmpty) return;
    if (room == LibraryRoom.street) return;
    final next = (aisle + delta).clamp(0, widget.sections.length - 1);
    if (next == aisle && room == LibraryRoom.aisle) return;
    _go(LibraryRoom.aisle, toAisle: next, shelves: shelvesOpen);
  }

  void _openFirstBook() {
    final books = [..._aisleBooks]
      ..sort((a, b) {
        final byLevel = a.levelIndex.compareTo(b.levelIndex);
        return byLevel != 0 ? byLevel : a.title.compareTo(b.title);
      });
    if (books.isEmpty) return;
    widget.onOpenBook(books.first);
  }

  void _onSwipe(DragEndDetails d, {required Axis axis}) {
    final now = DateTime.now();
    if (_swipeAt != null &&
        now.difference(_swipeAt!) < const Duration(milliseconds: 280))
      return;
    final v = d.primaryVelocity ?? 0;
    if (v.abs() < 280) return;
    _swipeAt = now;
    if (axis == Axis.horizontal) {
      if (v < 0) {
        _turn(1);
      } else {
        _turn(-1);
      }
    } else {
      if (v < 0) {
        _forward();
      } else {
        _back();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    ref.watch(progressProvider);
    final art = switch (room) {
      LibraryRoom.street => '$_art/facade.webp',
      LibraryRoom.hall => '$_art/hall.webp',
      LibraryRoom.aisle => _aisleArt(_section.id),
    };
    final align = switch (room) {
      LibraryRoom.street => Alignment.center,
      LibraryRoom.hall => const Alignment(-0.62, 0),
      LibraryRoom.aisle => Alignment.center,
    };
    final artKey = switch (room) {
      LibraryRoom.street => const ValueKey('library-facade-art'),
      LibraryRoom.hall => const ValueKey('library-hall-art'),
      LibraryRoom.aisle => const ValueKey('library-aisle-art'),
    };
    final roomKey = switch (room) {
      LibraryRoom.street => const ValueKey('library-street'),
      LibraryRoom.hall => const ValueKey('library-hall'),
      LibraryRoom.aisle => ValueKey('aisle-${_section.id}'),
    };

    return Stack(
      key: const ValueKey('library-list'),
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF140E0A)),
        GestureDetector(
          onHorizontalDragEnd: (d) => _onSwipe(d, axis: Axis.horizontal),
          onVerticalDragEnd: (d) => _onSwipe(d, axis: Axis.vertical),
          child: AnimatedSwitcher(
            duration: _d(),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: Image.asset(
              art,
              key: artKey,
              fit: BoxFit.cover,
              alignment: align,
              width: double.infinity,
              height: double.infinity,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 160,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xCC140E0A), Color(0x00140E0A)],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 8,
          top: pad.top + 2,
          child: Row(
            children: [
              const NavButtons(),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'THE LIBRARY',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFF7E7C1),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('library-view-toggle'),
                tooltip: 'List view (search & filter)',
                onPressed: widget.onListView,
                icon: const Icon(
                  Icons.view_list_rounded,
                  color: Color(0xFFF7E7C1),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          key: roomKey,
          left: 0,
          right: 0,
          top: pad.top + 48,
          bottom: pad.bottom + 86,
          child: const SizedBox.expand(),
        ),
        if (room == LibraryRoom.street)
          Positioned(
            left: 24,
            right: 24,
            bottom: pad.bottom + 100,
            child: _WalkCta(
              key: const ValueKey('library-enter'),
              icon: Icons.login_rounded,
              label: 'Walk in · بفرمایید داخل',
              onTap: _forward,
            ),
          ),
        if (room == LibraryRoom.hall) ...[
          Positioned(
            left: 8,
            width: MediaQuery.sizeOf(context).width * 0.46,
            top: pad.top + 120,
            bottom: pad.bottom + 120,
            child: _Hotspot(
              key: const ValueKey('hall-door'),
              label: 'Enter the aisles · ورود به راهروها',
              onTap: () => _go(LibraryRoom.aisle, shelves: false),
            ),
          ),
          Positioned(
            right: 16,
            left: MediaQuery.sizeOf(context).width * 0.42,
            bottom: pad.bottom + 110,
            child: _HallDesk(
              books: widget.books,
              onOpenBook: widget.onOpenBook,
            ),
          ),
        ],
        if (room == LibraryRoom.aisle) ...[
          Positioned(
            left: 16,
            right: 16,
            top: pad.top + 52,
            child: _AisleBanner(section: _section),
          ),
          if (!shelvesOpen) ...[
            Positioned(
              left: 0,
              width: 78,
              top: pad.top + 130,
              bottom: pad.bottom + 120,
              child: _Hotspot(
                key: const ValueKey('aisle-shelves-left'),
                label: 'Browse the shelves · دیدن قفسه‌ها',
                onTap: () => setState(() => shelvesOpen = true),
              ),
            ),
            Positioned(
              right: 0,
              width: 78,
              top: pad.top + 130,
              bottom: pad.bottom + 120,
              child: _Hotspot(
                key: const ValueKey('aisle-shelves-right'),
                label: 'Browse the shelves · دیدن قفسه‌ها',
                onTap: () => setState(() => shelvesOpen = true),
              ),
            ),
            Positioned(
              left: 56,
              right: 56,
              bottom: pad.bottom + 100,
              child: _WalkCta(
                key: const ValueKey('aisle-shelves'),
                icon: Icons.menu_book_rounded,
                label: 'Browse the shelves · دیدن قفسه‌ها',
                onTap: () => setState(() => shelvesOpen = true),
              ),
            ),
          ],
        ],
        if (shelvesOpen)
          Positioned(
            left: 0,
            right: 0,
            top: MediaQuery.sizeOf(context).height * 0.22,
            bottom: pad.bottom + 78,
            child: _ShelfPanel(
              section: _section,
              onClose: () => setState(() => shelvesOpen = false),
              onOpenBook: _openFirstBook,
              child: widget.bookcase(
                _section,
                _aisleBooks,
                scrollShelves: true,
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _WalkPad(
            room: room,
            section: _section,
            canLeft: room != LibraryRoom.street && aisle > 0,
            canRight:
                room != LibraryRoom.street &&
                aisle < widget.sections.length - 1,
            canBack: room != LibraryRoom.street || shelvesOpen,
            canForward: true,
            shelvesOpen: shelvesOpen,
            onLeft: () => _turn(-1),
            onRight: () => _turn(1),
            onBack: _back,
            onForward: _forward,
          ),
        ),
      ],
    );
  }
}

class _WalkCta extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _WalkCta({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Material(
        color: const Color(0xE21F3B2E),
        elevation: 8,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: const Color(0xFFF1D58E)),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    hl(label),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFF7E7C1),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Hotspot extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Hotspot({super.key, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: const SizedBox.expand(),
    ),
  );
}

class _AisleBanner extends StatelessWidget {
  final LibraryCategory section;
  const _AisleBanner({required this.section});
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0xFFCBA45A), Color(0xFFF1D58E), Color(0xFFB88C3A)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: hl(section.name),
              style: BL.display(
                16,
                color: const Color(0xFF5E3B1C),
                w: FontWeight.w800,
              ),
            ),
            const TextSpan(text: '   '),
            TextSpan(
              text: hl(section.nameFa),
              style: BL.fa(
                13,
                color: const Color(0xFF5E3B1C),
                w: FontWeight.w700,
              ),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    ),
  );
}

class _HallDesk extends ConsumerWidget {
  final List<Book> books;
  final void Function(Book book) onOpenBook;
  const _HallDesk({required this.books, required this.onOpenBook});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(progressProvider.notifier);
    ref.watch(progressProvider);
    final last = books.where((b) => b.id == ctrl.lastBook).firstOrNull;
    final loans = books.where(ctrl.bookStarted).toList()
      ..sort(
        (a, b) => ctrl.bookDone(a.id) ? 1 : (ctrl.bookDone(b.id) ? -1 : 0),
      );
    return Material(
      key: const ValueKey('front-desk'),
      color: const Color(0xE22A1A10),
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hl('Front desk · میز امانت'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFF7E7C1),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            if (last != null)
              InkWell(
                key: const ValueKey('continue-reading'),
                onTap: () => context.push('/read/${last.id}'),
                child: Text(
                  hl('Continue: ${last.title}'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFF1D58E),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              )
            else
              Text(
                hl('Pick a book from the aisles · کتاب را از راهروها بردار'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFEBD9B4),
                  fontSize: 12.5,
                ),
              ),
            if (loans.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                hl(
                  'Your loans · امانت‌های تو (${loans.where((b) => ctrl.bookDone(b.id)).length} finished)',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFF7E7C1),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 64,
                child: ListView(
                  key: const ValueKey('your-loans'),
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final b in loans)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: InkWell(
                          onTap: () => onOpenBook(b),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.asset(
                                  b.coverAsset,
                                  width: 44,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    width: 44,
                                    height: 64,
                                    color: const Color(0xFF3B2A1A),
                                  ),
                                ),
                              ),
                              if (ctrl.bookDone(b.id))
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: Container(
                                    key: ValueKey('finished-${b.id}'),
                                    padding: const EdgeInsets.all(1),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF2E8B57),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check_rounded,
                                      size: 10,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShelfPanel extends StatelessWidget {
  final LibraryCategory section;
  final Widget child;
  final VoidCallback onClose, onOpenBook;
  const _ShelfPanel({
    required this.section,
    required this.child,
    required this.onClose,
    required this.onOpenBook,
  });
  @override
  Widget build(BuildContext context) => Material(
    key: const ValueKey('shelf-panel'),
    color: const Color(0xF21A120C),
    elevation: 16,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: [
              IconButton(
                key: const ValueKey('shelves-close'),
                tooltip: 'Close shelves · بستن قفسه‌ها',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, color: Color(0xFFF7E7C1)),
              ),
              Expanded(
                child: Text(
                  hl('${section.name} · ${section.nameFa}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFF7E7C1),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('aisle-enter'),
                tooltip: 'Open a book · باز کردن کتاب',
                onPressed: onOpenBook,
                icon: const Icon(
                  Icons.auto_stories_rounded,
                  color: Color(0xFFF1D58E),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    ),
  );
}

class _WalkPad extends StatelessWidget {
  final LibraryRoom room;
  final LibraryCategory section;
  final bool canLeft, canRight, canBack, canForward, shelvesOpen;
  final VoidCallback onLeft, onRight, onBack, onForward;
  const _WalkPad({
    required this.room,
    required this.section,
    required this.canLeft,
    required this.canRight,
    required this.canBack,
    required this.canForward,
    required this.shelvesOpen,
    required this.onLeft,
    required this.onRight,
    required this.onBack,
    required this.onForward,
  });
  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final forwardLabel = switch (room) {
      LibraryRoom.street => 'Walk in · بفرمایید داخل',
      LibraryRoom.hall => 'Enter the aisles · ورود به راهروها',
      LibraryRoom.aisle =>
        shelvesOpen
            ? 'Open a book · باز کردن کتاب'
            : 'Browse the shelves · دیدن قفسه‌ها',
    };
    final backLabel = shelvesOpen
        ? 'Close shelves · بستن قفسه‌ها'
        : room == LibraryRoom.aisle
        ? 'Back to the hall · بازگشت به سرسرا'
        : 'Back to the street · بازگشت به خیابان';
    return Material(
      color: const Color(0xF21F3B2E),
      elevation: 12,
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, 6, 8, pad.bottom + 6),
        child: Row(
          children: [
            _PadBtn(
              key: const ValueKey('walk-left'),
              icon: Icons.chevron_left_rounded,
              tooltip: 'Previous aisle · راهروی قبلی',
              onTap: canLeft ? onLeft : null,
            ),
            _PadBtn(
              key: const ValueKey('walk-back'),
              icon: Icons.south_rounded,
              tooltip: backLabel,
              onTap: canBack ? onBack : null,
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hl(switch (room) {
                      LibraryRoom.street => 'The street · خیابان',
                      LibraryRoom.hall => 'Front hall · سرسرا',
                      LibraryRoom.aisle => section.name,
                    }),
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
                    hl(switch (room) {
                      LibraryRoom.street => 'New Life Public Library',
                      LibraryRoom.hall => 'میز امانت',
                      LibraryRoom.aisle => section.nameFa,
                    }),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    textDirection: helperDir,
                    style: BL.fa(11, color: const Color(0xFFEBD9B4)),
                  ),
                ],
              ),
            ),
            _PadBtn(
              key: const ValueKey('walk-forward'),
              icon: Icons.north_rounded,
              tooltip: forwardLabel,
              onTap: canForward ? onForward : null,
              filled: true,
            ),
            _PadBtn(
              key: const ValueKey('walk-right'),
              icon: Icons.chevron_right_rounded,
              tooltip: 'Next aisle · راهروی بعدی',
              onTap: canRight ? onRight : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _PadBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool filled;
  const _PadBtn({
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
              width: 48,
              height: 48,
              child: Icon(
                icon,
                color: enabled
                    ? (filled
                          ? const Color(0xFF5E3B1C)
                          : const Color(0xFFF7E7C1))
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
