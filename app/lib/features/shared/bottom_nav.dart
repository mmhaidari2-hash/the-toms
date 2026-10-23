import 'package:british_life/core/i18n/helper_text.dart';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/providers.dart';
import '../../core/engine/leitner.dart';

/// The three home tabs, always one tap away: My path (the roadmap), Town (the map) and Leitner (word box).
/// Frosted glass over the content; a single BackdropFilter keeps it cheap on phones.
enum HomeTab { path, town, leitner }

const homeTabRoutes = {HomeTab.path: '/course', HomeTab.town: '/', HomeTab.leitner: '/leitner'};
const bottomNavHeight = 64.0;

class TomsBottomNav extends ConsumerWidget {
  final HomeTab current;
  final bool dark;
  const TomsBottomNav({super.key, required this.current, this.dark = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final box = ref.watch(progressProvider).leitnerBox;
    final due = box.isEmpty ? 0 : Leitner.due(box.values, DateTime.now()).length;
    final pad = MediaQuery.paddingOf(context).bottom;
    final fg = dark ? Colors.white : const Color(0xFF2A1E16);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          key: const ValueKey('bottom-nav'),
          padding: EdgeInsets.only(bottom: pad),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: dark
                  ? [const Color(0x8C2A1F18), const Color(0xB3140E0A)]
                  : [const Color(0xD9FFFBF3), const Color(0xF2F6ECDD)],
            ),
            border: Border(top: BorderSide(color: dark ? Colors.white24 : const Color(0x1F2A1E16), width: .8)),
          ),
          child: SizedBox(
            height: bottomNavHeight,
            child: Row(children: [
              _Tab(tab: HomeTab.path, icon: Icons.route_rounded, en: 'My path', fa: 'مسیر من', current: current, fg: fg),
              _Tab(tab: HomeTab.town, icon: Icons.location_city_rounded, en: 'Town', fa: 'شهر', current: current, fg: fg),
              _Tab(tab: HomeTab.leitner, icon: Icons.inventory_2_rounded, en: 'Leitner', fa: 'لایتنر', current: current, fg: fg, badge: due),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final HomeTab tab, current;
  final IconData icon;
  final String en, fa;
  final Color fg;
  final int badge;
  const _Tab({required this.tab, required this.icon, required this.en, required this.fa, required this.current, required this.fg, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    final on = tab == current;
    const red = Color(0xFFC8102E);
    return Expanded(
      child: Semantics(
        button: true,
        selected: on,
        label: en,
        child: InkWell(
          key: ValueKey('tab-${tab.name}'),
          onTap: on ? null : () => context.go(homeTabRoutes[tab]!),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Stack(clipBehavior: Clip.none, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: on ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFE0344F), red]) : null,
                  boxShadow: on ? const [BoxShadow(color: Color(0x55C8102E), blurRadius: 10, offset: Offset(0, 3))] : null,
                ),
                child: Icon(icon, size: 22, color: on ? Colors.white : fg.withValues(alpha: .72)),
              ),
              if (badge > 0)
                Positioned(
                  right: 4, top: -4,
                  child: Container(
                    key: const ValueKey('leitner-badge'),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 18),
                    decoration: BoxDecoration(color: const Color(0xFF1F7A4D), borderRadius: BorderRadius.circular(9), border: Border.all(color: Colors.white, width: 1.4)),
                    child: Text(hl(badge > 99 ? '99+' : '$badge'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                  ),
                ),
            ]),
            const SizedBox(height: 3),
            Text(hl('$en · $fa'), maxLines: 1, style: TextStyle(fontSize: 11, fontWeight: on ? FontWeight.w900 : FontWeight.w700, color: on ? (fg == Colors.white ? Colors.white : red) : fg.withValues(alpha: .72))),
          ]),
        ),
      ),
    );
  }
}
