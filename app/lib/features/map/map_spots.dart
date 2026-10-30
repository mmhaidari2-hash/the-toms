import 'package:british_life/core/i18n/helper_text.dart';
import '../../core/platform/asset_text.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/data/repository.dart';
import '../seasons/seasons_data.dart';
import '../roleplay/roleplay_data.dart';
import '../shared/widgets.dart';

/// A building / object on the town map and the lessons set there (index built by tool/make_spots.py).
class MapSpot {
  final String id, title, titleFa, icon;
  final double x, y;
  final String? pack;
  final List<String> lessons;
  const MapSpot(this.id, this.title, this.titleFa, this.icon, this.x, this.y, this.pack, this.lessons);
  factory MapSpot.fromJson(Map<String, dynamic> j) =>
      MapSpot(j['id'], j['title'], j['titleFa'], j['icon'], (j['x'] as num).toDouble(), (j['y'] as num).toDouble(), j['pack'], List<String>.from(j['lessons']));
}

final spotsProvider = FutureProvider<List<MapSpot>>((ref) async {
  final j = jsonDecode(await loadAssetText('assets/data/spots.json')) as List;
  return [for (final s in j) MapSpot.fromJson(s)];
});

/// A place on the map with lessons at the learner's current level: highlighted so the level's places stand out.
bool spotFocus(ProgressController ctrl, Course c, MapSpot s) {
  final cur = ctrl.currentLevel(c);
  return spotLessons(c, s).any((l) => c.unitOf(l.id)?.level == cur);
}

/// Spots that open a whole section (each has A1 content for everyone), so their marker is never shown locked.
const featureSpots = {'library', 'school', 'cinema', 'radio', 'missions', 'park', 'garage', 'visa', 'settlement'};

/// The lessons of a spot, in course order, that exist in this build.
List<Lesson> spotLessons(Course c, MapSpot s) => [for (final id in s.lessons) ?c.lesson(id)];

/// Level / pack label for a lesson ("Level 2 · Unit 5", "Vida's Nursery · A1").
String lessonWhere(Course c, Lesson l) {
  final u = c.unitOf(l.id)!;
  final pk = c.packOf(u);
  return pk != null ? '${pk.title} · ${u.cefr ?? ''}' : 'Level ${u.level} · Unit ${c.numberInLevel(u)}';
}

/// Round icon + label on the map.
/// The spot's painted icon (a crop of its own painting, tool/make_spot_icons.py); emoji only as a fallback.
class SpotIcon extends StatelessWidget {
  final MapSpot s;
  final double size;
  final bool dim;
  const SpotIcon(this.s, {super.key, this.size = 36, this.dim = false});
  @override
  Widget build(BuildContext context) {
    Widget img = Image.asset(
      'assets/spots/${s.id}.webp',
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(hl(s.icon), style: TextStyle(fontSize: size * .55)),
        ),
      ),
    );
    if (dim) img = ColorFiltered(colorFilter: const ColorFilter.matrix([.33, .33, .33, 0, 0, .33, .33, .33, 0, 0, .33, .33, .33, 0, 0, 0, 0, 0, .75, 0]), child: img);
    return ClipOval(child: img);
  }
}

class SpotMarker extends StatelessWidget {
  final MapSpot s;
  final bool open;
  final bool visited;
  /// Has lessons at the learner's current level — highlighted with a red glow so the level's places stand out.
  final bool focus;
  final VoidCallback onTap;
  /// Career-pack buildings: the level they open at ("A2"), shown as a badge while the building is still locked.
  final String? levelTag;
  const SpotMarker({super.key, required this.s, required this.open, this.visited = false, this.focus = false, this.levelTag, required this.onTap});
  static const width = 100.0;
  @override
  Widget build(BuildContext context) => GestureDetector(
    key: ValueKey('spot-${s.id}'),
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Opacity(
      opacity: open ? 1 : .62,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // A 3D glass orb: soft ground shadow, translucent body, gold rim, specular highlight.
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-.35, -.45),
                  radius: .95,
                  colors: open
                      ? const [Color(0xFFFFFFFF), Color(0xE6FBF3E4), Color(0xCCE9D7B8)]
                      : const [Color(0xCC6B6058), Color(0xE0332821), Color(0xF0201813)],
                ),
                border: Border.all(color: focus ? const Color(0xFFFFC83D) : visited ? const Color(0xFFE9C46A) : (open ? BL.gold : Colors.white38), width: focus ? 3.0 : open ? 2.0 : 1.4),
                boxShadow: [
                  const BoxShadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 5)),
                  if (focus) const BoxShadow(color: Color(0xCCFFC83D), blurRadius: 16, spreadRadius: 3)
                  else if (visited) const BoxShadow(color: Color(0x66FFC94D), blurRadius: 8, spreadRadius: 1),
                ],
              ),
              key: focus ? ValueKey('spot-focus-${s.id}') : null,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  ClipOval(child: SpotIcon(s, size: 38, dim: !open)),
                  // Glass gloss on the top half.
                  Positioned(
                    top: 3, left: 8, right: 8, height: 15,
                    child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x99FFFFFF), Color(0x00FFFFFF)]),
                    ))),
                  ),
                  if (!open) const Positioned(right: -6, bottom: -5, child: _Badge(icon: Icons.lock_rounded, color: Color(0xFF3A2E26))),
                  if (!open && levelTag != null)
                    Positioned(
                      left: -10, top: -6,
                      child: Container(
                        key: ValueKey('spot-level-${s.id}'),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(color: BL.gold, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white, width: 1)),
                        child: Text(hl('$levelTag+'), style: const TextStyle(color: BL.ink, fontSize: 9, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  if (open && visited) const Positioned(right: -6, bottom: -5, child: _Badge(icon: Icons.check_rounded, color: Color(0xFF1F7A4D))),
                ],
              ),
            ),
            const SizedBox(height: 3),
            // Frosted-glass label (faux frost: translucent gradient + hairline, no per-label blur so phones stay fast).
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xC72E241D), Color(0xE0140E0A)]),
                border: Border.all(color: const Color(0x40FFFFFF), width: .7),
                boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: Text(
                hl(label(s.title)),
                maxLines: 2,
                softWrap: true,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 10, height: 1.15, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  // The estate agent keeps its name and says what it is; other "A & B" titles keep only the first part.
  static String label(String t) => t.startsWith('Fennick & Rowe') ? 'Estate Agent\nFennick & Rowe' : t.split(' — ').first.split(' & ').first;
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _Badge({required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: 17, height: 17,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.3)),
    child: Icon(icon, size: 11, color: Colors.white),
  );
}

/// Bottom sheet: the place's name (EN + FA), its lessons (any level; locked ones shown) and a Start button.
Future<void> showSpotSheet(BuildContext context, WidgetRef ref, MapSpot s, ContentBundle c) {
  final ctrl = ref.read(progressProvider.notifier);
  final ls = spotLessons(c.course, s);
  final next = ls.where((l) => ctrl.lessonOpen(c.course, l) && !ctrl.lessonDone(l)).firstOrNull ?? ls.where((l) => ctrl.lessonOpen(c.course, l)).firstOrNull;
  final done = ls.where(ctrl.lessonDone).length;
  void open(BuildContext sheet, Lesson l) {
    Navigator.of(sheet).pop();
    context.push('/lesson/${l.id}');
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: BL.cream,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (sheet) => DraggableScrollableSheet(
      key: ValueKey('spotsheet-${s.id}'),
      expand: false,
      initialChildSize: .66,
      maxChildSize: .92,
      minChildSize: .35,
      builder: (_, sc) => ListView(
        controller: sc,
        padding: EdgeInsets.fromLTRB(18, 0, 18, MediaQuery.paddingOf(context).bottom + 18),
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: BL.gold, width: 2),
                  boxShadow: BL.shadow(.25),
                ),
                child: SpotIcon(s, size: 52),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hl(s.title), style: BL.display(22)),
                    Text(
                      hl(s.titleFa),
                      textDirection: helperDir,
                      style: BL.fa(14, color: BL.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (s.id == 'garage') ...[
            const SizedBox(height: 12),
            Material(
              color: BL.navy,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                key: const ValueKey('spot-open-driving'),
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.of(sheet).pop();
                  context.push('/driving');
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.directions_car_rounded, color: BL.gold),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Driving School · lessons with the instructor',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Material(
              color: BL.navy,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                key: const ValueKey('spot-open-theory'),
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.of(sheet).pop();
                  context.push('/theory');
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.quiz_rounded, color: BL.gold),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Theory test prep',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (s.id == 'library') ...[
            const SizedBox(height: 12),
            Material(
              color: BL.navy,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                key: const ValueKey('spot-open-library'),
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.of(sheet).pop();
                  context.push('/library');
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.local_library_rounded, color: BL.gold),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Browse the shelves · graded readers',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Material(
              color: const Color(0xFF1F3A68),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                key: const ValueKey('spot-open-lifeuk'),
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.of(sheet).pop();
                  context.push('/lifeuk');
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_rounded, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Life in the UK test prep · study corner',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (s.id == 'settlement') ...[
            const SizedBox(height: 12),
            Material(
              color: const Color(0xFF1F3A68),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                key: const ValueKey('spot-open-settlement'),
                borderRadius: BorderRadius.circular(18),
                onTap: () { Navigator.of(sheet).pop(); context.push('/settlement'); },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(children: [
                    Icon(Icons.account_balance_rounded, color: BL.gold),
                    SizedBox(width: 12),
                    Expanded(child: Text('B2 settlement pathway · Life in the UK, ILR info, B2 English', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15))),
                    Icon(Icons.chevron_right_rounded, color: Colors.white),
                  ]),
                ),
              ),
            ),
          ],
          if (s.id == 'visa') ...[
            const SizedBox(height: 12),
            Material(
              color: const Color(0xFF0B3D5C),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                key: const ValueKey('spot-open-visa'),
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.of(sheet).pop();
                  context.push('/visa');
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.badge_rounded, color: BL.gold),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'General visa info · GOV.UK & OISC signposts',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(hl('Not immigration advice. For your case, use GOV.UK and an OISC-regulated adviser.'), style: const TextStyle(fontSize: 12.5, color: BL.muted, height: 1.35)),
          ],
          if (s.id == 'cinema') ...[
            const SizedBox(height: 12),
            Material(
              color: const Color(0xFF17110F),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                key: const ValueKey('spot-open-cinema'),
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.of(sheet).pop();
                  context.push('/cinema');
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.movie_rounded, color: BL.gold),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Now showing · watch & dub scenes',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (s.id == 'radio') ...[
            const SizedBox(height: 12),
            Material(
              color: const Color(0xFF14202B),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                key: const ValueKey('spot-open-radio'),
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.of(sheet).pop();
                  context.push('/radio');
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.radio_rounded, color: BL.gold),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'On air · listen to Hackney Hum',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (s.id == 'home') ...[
            const SizedBox(height: 12),
            Material(
              color: const Color(0xFF2E7D5B),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                key: const ValueKey('spot-open-messages'),
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.of(sheet).pop();
                  context.push('/messages');
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.chat_rounded, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Messages · voice notes from the family',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Material(
              color: const Color(0xFF8A3B2E),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                key: const ValueKey('spot-open-seasons'),
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.of(sheet).pop();
                  context.push('/seasons');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Consumer(
                          builder: (_, r, _) {
                            final f = r.watch(seasonsProvider).whenOrNull(data: Seasons.featured);
                            return Text(
                              hl(f == null ? 'Family calendar · British celebrations' : 'Family calendar · ${f.$1.title}: ${Seasons.countdown(f.$2).toLowerCase()}'),
                              key: const ValueKey('spot-seasons-next'),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                            );
                          },
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (s.id == 'park') ...[
            const SizedBox(height: 12),
            Material(
              color: const Color(0xFF3C7A3E),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                key: const ValueKey('spot-open-park'),
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.of(sheet).pop();
                  context.push('/park');
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.sports_esports_rounded, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Park games · quick word games',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ],
          Consumer(builder: (_, ref, _) {
            final r = (ref.watch(roleplaysProvider).value ?? const <Roleplay>[]).where((x) => x.spot == s.id).firstOrNull;
            if (r == null) return const SizedBox.shrink();
            final st = ref.read(progressProvider.notifier).roleplayStars(r.id);
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Material(
                color: BL.navy,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  key: ValueKey('spot-roleplay-${r.id}'),
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    Navigator.of(sheet).pop();
                    context.push('/roleplay/${r.id}');
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(children: [
                      const Icon(Icons.forum_rounded, color: BL.gold),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(hl('Role-play · ${r.title}'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                          Text(hl('${r.level} · 3 goals${st > 0 ? '  ·  ${'★' * st}${'☆' * (3 - st)}' : ''}  ·  ${r.titleFa}'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white),
                    ]),
                  ),
                ),
              ),
            );
          }),
          if (s.id == 'missions') ...[
            const SizedBox(height: 12),
            Material(
              color: BL.red,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                key: const ValueKey('spot-open-missions'),
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.of(sheet).pop();
                  context.push('/missions');
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.hiking_rounded, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Real-life missions · try it out there',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (s.id == 'school' || s.id == 'university') ...[
            const SizedBox(height: 12),
            Material(
              color: BL.navy,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                key: ValueKey(s.id == 'school' ? 'spot-open-school' : 'spot-open-college'),
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.of(sheet).pop();
                  context.push(s.id == 'school' ? '/school' : '/school?campus=college');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.school_rounded, color: BL.gold),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          s.id == 'school' ? 'Grammar School · Mrs Ellis\'s classes A1–A2' : 'Riverside Adult College · grammar classes B1–C1',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            hl('${ls.length} lessons here  ·  $done done'),
            style: const TextStyle(color: BL.muted, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('spot-start'),
            onPressed: next == null ? null : () => open(sheet, next),
            style: FilledButton.styleFrom(
              backgroundColor: BL.red,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(
              hl(next == null ? 'Locked for now — keep going on the course' : 'Start: ${next.title}'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
          const SizedBox(height: 10),
          for (final l in ls)
            Builder(
              builder: (_) {
                final isOpen = ctrl.lessonOpen(c.course, l), isDone = ctrl.lessonDone(l);
                return ListTile(
                  key: ValueKey('spot-lesson-${l.id}'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Opacity(opacity: isOpen ? 1 : .45, child: Avatar(c.character(l.lead), size: 40)),
                  title: Text(
                    hl(l.title),
                    style: TextStyle(fontWeight: FontWeight.w700, color: isOpen ? BL.ink : BL.muted),
                  ),
                  subtitle: Text(hl('${lessonWhere(c.course, l)}  ·  ${l.titleFa}'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                  trailing: Icon(isDone ? Icons.check_circle_rounded : (isOpen ? Icons.play_circle_fill_rounded : Icons.lock_rounded), color: isDone ? BL.green : (isOpen ? BL.red : BL.muted)),
                  onTap: () {
                    if (isOpen) return open(sheet, l);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2), content: Text(hl('"${l.title}" unlocks as you go — ${lessonWhere(c.course, l)}.'))));
                  },
                );
              },
            ),
        ],
      ),
    ),
  );
}
