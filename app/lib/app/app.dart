import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

class BritishLifeApp extends StatelessWidget {
  const BritishLifeApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'The Toms: British Life Immersion',
    debugShowCheckedModeBanner: false,
    theme: BL.theme(),
    routerConfig: router,
    builder: (context, child) => ColoredBox(
      color: const Color(0xFFE9E2D6),
      // Keep a phone-width column on tablets/desktop browsers.
      child: Center(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: child),
      ),
    ),
  );
}
