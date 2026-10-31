import 'package:british_life/core/i18n/helper_text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/models/learner_profile.dart';
import '../../core/data/repository.dart';
import '../shared/widgets.dart';
import '../motivation/motivation_widgets.dart';
import '../../core/platform/remind.dart';
import 'map_spots.dart';
import 'map_loupe.dart';
import '../shared/bottom_nav.dart';
import 'level_up.dart';
import '../shared/lang_bar.dart';
import '../motivation/streak_sheet.dart';

/// A region of the painted roadmap. [rects] are normalised (x, y, w, h) tap areas on map.webp.
class MapRegion {
  final String id, title, titleFa, sub;
  final int? level; // course level it opens (null = Career Pack)
  final String? pack;
  final Offset pin; // label anchor (normalised)
  final List<List<double>> rects;
  const MapRegion(this.id, this.title, this.titleFa, this.sub, this.pin, this.rects, {this.level, this.pack});
}

const mapImage = 'assets/places/map.webp';
const mapAspect = 1280 / 720;

const mapRegions = [
  MapRegion('home', 'Home', 'خانه', 'A1 · Level 1', Offset(.48, .58), [[.36, .55, .24, .40]], level: 1),
  MapRegion('neighbourhood', 'Neighbourhood', 'محله', 'A2 · Level 2', Offset(.84, .56), [[.66, .48, .33, .44], [.17, .52, .18, .2]], level: 2),
  MapRegion('highstreet', 'High Street', 'خیابان اصلی', 'B1 · Level 3', Offset(.53, .40), [[.28, .36, .46, .19]], level: 3),
  MapRegion('town', 'Town centre', 'مرکز شهر', 'B2 · Level 4', Offset(.30, .21), [[.03, .14, .95, .22]], level: 4),
  MapRegion('city', 'The city', 'شهر بزرگ', 'C1 · Level 5', Offset(.55, .06), [[.12, .0, .86, .14]], level: 5),
  MapRegion('nursery', "Primrose Lane Nursery", 'مهدکودک پرایمروز لین', 'Career Pack · Premium', Offset(.11, .5), [[.02, .47, .15, .18]], pack: 'nursery'),
  MapRegion('homes', 'Hartley & Wren Homes', 'املاک هارتلی و رن', 'Career Pack · A2–B2', Offset(.765, .585), [[.72, .55, .09, .08]], pack: 'homes'),
];

/// Is a map region open for this learner? Level regions follow the course gating; packs are unlocked for now.
bool regionOpen(ProgressController ctrl, Course course, MapRegion r) {
  if (ctrl.gatesOpen) return true;
  if (r.pack != null) return (course.pack(r.pack!)?.unlocked ?? false) || ctrl.hasPremium;
  final i = course.units.indexWhere((u) => u.level == r.level);
  return i >= 0 && ctrl.unitOpen(course, i);
}

/// First screen: the painted map of home → neighbourhood → town, one big Continue button, everything else in the menu.
class MapHome extends ConsumerStatefulWidget {
  const MapHome({super.key});
  @override
  ConsumerState<MapHome> createState() => _MapHomeState();
}

class _MapHomeState extends ConsumerState<MapHome> {
  final _scroll = ScrollController();
  bool _centred = false, _celebrating = false;
  /// Glass loupe: the finger / mouse point on the map (null = no lens) and the spot under it.
  Offset? _lens;
  MapSpot? _lensSpot;
  bool _lensTouch = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  /// Run 22: the lens is drawn in screen space, so it must follow the scroll offset. A mouse-hover lens
  /// simply goes away while the map scrolls (wheel / trackpad / drag); a press-and-hold lens repaints in place.
  void _onScroll() {
    if (_lens == null) return;
    setState(() {
      if (!_lensTouch) {
        _lens = null;
        _lensSpot = null;
      }
    });
  }

  void _moveLens(Offset? at, List<MapSpot> spots, double w, double h) {
    MapSpot? best;
    if (at != null) {
      // Hysteresis: stay on the current pin until the finger is clearly away from it (64 px), and only
      // snap onto a new pin when within 40 px of its centre, so the lens never jitters between two pins.
      final cur = _lensSpot;
      if (cur != null && (Offset(cur.x * w, cur.y * h) - at).distance < 64) {
        best = cur;
      } else {
        var bd = 40.0;
        for (final s in spots) {
          final d = (Offset(s.x * w, s.y * h) - at).distance;
          if (d < bd) {
            bd = d;
            best = s;
          }
        }
      }
    }
    // Run 22: the mouse only raises the lens over a pin, never over empty map (no lens while just moving across).
    if (at != null && best == null && !_lensTouch) at = null;
    if (best != null && best != _lensSpot && _lensTouch) HapticFeedback.selectionClick();
    if (at == _lens && best == _lensSpot) return;
    setState(() {
      _lens = at;
      _lensSpot = best;
    });
  }

  /// How much a spot grows near the lens: the one under it most, its neighbours a little.
  double _lensScale(MapSpot s, double w, double h) {
    final at = _lens;
    if (at == null) return 1;
    if (s == _lensSpot) return 1.28;
    final d = (Offset(s.x * w, s.y * h) - at).distance;
    return 1 + .14 * (1 - d / 150).clamp(0.0, 1.0);
  }

  /// "A1", "A1–A2" or "All levels" for a spot.
  String? _spotLevel(MapSpot s, ContentBundle c) {
    if (featureSpots.contains(s.id)) return 'All levels';
    final lv = {for (final l in spotLessons(c.course, s)) ?c.course.unitOf(l.id)?.level}.toList()..sort();
    if (lv.isEmpty) return null;
    final a = ProgressController.cefrOf(lv.first), b = ProgressController.cefrOf(lv.last);
    return a == b ? a : '$a–$b';
  }

  /// Moved up a level since the last visit? Celebrate once, then the map and path follow the new level.
  void _checkLevelUp(ContentBundle c) {
    if (_celebrating) return;
    final ctrl = ref.read(progressProvider.notifier);
    if (ctrl.levelSeen == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.markLevelSeen(ctrl.currentLevel(c.course)));
      return;
    }
    final up = ctrl.pendingLevelUp(c.course);
    if (up == null) return;
    _celebrating = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ctrl.markLevelSeen(up);
      if (mounted) await showLevelUp(context, up);
      _celebrating = false;
    });
  }

  void _open(MapRegion r, ContentBundle c) {
    final ctrl = ref.read(progressProvider.notifier);
    if (!regionOpen(ctrl, c.course, r)) {
      final need = r.level ?? 1;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        // Float above the Continue button so it never covers it.
        margin: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.paddingOf(context).bottom + 100),
        content: Text(hl('${r.title} (${ProgressController.cefrOf(need)}) opens when you pass ${ProgressController.cefrOf(need - 1)} — or take the placement test.')),
        action: SnackBarAction(label: 'Test', onPressed: () => context.push('/placement')),
      ));
      return;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    context.push(r.pack != null ? '/pack/${r.pack}' : '/course?level=${r.level}');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(contentProvider);
    final p = ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    if (!p.onboarded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/onboarding');
      });
    }
    final c = async.value;
    final pad = MediaQuery.paddingOf(context);
    if (c == null) {
      return Scaffold(
        backgroundColor: BL.ink,
        body: Center(
          child: async.hasError
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.wifi_off_rounded, color: Colors.white54, size: 40),
                    const SizedBox(height: 12),
                    const Text("Hackney didn't load properly", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                    const SizedBox(height: 6),
                    const Text('Usually a wobbly connection. Your progress is safe.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
                    const SizedBox(height: 16),
                    FilledButton(key: const ValueKey('home-retry'), onPressed: () => ref.invalidate(contentProvider), child: const Text('Try again')),
                  ]),
                )
              : const CircularProgressIndicator(color: BL.gold),
        ),
      );
    }
    final spots = ref.watch(spotsProvider).value ?? const <MapSpot>[];
    final next = ctrl.nextLesson(c.course);
    final nu = next == null ? null : c.course.unitOf(next.id);
    final cur = ctrl.currentLevel(c.course);
    if (p.onboarded) _checkLevelUp(c);
    return Scaffold(
      backgroundColor: BL.ink,
      bottomNavigationBar: const TomsBottomNav(current: HomeTab.town, dark: true),
      body: LayoutBuilder(builder: (context, box) {
        final h = box.maxHeight, w = h * mapAspect;
        if (!_centred) {
          _centred = true;
          final lv = cur;
          final r = mapRegions.firstWhere((r) => r.level == lv);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scroll.hasClients) _scroll.jumpTo((r.pin.dx * w - box.maxWidth / 2).clamp(0, _scroll.position.maxScrollExtent));
          });
        }
        return Stack(children: [
          SingleChildScrollView(
            key: const ValueKey('map-scroll'),
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: MouseRegion(
              onHover: (e) { if (e.kind == PointerDeviceKind.mouse) _moveLens(e.localPosition, spots, w, h); },
              onExit: (_) { if (!_lensTouch) _moveLens(null, spots, w, h); },
              child: RawGestureDetector(
              gestures: {
                // Press, hold for a moment, then slide: the loupe follows the finger (a quick swipe still scrolls).
                LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                  () => LongPressGestureRecognizer(duration: const Duration(milliseconds: 260)),
                  (g) => g
                    ..onLongPressStart = (d) {
                      _lensTouch = true;
                      HapticFeedback.lightImpact();
                      _moveLens(d.localPosition, spots, w, h);
                    }
                    ..onLongPressMoveUpdate = (d) {
                      _moveLens(d.localPosition, spots, w, h);
                    }
                    ..onLongPressEnd = (_) {
                      // Let go on a place: open it.
                      final s = _lensSpot;
                      _lensTouch = false;
                      _moveLens(null, spots, w, h);
                      if (s != null) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        showSpotSheet(context, ref, s, c);
                      }
                    }
                    ..onLongPressCancel = () {
                      _lensTouch = false;
                      if (_lens != null) _moveLens(null, spots, w, h);
                    },
                ),
              },
              child: SizedBox(
              width: w,
              height: h,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned.fill(child: Image.asset(mapImage, fit: BoxFit.cover)),
                for (final r in mapRegions)
                  for (final rc in r.rects)
                    Positioned(
                      left: rc[0] * w, top: rc[1] * h, width: rc[2] * w, height: rc[3] * h,
                      child: GestureDetector(key: ValueKey('region-${r.id}-${r.rects.indexOf(rc)}'), behavior: HitTestBehavior.opaque, onTap: () => _open(r, c)),
                    ),
                // Level zones (A1 … C1): locked districts are dimmed, the current one glows gold, each carries its badge.
                for (final r in mapRegions.where((r) => r.level != null))
                  for (final rc in r.rects)
                    Positioned(
                      left: rc[0] * w, top: rc[1] * h, width: rc[2] * w, height: rc[3] * h,
                      child: IgnorePointer(child: _Zone(open: regionOpen(ctrl, c.course, r), current: r.level == cur)),
                    ),
                for (final r in mapRegions.where((r) => r.level != null))
                  Positioned(
                    left: r.pin.dx * w - 30, top: (r.pin.dy < .11 ? .11 : r.pin.dy) * h - 14, // keep the top district's badge clear of the title bar
                    child: IgnorePointer(child: _ZoneBadge(level: r.level!, open: regionOpen(ctrl, c.course, r), current: r.level == cur, passed: ctrl.levelPassed(c.course, r.level!) || ctrl.levelSkipped(c.course, r.level!), progress: ctrl.levelProgress(c.course, r.level!))),
                  ),
                // The living town: every building / object opens the lessons set there.
                for (final s in spots)
                  Positioned(
                    left: s.x * w - SpotMarker.width / 2, top: s.y * h - 22,
                    child: AnimatedScale(
                      scale: _lensScale(s, w, h),
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      alignment: const Alignment(0, -.45),
                      child: SpotMarker(
                      s: s,
                      open: featureSpots.contains(s.id) || spotLessons(c.course, s).any((l) => ctrl.lessonOpen(c.course, l)),
                      visited: spotLessons(c.course, s).any(ctrl.lessonDone),
                      focus: spotFocus(ctrl, c.course, s),
                      levelTag: s.pack == null ? null : spotLessons(c.course, s).map((l) => c.course.unitOf(l.id)?.cefr).whereType<String>().fold<String?>(null, (a, b) => a == null || b.compareTo(a) < 0 ? b : a),
                      onTap: () {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        showSpotSheet(context, ref, s, c);
                      },
                    ),
                    ),
                  ),
              ]),
            ),
            ),
            ),
          ),
          // The glass loupe, in screen space above the map (still under the top bar and buttons).
          if (_lens != null)
            Positioned.fill(
              child: IgnorePointer(
                child: MapLoupe(
                  focal: _lensSpot == null ? _lens! : Offset(_lensSpot!.x * w, _lensSpot!.y * h),
                  scrollX: _scroll.hasClients ? _scroll.offset : 0,
                  mapW: w,
                  mapH: h,
                  mapImage: mapImage,
                  spot: _lensSpot,
                  level: _lensSpot == null ? null : _spotLevel(_lensSpot!, c),
                  viewWidth: box.maxWidth,
                  topSafe: pad.top + 120,
                  open: _lensSpot == null || featureSpots.contains(_lensSpot!.id) || spotLessons(c.course, _lensSpot!).any((l) => ctrl.lessonOpen(c.course, l)),
                ),
              ),
            ),
          // Top bar
          Positioned(
            left: 0, right: 0, top: 0,
            child: IgnorePointer(child: Container(height: pad.top + 130, decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xCC140E0A), Color(0x00140E0A)])))),
          ),
          Positioned(
            left: 20, right: 10, top: pad.top + 10,
            child: Row(children: [
              Expanded(child: Text('New Life UK', key: const ValueKey('app-title'), maxLines: 1, overflow: TextOverflow.ellipsis, style: BL.display(25, color: Colors.white).copyWith(shadows: const [Shadow(blurRadius: 8, color: Colors.black54)]))),
              const _StatsChip(),
              const SizedBox(width: 8),
              _RoundBtn(key: const ValueKey('menu'), icon: Icons.menu_rounded, onTap: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                showAppMenu(context, ref);
              }),
            ]),
          ),
          // Level areas: one chip per level (and pack), tap to open that level's path.
          Positioned(
            left: 0, right: 0, top: pad.top + 58, height: 56,
            child: ListView(
              key: const ValueKey('level-strip'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                for (final r in mapRegions)
                  Padding(padding: const EdgeInsets.only(right: 8), child: _Pin(r: r, open: regionOpen(ctrl, c.course, r), here: r.level != null && r.level == cur, passed: r.level != null && ctrl.levelPassed(c.course, r.level!), skipped: r.level != null && ctrl.levelSkipped(c.course, r.level!), progress: r.level == null ? null : ctrl.levelProgress(c.course, r.level!), onTap: () => _open(r, c))),
              ],
            ),
          ),

          if (ref.watch(progressProvider).ownerMode)
            Positioned(
              left: 16,
              bottom: 88,
              child: Material(
                color: const Color(0xE6C9A04C),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  key: const ValueKey('owner-badge'),
                  borderRadius: BorderRadius.circular(20),
                  onTap: () async {
                    final off = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(hl('Owner mode')),
                        content: Text(hl('Every lesson and pack is unlocked on this device. Turn off to restore normal gates. Your progress stays.')),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(hl('Keep on'))),
                          FilledButton(key: const ValueKey('owner-turn-off'), onPressed: () => Navigator.pop(ctx, true), child: Text(hl('Turn off'))),
                        ],
                      ),
                    );
                    if (off == true && context.mounted) {
                      ref.read(progressProvider.notifier).setOwnerMode(false);
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text('Owner mode', style: TextStyle(color: Color(0xFF1B2A4A), fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                ),
              ),
            ),
          // One big Continue button
          Positioned(
            left: 16, right: 16, bottom: 12,
            child: Pressable(
              key: const ValueKey('continue'),
              onTap: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                context.push(next == null ? '/course' : '/lesson/${next.id}');
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                decoration: BoxDecoration(color: BL.red, borderRadius: BorderRadius.circular(26), boxShadow: BL.shadow(.35)),
                child: Row(children: [
                  if (next != null) Avatar(c.character(next.lead), size: 46, ring: false),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(hl(nu == null ? 'ALL DONE' : 'CONTINUE · ${ProgressController.cefrOf(nu.level)} · UNIT ${c.course.numberInLevel(nu)}'), style: const TextStyle(color: Color(0xFFFFD9A0), fontSize: 10.5, letterSpacing: 1.3, fontWeight: FontWeight.w800)),
                      Text(hl(next?.title ?? 'Continue lesson'), maxLines: 1, overflow: TextOverflow.ellipsis, style: BL.display(19, color: Colors.white)),
                    ]),
                  ),
                  Container(
                    width: 46, height: 46,
                    decoration: const BoxDecoration(color: Color(0xFFFBF3E4), shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded, color: BL.ink, size: 28),
                  ),
                ]),
              ),
            ),
          ),
        ]);
      }),
    );
  }
}

/// Streak + today's goal ring; opens the progress screen. One small chip keeps the map uncluttered.
class _StatsChip extends ConsumerStatefulWidget {
  const _StatsChip();
  @override
  ConsumerState<_StatsChip> createState() => _StatsChipState();
}

class _StatsChipState extends ConsumerState<_StatsChip> {
  @override
  void initState() {
    super.initState();
    // Daily reminder nudge: once a day after the chosen time, if today's goal isn't met yet.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ctrl = ref.read(progressProvider.notifier);
      if (!mounted || !ctrl.reminderDue()) return;
      ctrl.markReminded();
      final left = ctrl.dailyGoal - ctrl.xpToday;
      final sent = await showNotification('New Life UK', ctrl.currentStreak > 0 ? 'Your ${ctrl.currentStreak}-day streak is waiting. $left XP to today\'s goal.' : '$left XP to your daily goal. One lesson will do it!');
      if (!sent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(hl('Reminder: $left XP to today\'s goal. One lesson will do it!'))));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    return Material(
      color: Colors.white.withValues(alpha: .92),
      shape: const StadiumBorder(),
      child: InkWell(
        key: const ValueKey('stats-chip'),
        customBorder: const StadiumBorder(),
        onTap: () => showStreakSheet(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.local_fire_department_rounded, color: BL.red, size: 22),
            Text(hl('${ctrl.currentStreak}'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: BL.ink)),
            const SizedBox(width: 8),
            GoalRing(xp: ctrl.xpToday, goal: ctrl.dailyGoal, size: 22),
          ]),
        ),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundBtn({super.key, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: .92),
    shape: const CircleBorder(),
    child: IconButton(onPressed: onTap, icon: Icon(icon, color: BL.ink), tooltip: 'Menu'),
  );
}

class _Pin extends StatelessWidget {
  final MapRegion r;
  final bool open, here, skipped;
  final bool passed0;
  final double? progress;
  final VoidCallback onTap;
  const _Pin({required this.r, required this.open, required this.here, bool passed = false, this.skipped = false, this.progress, required this.onTap}) : passed0 = passed;
  bool get passed => passed0 || skipped;
  @override
  Widget build(BuildContext context) {
    final lv = r.level;
    final status = r.pack != null ? r.sub : !open ? 'Locked' : passed0 ? 'Passed ✓' : skipped ? 'Skipped ✓' : here ? 'You are here' : '${((progress ?? 0) * 100).round()}%';
    return GestureDetector(
      key: ValueKey('pin-${r.id}'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: open ? const [Color(0xF7FFFFFF), Color(0xE6F3E6D0)] : const [Color(0xB33A2E26), Color(0xD9181210)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: here ? BL.red : (open ? const Color(0xCCFFFFFF) : Colors.white24), width: here ? 2.2 : 1.2),
          boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (lv != null)
            Container(
              width: 34, height: 34, alignment: Alignment.center,
              margin: const EdgeInsets.only(right: 7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: here ? BL.red : passed ? const Color(0xFF1F7A4D) : open ? BL.ink : const Color(0x33FFFFFF),
              ),
              child: Text(hl(ProgressController.cefrOf(lv)), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12.5)),
            )
          else
            const Padding(padding: EdgeInsets.only(left: 4, right: 6), child: Icon(Icons.workspace_premium_rounded, size: 16, color: Color(0xFFC9A04C))),
          Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (!open) const Padding(padding: EdgeInsets.only(right: 3), child: Icon(Icons.lock_rounded, size: 11, color: Colors.white70)),
              Text(hl(r.title), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: open ? BL.ink : Colors.white)),
            ]),
            Text(hl(status), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: here ? BL.red : open ? BL.muted : Colors.white60)),
            if (lv != null && open)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SizedBox(
                  width: 64,
                  child: ClipRRect(borderRadius: BorderRadius.circular(9), child: LinearProgressIndicator(value: passed ? 1 : (progress ?? 0), minHeight: 3.5, backgroundColor: const Color(0x22000000), color: passed ? const Color(0xFF1F7A4D) : BL.red)),
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}

/// Tint over one level district on the painting.
class _Zone extends StatelessWidget {
  final bool open, current;
  const _Zone({required this.open, required this.current});
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      color: open ? (current ? const Color(0x14FFD36B) : null) : const Color(0x6B0B0806),
      border: current ? Border.all(color: const Color(0xCCFFD36B), width: 2) : null,
    ),
  );
}

/// Floating district badge on the painting: CEFR level, status and a progress ring.
class _ZoneBadge extends StatelessWidget {
  final int level;
  final bool open, current, passed;
  final double progress;
  const _ZoneBadge({required this.level, required this.open, required this.current, required this.passed, required this.progress});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 60,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        key: ValueKey('zone-${ProgressController.cefrOf(level)}'),
        width: 30, height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(center: const Alignment(-.3, -.4), colors: current ? const [Color(0xFFFF7A6E), BL.red] : passed ? const [Color(0xFF4CC28A), Color(0xFF1F7A4D)] : open ? const [Color(0xFF5A4A40), BL.ink] : const [Color(0xFF6B6058), Color(0xFF2A211B)]),
          border: Border.all(color: Colors.white, width: 1.6),
          boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Stack(alignment: Alignment.center, children: [
          if (open) Positioned.fill(child: Padding(padding: const EdgeInsets.all(1.5), child: CircularProgressIndicator(value: passed ? 1 : progress, strokeWidth: 2.2, color: const Color(0xFFFFD36B), backgroundColor: Colors.white24))),
          open
              ? Text(hl(ProgressController.cefrOf(level)), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11))
              : const Icon(Icons.lock_rounded, size: 14, color: Colors.white70),
        ]),
      ),
      if (current)
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(color: BL.red, borderRadius: BorderRadius.circular(6)),
          child: const Text('YOU', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .8)),
        ),
    ]),
  );
}

typedef _MI = (IconData, String, String, String);

/// Everything that used to crowd the home screen — grouped so it reads at a glance.
void showAppMenu(BuildContext context, WidgetRef ref) {
  final c = ref.read(contentProvider).value;
  final groups = <(String, String, List<_MI>)>[
    ('Learn', 'یادگیری', [
      (Icons.route_rounded, 'Course path', 'مسیر درس‌ها', '/course'),
      (Icons.school_rounded, 'Grammar', 'دستور زبان', '/school'),
      (Icons.inventory_2_rounded, 'Leitner box', 'جعبهٔ لایتنر', '/leitner'),
      (Icons.quiz_rounded, 'Placement test', 'تعیین سطح', '/placement'),
    ]),
    ('Read, watch & listen', 'بخوان، ببین، گوش کن', [
      (Icons.local_library_rounded, 'Library', 'کتابخانه', '/library'),
      (Icons.movie_rounded, 'Cinema', 'سینما و دوبله', '/cinema'),
      (Icons.radio_rounded, 'Radio', 'رادیو', '/radio'),
      (Icons.chat_rounded, 'Messages', 'پیام‌ها', '/messages'),
    ]),
    ('Life in the UK', 'زندگی در بریتانیا', [
      (Icons.hiking_rounded, 'Missions', 'مأموریت‌ها', '/missions'),
      (Icons.account_balance_rounded, 'Life in the UK test', 'آزمون زندگی در بریتانیا', '/lifeuk'),
      (Icons.badge_rounded, 'Visa Help Desk', 'میز کمک ویزا', '/visa'),
      (Icons.account_balance_outlined, 'Settlement pathway (B2)', 'مسیر اقامت (B2)', '/settlement'),
      (Icons.offline_pin_rounded, 'Arrival Offline Pack', 'بستهٔ آفلاین ورود', '/arrival'),
      (Icons.description_rounded, 'UK Forms Practice Lab', 'آزمایشگاه فرم‌های بریتانیا', '/forms'),
      (Icons.record_voice_over_rounded, 'Pronunciation coach', 'مربی تلفظ', '/coach'),
      (Icons.directions_car_rounded, 'Driving School', 'آموزشگاه رانندگی', '/driving'),
      (Icons.fact_check_rounded, 'Theory test', 'آزمون تئوری', '/theory'),
      (Icons.calendar_month_rounded, 'Seasons', 'مناسبت‌ها', '/seasons'),
      if (c != null) for (final pk in c.course.packs) (Icons.workspace_premium_rounded, pk.title, pk.titleFa, '/pack/${pk.id}'),
    ]),
    ('You & the family', 'شما و خانواده', [
      (Icons.flag_rounded, 'My study plan', 'برنامهٔ مطالعه', '/plan'),
      (Icons.replay_rounded, 'My mistakes', 'اشتباه‌های من', '/practice/mistakes'),
      (Icons.local_fire_department_rounded, 'Progress', 'پیشرفت و نشان‌ها', '/progress'),
      (Icons.manage_accounts_rounded, 'Profiles', 'پروفایل‌ها', '/profiles'),
      (Icons.family_restroom_rounded, 'Family', 'خانواده و داستان‌ها', '/family'),
      (Icons.menu_book_rounded, 'Diary', 'دفتر خاطرات', '/diary'),
      (Icons.verified_rounded, 'Certificates', 'گواهی‌ها', '/certificate/1'),
      (Icons.sports_esports_rounded, 'Park games', 'بازی‌های پارک', '/park'),
    ]),
  ];
  final more = <_MI>[
    (Icons.badge_rounded, 'Your name', 'نام شما', '#name'),
    (Icons.workspace_premium_outlined, 'Premium', 'اشتراک ویژه', '/premium'),
    (Icons.help_outline_rounded, 'How it works', 'راهنما', '/howto'),
    (Icons.gavel_rounded, 'Privacy & terms', 'حریم خصوصی', '/legal'),
  ];
  void go(BuildContext sheet, String route) {
    Navigator.of(sheet).pop();
    if (route == '#name') {
      showNameDialog(context, ref);
    } else {
      context.push(route);
    }
  }

  final kid = ref.read(progressProvider.notifier).kidMode;
  List<_MI> filt(List<_MI> items) => [for (final it in items) if (!kid || !kidBlocks(it.$4)) it];
  final groupsView = [for (final (en, fa, items) in groups) (en, fa, filt(items))];
  final moreView = filt(more);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: BL.cream,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .88),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: LayoutBuilder(builder: (context, box) {
          final w = (box.maxWidth - 16) / 3;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            for (final (en, fa, items) in groupsView) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                child: Row(children: [
                  Text(hl(en.toUpperCase()), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1, color: BL.navy)),
                  const Spacer(),
                  Text(hl(fa), textDirection: helperDir, style: BL.fa(11.5, color: BL.muted)),
                ]),
              ),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final (icon, ten, tfa, route) in items)
                  SizedBox(width: w, child: _MenuTile(key: ValueKey('menu-$route'), icon: icon, en: ten, fa: tfa, onTap: () => go(sheet, route))),
              ]),
            ],
            const SizedBox(height: 14),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
              child: Row(children: [
                const Icon(Icons.translate_rounded, color: BL.muted, size: 20),
                const SizedBox(width: 14),
                const Text('Helper language', style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(hl('زبان کمکی'), textDirection: helperDir, style: BL.fa(11.5, color: BL.muted)),
              ]),
            ),
            const Padding(padding: EdgeInsets.fromLTRB(4, 0, 4, 8), child: HelperLangBar()),
            for (final (icon, en, fa, route) in moreView)
              ListTile(
                key: ValueKey('menu-$route'),
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: Icon(icon, color: BL.muted, size: 20),
                title: Text(hl(en), style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: Text(hl(fa), textDirection: helperDir, style: BL.fa(11.5, color: BL.muted)),
                onTap: () => go(sheet, route),
              ),
            // AI disclosure (run 23): every voice in the app is generated, none is a recording of a real person.
            Padding(
              key: const ValueKey('ai-voices-note'),
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: Row(children: [
                const Icon(Icons.record_voice_over_outlined, color: BL.muted, size: 16),
                const SizedBox(width: 10),
                Expanded(child: Text(hl('Voices are AI-generated (text-to-speech), not real people.'), style: const TextStyle(fontSize: 11.5, color: BL.muted))),
              ]),
            ),
          ]);
        }),
      ),
    ),
  );
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String en, fa;
  final VoidCallback onTap;
  const _MenuTile({super.key, required this.icon, required this.en, required this.fa, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            height: 92,
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: BL.mist)),
            child: Column(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF34548C), BL.navy]),
                  boxShadow: [BoxShadow(color: BL.navy.withValues(alpha: .25), blurRadius: 6, offset: const Offset(0, 3))],
                ),
                child: Icon(icon, color: Colors.white, size: 19),
              ),
              const SizedBox(height: 6),
              Text(hl(en), maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, height: 1.1)),
              const Spacer(),
              Text(hl(fa), maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: helperDir, style: BL.fa(9.5, color: BL.muted)),
            ]),
          ),
        ),
      );
}

/// Change the name the family uses in text (the recorded voices never say a name).
Future<void> showNameDialog(BuildContext context, WidgetRef ref) async {
  final ctrl = ref.read(progressProvider.notifier);
  final t = TextEditingController(text: ctrl.pref('name'));
  final v = await showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('What should the family call you?'),
      content: TextField(
        key: const ValueKey('name-field'),
        controller: t,
        autofocus: true,
        maxLength: 24,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'Your first name (optional)', counterText: ''),
        onSubmitted: (s) => Navigator.of(d).pop(s),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('Cancel')),
        FilledButton(key: const ValueKey('name-save'), onPressed: () => Navigator.of(d).pop(t.text), child: const Text('Save')),
      ],
    ),
  );
  if (v != null) ctrl.setPref('name', v.trim());
}
