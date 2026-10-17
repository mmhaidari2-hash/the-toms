import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import '../shared/nav.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/platform/voice.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/data/repository.dart';
import '../../core/models/character.dart';
import '../../core/models/place.dart';
import '../home/home_screen.dart';
import '../../core/i18n/strings.dart';
import '../shared/widgets.dart';
import '../../core/platform/loop_video.dart';
import 'ambient.dart';
import 'place_widgets.dart';

class PlaceScreen extends ConsumerWidget {
  final String placeId;
  const PlaceScreen({super.key, required this.placeId});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    backgroundColor: BL.ink,
    body: ref
        .watch(contentProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
          error: (e, _) => ErrorState(message: '$e', onRetry: () => ref.invalidate(contentProvider)),
          data: (c) {
            final p = c.place(placeId);
            if (p == null) return ErrorState(message: 'Place not found.', onRetry: () => context.go('/'));
            return _Explorer(c: c, place: p);
          },
        ),
  );
}

class _Explorer extends ConsumerStatefulWidget {
  final ContentBundle c;
  final Place place;
  const _Explorer({required this.c, required this.place});
  @override
  ConsumerState<_Explorer> createState() => _ExplorerState();
}

class _ExplorerState extends ConsumerState<_Explorer> {
  final _scroll = ScrollController();
  Hotspot? _ambient;
  Hotspot? _flash;
  bool _centred = false, _reveal = true;

  @override
  void initState() {
    super.initState();
    // Hitboxes shimmer once on arrival so people know where to tap, then vanish.
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _reveal = false);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    Voice.stop();
    super.dispose();
  }

  void _tap(Hotspot h) {
    HapticFeedback.selectionClick();
    setState(() => _flash = h);
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted && _flash == h) setState(() => _flash = null);
    });
    if (h.isProp) {
      setState(() => _ambient = h);
      Voice.say('narrator', h.prop!.phrase, rate: .9);
      return;
    }
    final ctrl = ref.read(progressProvider.notifier);
    if (h.sceneId != null) {
      final s = widget.c.scenes[h.sceneId];
      if (s != null && ctrl.canPlay(s, widget.c)) {
        context.push('/chat/${h.sceneId}');
        return;
      }
    }
    setState(() => _ambient = h);
    if (h.ambientEn != null) Voice.say(h.characterId, h.ambientEn!);
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final open = ref.read(progressProvider.notifier).placeOpen(place.id, widget.c);
    final tier = widget.c.tiers[widget.c.tierIndexOfPlace(place.id)];
    final pad = MediaQuery.paddingOf(context);
    return Stack(
      children: [
        Positioned.fill(child: place.image != null ? _painted(place) : _storybook(place)),
        // top scrim + title
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: .55), Colors.transparent]),
                    ),
                  ),
                ),
              ),
              Padding(
            padding: EdgeInsets.fromLTRB(8, pad.top + 6, 16, 28),
            child: Row(
              children: [
                const NavButtons(light: true),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(place.title, style: BL.display(21, color: Colors.white)),
                      Text(
                        place.titleFa,
                        textDirection: TextDirection.rtl,
                        style: BL.fa(12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                if (ambientSpecs[place.id]?.video != null)
                  IconButton(
                    tooltip: 'Motion',
                    onPressed: () => ref.read(progressProvider.notifier).setMotion(!ref.read(progressProvider.notifier).motionOn),
                    style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: .18)),
                    icon: Icon(ref.watch(progressProvider).missionsDone['pref:motion'] != 'off' ? Icons.motion_photos_on_rounded : Icons.motion_photos_off_rounded, color: Colors.white, size: 18),
                  ),
                LevelChip(tier.id, dark: true),
              ],
            ),
          ),
            ],
          ),
        ),
        // bottom: gradient (never absorbs taps) + ambient card + character strip fallback
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withValues(alpha: .65), Colors.transparent]),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 36, 16, pad.bottom + 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (c, a) => FadeTransition(
                        opacity: a,
                        child: SlideTransition(position: Tween(begin: const Offset(0, .25), end: Offset.zero).animate(a), child: c),
                      ),
                      child: !open
                          ? _hint(Icons.lock_rounded, 'This place is still locked', 'این مکان هنوز قفل است', key: 'lock')
                          : _ambient == null
                          ? const SizedBox.shrink(key: ValueKey('none'))
                          : _ambientCard(_ambient!),
                    ),
                    if (open) ...[const SizedBox(height: 12), _strip(place)],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Fallback: everyone in the painting as big avatar buttons (always reachable, also for screen readers).
  Widget _strip(Place place) {
    final done = ref.watch(progressProvider).completedScenes;
    final role = ref.watch(progressProvider).role;
    final people = place.hotspots.where((h) => !h.isProp && h.characterId != role).toList();
    // Everyone fits on one row on any phone width — no hidden, scrolled-off characters.
    return LayoutBuilder(
      builder: (context, box) {
        final itemW = (box.maxWidth / people.length).clamp(0.0, 74.0);
        final av = (itemW - 22).clamp(30.0, 46.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final h in people)
              SizedBox(
                width: itemW,
                child: Pressable(
                  onTap: () => _tap(h),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: h.sceneId != null && !done.contains(h.sceneId) ? const Color(0xFFE9B949) : Colors.white38, width: 2),
                        ),
                        child: Avatar(widget.c.character(h.characterId), size: av, ring: false),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.c.character(h.characterId).name.split(' ').first,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _hint(IconData i, String en, String fa, {required String key}) => Center(
    key: ValueKey(key),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(i, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  en,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                Text(
                  fa,
                  textDirection: TextDirection.rtl,
                  style: BL.fa(11.5, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _ambientCard(Hotspot h) {
    final lang = ref.read(progressProvider).lang;
    final prop = h.prop;
    final ch = prop == null ? widget.c.character(h.characterId) : null;
    final s = h.sceneId == null ? null : widget.c.scenes[h.sceneId];
    final locked = s != null;
    String lockMsg() {
      if (s == null) return '';
      if (s.requiresTrust != null) return tr(lang, 'privateStory');
      if (widget.c.roleOfScene(s.id) != null) return tr(lang, 'roleStory');
      return tr(lang, 'lockedLevel');
    }

    const gold = Color(0xFFE8C987);
    Widget say(String en, String? fa) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(en, style: BL.display(16.5, color: const Color(0xFFFBF3E4), w: FontWeight.w500)),
        if (fa != null) SizedBox(width: double.infinity, child: Text(fa, textDirection: TextDirection.rtl, style: BL.fa(12.5, color: Colors.white54))),
      ],
    );
    return ClipRRect(
      key: ValueKey(prop?.id ?? h.characterId),
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFC9A45C), width: 1.2),
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xE62A1D14), Color(0xF2140E0A)]),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (ch != null) Avatar(ch, size: 34, ring: false) else const Text('✦', style: TextStyle(color: gold, fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: ch?.name ?? prop!.word, style: BL.display(16, color: gold)),
                          TextSpan(text: '   ${ch?.role ?? prop!.fa}', style: BL.fa(12, color: Colors.white54)),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(onTap: () => setState(() => _ambient = null), child: const Icon(Icons.close_rounded, size: 18, color: Colors.white38)),
                ],
              ),
              const SizedBox(height: 10),
              if (prop != null) ...[
                Text('BRITISH PHRASE', style: const TextStyle(color: Color(0xFFC9A45C), fontSize: 10, letterSpacing: 1.3, fontWeight: FontWeight.w800)),
                say('“${prop.phrase}”', prop.phraseFa),
                const SizedBox(height: 8),
                for (final m in prop.mini)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: m[0] == 'me' ? 'You  ' : '${widget.c.characterOrNull(m[0])?.name ?? m[0]}  ', style: const TextStyle(color: gold, fontWeight: FontWeight.w700, fontSize: 13)),
                          TextSpan(text: m[1], style: const TextStyle(color: Colors.white, fontSize: 13.5)),
                        ],
                      ),
                    ),
                  ),
              ] else
                say(locked ? lockMsg() : '“${h.ambientEn}”', locked ? null : h.ambientFa),
              const SizedBox(height: 6),
              if (prop != null || !locked)
                TextButton.icon(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, foregroundColor: gold),
                  onPressed: () => prop != null ? Voice.say('narrator', prop.phrase, rate: .9) : Voice.say(h.characterId, h.ambientEn ?? ''),
                  icon: const Icon(Icons.volume_up_rounded, size: 16),
                  label: Text(tr(lang, 'listen')),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Painted illustration: fill the height, pan horizontally, hotspots in image space.
  Widget _painted(Place place) => LayoutBuilder(
    builder: (context, box) {
      // Show ~60% of the screen height so a portrait phone sees a wide slice; pan for the rest.
      // Portrait: ~60% of the height, pan sideways. Landscape: fill the height (minus chrome) so every
      // tap area stays on screen; never let the painting overflow vertically.
      final landscape = box.maxWidth > box.maxHeight;
      var h = box.maxHeight * (landscape ? .82 : .6), w = h * place.aspect;
      if (w < box.maxWidth) {
        w = box.maxWidth;
        h = w / place.aspect;
      }
      if (h > box.maxHeight) {
        h = box.maxHeight;
        w = h * place.aspect;
      }
      if (!_centred) {
        _centred = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) _scroll.jumpTo((_scroll.position.maxScrollExtent / 2));
        });
      }
      return Stack(
        children: [
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Image.asset(place.image!, fit: BoxFit.cover, color: Colors.black.withValues(alpha: .35), colorBlendMode: BlendMode.darken),
            ),
          ),
          SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: w,
              height: box.maxHeight,
              child: Stack(
                children: [
                  Positioned(
                    top: (box.maxHeight - h) / 2,
                    left: 0,
                    width: w,
                    height: h,
                    child: DecoratedBox(
                      decoration: BoxDecoration(boxShadow: BL.shadow(.5)),
                      child: Image.asset(place.image!, fit: BoxFit.fill),
                    ),
                  ),
                  if (ambientSpecs[place.id]?.video != null && ambientAllowed(context, ref.watch(progressProvider).missionsDone['pref:motion'] != 'off'))
                    Positioned(
                      top: (box.maxHeight - h) / 2,
                      left: 0,
                      width: w,
                      height: h,
                      child: ambientSpecs[place.id]!.video != null
                          ? LoopVideo(asset: ambientSpecs[place.id]!.video!, poster: place.image!.replaceFirst('assets/', ''))
                          : AmbientLayer(image: place.image!, spec: ambientSpecs[place.id]!),
                    ),
                  // One tap target over the whole painting: map the tap to image space and test polygons.
                  // (Per-hotspot ClipPath detectors missed taps on iOS Safari; this is robust and pan-friendly.)
                  Positioned(
                    top: (box.maxHeight - h) / 2,
                    left: 0,
                    width: w,
                    height: h,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (d) {
                        final hs = hitTest(place.hotspots.where((x) => x.characterId != ref.read(progressProvider).role), d.localPosition.dx / w, d.localPosition.dy / h);
                        if (hs != null) _tap(hs);
                      },
                      child: IgnorePointer(
                        child: CustomPaint(painter: _Outlines(place.hotspots, _reveal ? null : _flash, _reveal)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );

  // No painting yet: storybook backdrop with illustrated characters standing in.
  Widget _storybook(Place place) {
    final done = ref.watch(progressProvider).completedScenes;
    return Stack(
      children: [
        Positioned.fill(child: StorybookBackdrop(place: place, iconSize: 220)),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 28,
            runSpacing: 28,
            children: [for (final h in place.hotspots.where((h) => !h.isProp)) _StandIn(ch: widget.c.character(h.characterId), talk: h.sceneId != null, done: done.contains(h.sceneId), onTap: () => _tap(h))],
          ),
        ),
      ],
    );
  }
}

class _Pulse extends StatefulWidget {
  final Widget Function(double t) builder;
  const _Pulse({required this.builder});
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _c, builder: (_, _) => widget.builder(Curves.easeInOut.transform(_c.value)));
}

class _NameTag extends StatelessWidget {
  final Character ch;
  final bool talk, done;
  const _NameTag({required this.ch, required this.talk, required this.done});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
    decoration: BoxDecoration(color: BL.cream.withValues(alpha: .95), borderRadius: BorderRadius.circular(99), boxShadow: BL.shadow(.25)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(shape: BoxShape.circle, color: done ? BL.green : (talk ? BL.red : BL.muted)),
          child: Icon(done ? Icons.check_rounded : (talk ? Icons.chat_bubble_rounded : Icons.format_quote_rounded), size: 11, color: Colors.white),
        ),
        const SizedBox(width: 5),
        Text(
          ch.name,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: BL.ink),
        ),
      ],
    ),
  );
}

class _StandIn extends StatelessWidget {
  final Character ch;
  final bool talk, done;
  final VoidCallback onTap;
  const _StandIn({required this.ch, required this.talk, required this.done, required this.onTap});
  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: _Pulse(
      builder: (t) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: BL.gold.withValues(alpha: .25 + .3 * t),
                  blurRadius: 24 + 14 * t,
                  spreadRadius: 2 + 4 * t,
                ),
              ],
            ),
            child: Avatar(ch, size: 120),
          ),
          const SizedBox(height: 12),
          _NameTag(ch: ch, talk: talk, done: done),
          const SizedBox(height: 4),
          Text(
            ch.role,
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

/// Point-in-polygon over hotspots (normalised image coords). Props win over people (they sit on top).
Hotspot? hitTest(Iterable<Hotspot> spots, double x, double y) {
  bool inside(List<List<double>> p) {
    var c = false;
    for (var i = 0, j = p.length - 1; i < p.length; j = i++) {
      if ((p[i][1] > y) != (p[j][1] > y) && x < (p[j][0] - p[i][0]) * (y - p[i][1]) / (p[j][1] - p[i][1]) + p[i][0]) c = !c;
    }
    return c;
  }

  List<List<double>> poly(Hotspot h) {
    if (h.shape != null) return h.shape!;
    final r = h.rect!;
    return [[r[0], r[1]], [r[0] + r[2], r[1]], [r[0] + r[2], r[1] + r[3]], [r[0], r[1] + r[3]]];
  }

  final list = spots.where((h) => h.rect != null || h.shape != null).toList();
  for (final h in list.where((h) => h.isProp)) {
    if (inside(poly(h))) return h;
  }
  // Overlapping figures: the smallest (most specific) shape that contains the tap wins.
  double area(List<List<double>> p) {
    var a = 0.0;
    for (var i = 0, j = p.length - 1; i < p.length; j = i++) {
      a += (p[j][0] + p[i][0]) * (p[j][1] - p[i][1]);
    }
    return a.abs() / 2;
  }

  Hotspot? best;
  for (final h in list.where((h) => !h.isProp)) {
    if (inside(poly(h)) && (best == null || area(poly(h)) < area(poly(best)))) best = h;
  }
  return best;
}

/// Soft outlines: all of them shimmer on arrival, then only the tapped one flashes.
class _Outlines extends CustomPainter {
  final List<Hotspot> spots;
  final Hotspot? flash;
  final bool all;
  _Outlines(this.spots, this.flash, this.all);
  @override
  void paint(Canvas c, Size s) {
    for (final h in spots) {
      if (!all && h != flash) continue;
      final r = h.rect;
      if (r == null) continue;
      final pts = h.shape ?? [[r[0], r[1]], [r[0] + r[2], r[1]], [r[0] + r[2], r[1] + r[3]], [r[0], r[1] + r[3]]];
      final p = Path();
      for (var i = 0; i < pts.length; i++) {
        final o = Offset(pts[i][0] * s.width, pts[i][1] * s.height);
        i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
      }
      p.close();
      final col = h.isProp ? const Color(0xFFE9B949) : Colors.white;
      c.drawPath(p, Paint()..color = col.withValues(alpha: .10));
      c.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = col.withValues(alpha: .55)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }
  }

  @override
  bool shouldRepaint(covariant _Outlines o) => o.flash != flash || o.all != all;
}
