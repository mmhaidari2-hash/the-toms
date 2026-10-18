import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/data/repository.dart';
import '../shared/widgets.dart';
import '../motivation/motivation_widgets.dart';
import '../../core/platform/remind.dart';
import 'map_spots.dart';

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
  MapRegion('home', 'Home', 'خانه', 'Level 1 · A0→A1', Offset(.48, .58), [[.36, .55, .24, .40]], level: 1),
  MapRegion('neighbourhood', 'Neighbourhood', 'محله', 'Level 2 · A1→A2', Offset(.84, .56), [[.66, .48, .33, .44], [.17, .52, .18, .2]], level: 2),
  MapRegion('highstreet', 'High Street', 'خیابان اصلی', 'Level 3 · A2→B1', Offset(.53, .40), [[.28, .36, .46, .19]], level: 3),
  MapRegion('town', 'Town centre', 'مرکز شهر', 'Level 4 · B1→B2', Offset(.30, .21), [[.03, .14, .95, .22]], level: 4),
  MapRegion('city', 'The city', 'شهر بزرگ', 'Level 5 · B2→C1', Offset(.55, .06), [[.12, .0, .86, .14]], level: 5),
  MapRegion('nursery', "Vida's Nursery", 'مهدکودک ویدا', 'Career Pack · Premium', Offset(.11, .5), [[.02, .47, .15, .18]], pack: 'nursery'),
];

/// Is a map region open for this learner? Level regions follow the course gating; packs are unlocked for now.
bool regionOpen(ProgressController ctrl, Course course, MapRegion r) {
  if (r.pack != null) return course.pack(r.pack!)?.unlocked ?? false;
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
  bool _centred = false;

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
        content: Text('${r.title} opens at Level $need. Finish Level ${need - 1} — or take the placement test.'),
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
      return Scaffold(backgroundColor: BL.ink, body: Center(child: async.hasError ? FilledButton(onPressed: () => ref.invalidate(contentProvider), child: const Text('Try again')) : const CircularProgressIndicator(color: BL.gold)));
    }
    final spots = ref.watch(spotsProvider).value ?? const <MapSpot>[];
    final next = ctrl.nextLesson(c.course);
    final nu = next == null ? null : c.course.unitOf(next.id);
    return Scaffold(
      backgroundColor: BL.ink,
      body: LayoutBuilder(builder: (context, box) {
        final h = box.maxHeight, w = h * mapAspect;
        if (!_centred) {
          _centred = true;
          final lv = nu?.level ?? 1;
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
            child: SizedBox(
              width: w,
              height: h,
              child: Stack(children: [
                Positioned.fill(child: Image.asset(mapImage, fit: BoxFit.cover)),
                for (final r in mapRegions)
                  for (final rc in r.rects)
                    Positioned(
                      left: rc[0] * w, top: rc[1] * h, width: rc[2] * w, height: rc[3] * h,
                      child: GestureDetector(key: ValueKey('region-${r.id}-${r.rects.indexOf(rc)}'), behavior: HitTestBehavior.opaque, onTap: () => _open(r, c)),
                    ),
                // The living town: every building / object opens the lessons set there.
                for (final s in spots)
                  Positioned(
                    left: s.x * w - 46, top: s.y * h - 20,
                    child: SpotMarker(
                      s: s,
                      open: featureSpots.contains(s.id) || spotLessons(c.course, s).any((l) => ctrl.lessonOpen(c.course, l)),
                      onTap: () {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        showSpotSheet(context, ref, s, c);
                      },
                    ),
                  ),
              ]),
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
              Expanded(child: Text('The Toms', style: BL.display(28, color: Colors.white).copyWith(shadows: const [Shadow(blurRadius: 8, color: Colors.black54)]))),
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
            left: 0, right: 0, top: pad.top + 58, height: 50,
            child: ListView(
              key: const ValueKey('level-strip'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                for (final r in mapRegions)
                  Padding(padding: const EdgeInsets.only(right: 8), child: _Pin(r: r, open: regionOpen(ctrl, c.course, r), here: r.level != null && r.level == nu?.level, onTap: () => _open(r, c))),
              ],
            ),
          ),
          // One big Continue button
          Positioned(
            left: 16, right: 16, bottom: pad.bottom + 16,
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
                      Text(nu == null ? 'ALL DONE' : 'CONTINUE · LEVEL ${nu.level} · UNIT ${c.course.numberInLevel(nu)}', style: const TextStyle(color: Color(0xFFFFD9A0), fontSize: 10.5, letterSpacing: 1.3, fontWeight: FontWeight.w800)),
                      Text(next?.title ?? 'Continue lesson', maxLines: 1, overflow: TextOverflow.ellipsis, style: BL.display(19, color: Colors.white)),
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
      final sent = await showNotification('English with the Toms', '$left XP to your daily goal. Keep your ${ctrl.currentStreak}-day streak going!');
      if (!sent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text('Reminder: $left XP to today\'s goal. One lesson will do it!')));
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
        onTap: () => context.push('/progress'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.local_fire_department_rounded, color: BL.red, size: 22),
            Text('${ctrl.currentStreak}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: BL.ink)),
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
  final bool open, here;
  final VoidCallback onTap;
  const _Pin({required this.r, required this.open, required this.here, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    key: ValueKey('pin-${r.id}'),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: open ? const Color(0xF2FBF3E4) : const Color(0xD9201813),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: here ? BL.red : (open ? BL.gold : Colors.white24), width: here ? 2.2 : 1.2),
        boxShadow: BL.shadow(.25),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (!open) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.lock_rounded, size: 12, color: Colors.white70)),
          if (r.pack != null) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.workspace_premium_rounded, size: 12, color: Color(0xFFC9A04C))),
          Text(r.title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: open ? BL.ink : Colors.white)),
        ]),
        Text(open ? r.sub : 'Needs Level ${r.level}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: open ? BL.muted : Colors.white60)),
      ]),
    ),
  );
}

/// Everything that used to crowd the home screen.
void showAppMenu(BuildContext context, WidgetRef ref) {
  final c = ref.read(contentProvider).value;
  final items = <(IconData, String, String, String)>[
    (Icons.route_rounded, 'Course path', 'مسیر درس‌ها', '/course'),
    (Icons.local_fire_department_rounded, 'Streak, goal, league & badges', 'رکورد، هدف، لیگ و نشان‌ها', '/progress'),
    (Icons.school_rounded, 'Grammar School', 'مدرسهٔ دستور زبان', '/school'),
    (Icons.local_library_rounded, 'Library · graded readers', 'کتابخانه · کتاب‌های داستان', '/library'),
    (Icons.movie_rounded, 'Cinema & dubbing', 'سینما و دوبله', '/cinema'),
    (Icons.radio_rounded, 'Hackney Hum radio', 'رادیو هاکنی هام', '/radio'),
    (Icons.chat_rounded, 'Messages', 'پیام‌ها', '/messages'),
    (Icons.calendar_month_rounded, 'Seasonal events', 'جشن‌ها و مناسبت‌ها', '/seasons'),
    (Icons.sports_esports_rounded, 'Park games', 'بازی‌های پارک', '/park'),
    (Icons.directions_car_rounded, 'Driving School', 'آموزشگاه رانندگی', '/driving'),
    (Icons.quiz_rounded, 'Driving theory test prep', 'آمادگی آزمون تئوری رانندگی', '/theory'),
    (Icons.account_balance_rounded, 'Life in the UK test prep', 'آمادگی آزمون زندگی در بریتانیا', '/lifeuk'),
    (Icons.hiking_rounded, 'Real-life missions', 'مأموریت‌های زندگی واقعی', '/missions'),
    (Icons.family_restroom_rounded, 'Family, stories & stats', 'خانواده، داستان‌ها و آمار', '/family'),
    if (c != null) for (final pk in c.course.packs) (Icons.workspace_premium_rounded, pk.title, pk.titleFa, '/pack/${pk.id}'),
    (Icons.workspace_premium_outlined, 'Premium (free in beta)', 'اشتراک ویژه (رایگان در دورهٔ آزمایشی)', '/premium'),
    (Icons.verified_rounded, 'Certificates', 'گواهی‌ها', '/certificate/1'),
    (Icons.menu_book_rounded, 'Diary', 'دفتر خاطرات', '/diary'),
    (Icons.quiz_rounded, 'Placement test', 'آزمون تعیین سطح', '/placement'),
    (Icons.gavel_rounded, 'Privacy, terms & about', 'حریم خصوصی، شرایط و دربارهٔ اپ', '/legal'),
    (Icons.help_outline_rounded, 'How it works', 'راهنمای برنامه', '/howto'),
  ];
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: BL.cream,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final (icon, en, fa, route) in items)
          ListTile(
            key: ValueKey('menu-$route'),
            leading: Icon(icon, color: BL.navy),
            title: Text(en, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(fa, textDirection: TextDirection.rtl, style: BL.fa(12, color: BL.muted)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.of(sheet).pop();
              context.push(route);
            },
          ),
        const SizedBox(height: 8),
      ])),
    ),
  );
}
