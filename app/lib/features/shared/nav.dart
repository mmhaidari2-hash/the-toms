import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/platform/history.dart';

/// Back to the previous screen; if there is none (deep link, refresh), fall back so we never dead-end.
void goBack(BuildContext context, [String fallback = '/']) {
  if (context.canPop()) {
    if (!historyBack()) context.pop();
  } else {
    context.go(fallback);
  }
}

/// Large, labelled back button for the top-left of every screen.
class NavBack extends StatelessWidget {
  final bool light;
  final String fallback;
  final VoidCallback? onTap;
  const NavBack({super.key, this.light = false, this.fallback = '/', this.onTap});
  @override
  Widget build(BuildContext context) {
    final fg = light ? Colors.white : BL.ink;
    return Semantics(
      button: true,
      label: 'Back',
      child: Material(
        key: const ValueKey('nav-back'),
        color: light ? Colors.black.withValues(alpha: .38) : Colors.black.withValues(alpha: .06),
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap ?? () => goBack(context, fallback),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: fg),
                const SizedBox(width: 4),
                Text('Back', style: TextStyle(color: fg, fontSize: 15, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round "map" button: always returns to the home map.
class NavHome extends StatelessWidget {
  final bool light;
  const NavHome({super.key, this.light = false});
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Map',
    child: Material(
      key: const ValueKey('nav-home'),
      color: light ? Colors.black.withValues(alpha: .38) : Colors.black.withValues(alpha: .06),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => context.go('/'),
        child: SizedBox(width: 44, height: 44, child: Icon(Icons.map_rounded, size: 22, color: light ? Colors.white : BL.ink)),
      ),
    ),
  );
}

/// Back + Map, side by side.
class NavButtons extends StatelessWidget {
  final bool light;
  final String fallback;
  final VoidCallback? onBack;
  const NavButtons({super.key, this.light = false, this.fallback = '/', this.onBack});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    NavBack(light: light, fallback: fallback, onTap: onBack),
    const SizedBox(width: 6),
    NavHome(light: light),
  ]);
}

/// Loading placeholder that still offers a way back (never a dead end).
class NavLoading extends StatelessWidget {
  const NavLoading({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Stack(children: const [
      Center(child: CircularProgressIndicator()),
      Positioned(top: 6, left: 8, child: NavButtons()),
    ])),
  );
}
