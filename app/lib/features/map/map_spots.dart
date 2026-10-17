import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/data/repository.dart';
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
  final j = jsonDecode(await rootBundle.loadString('assets/data/spots.json')) as List;
  return [for (final s in j) MapSpot.fromJson(s)];
});

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
    Widget img = Image.asset('assets/spots/${s.id}.webp', width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, _, _) => SizedBox(width: size, height: size, child: Center(child: Text(s.icon, style: TextStyle(fontSize: size * .55)))));
    if (dim) img = ColorFiltered(colorFilter: const ColorFilter.matrix([.33, .33, .33, 0, 0, .33, .33, .33, 0, 0, .33, .33, .33, 0, 0, 0, 0, 0, .75, 0]), child: img);
    return ClipOval(child: img);
  }
}

class SpotMarker extends StatelessWidget {
  final MapSpot s;
  final bool open;
  final VoidCallback onTap;
  const SpotMarker({super.key, required this.s, required this.open, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    key: ValueKey('spot-${s.id}'),
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: SizedBox(
      width: 92,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: open ? const Color(0xF7FBF3E4) : const Color(0xE6201813),
            shape: BoxShape.circle,
            border: Border.all(color: open ? BL.gold : Colors.white30, width: 1.6),
            boxShadow: BL.shadow(.35),
          ),
          child: Stack(clipBehavior: Clip.none, children: [
            SpotIcon(s, size: 36, dim: !open),
            if (!open) const Positioned(right: -8, bottom: -6, child: Icon(Icons.lock_rounded, size: 13, color: Colors.white70)),
          ]),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: const Color(0xD9140E0A), borderRadius: BorderRadius.circular(8)),
          child: Text(_short(s.title), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
        ),
      ]),
    ),
  );
  static String _short(String t) => t.split(' — ').first.split(' & ').first;
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
          Row(children: [
            Container(
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: BL.gold, width: 2), boxShadow: BL.shadow(.25)),
              child: SpotIcon(s, size: 52),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.title, style: BL.display(22)),
                Text(s.titleFa, textDirection: TextDirection.rtl, style: BL.fa(14, color: BL.muted)),
              ]),
            ),
          ]),
          const SizedBox(height: 6),
          Text('${ls.length} lessons here  ·  $done done', style: const TextStyle(color: BL.muted, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('spot-start'),
            onPressed: next == null ? null : () => open(sheet, next),
            style: FilledButton.styleFrom(backgroundColor: BL.red, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(next == null ? 'Locked for now — keep going on the course' : 'Start: ${next.title}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
          const SizedBox(height: 10),
          for (final l in ls)
            Builder(builder: (_) {
              final isOpen = ctrl.lessonOpen(c.course, l), isDone = ctrl.lessonDone(l);
              return ListTile(
                key: ValueKey('spot-lesson-${l.id}'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Opacity(opacity: isOpen ? 1 : .45, child: Avatar(c.character(l.lead), size: 40)),
                title: Text(l.title, style: TextStyle(fontWeight: FontWeight.w700, color: isOpen ? BL.ink : BL.muted)),
                subtitle: Text('${lessonWhere(c.course, l)}  ·  ${l.titleFa}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                trailing: Icon(isDone ? Icons.check_circle_rounded : (isOpen ? Icons.play_circle_fill_rounded : Icons.lock_rounded), color: isDone ? BL.green : (isOpen ? BL.red : BL.muted)),
                onTap: () {
                  if (isOpen) return open(sheet, l);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2), content: Text('"${l.title}" unlocks as you go — ${lessonWhere(c.course, l)}.')));
                },
              );
            }),
        ],
      ),
    ),
  );
}
