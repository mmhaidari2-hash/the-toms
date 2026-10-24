import 'package:flutter/material.dart';

import '../../core/i18n/helper_text.dart';

/// An English word with its helper-language gloss ("reading  پڑھنا", "reading  पढ़ना"): two separate texts, each laid
/// out in its own direction, with a fixed gap, so the scripts never run together in any helper language.
/// A gloss that only repeats the English (English helper) is left out.
class GlossLabel extends StatelessWidget {
  const GlossLabel(this.en, this.fa, {super.key, required this.enStyle, required this.glossStyle, this.gap = 6});
  final String en, fa;
  final TextStyle enStyle, glossStyle;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final g = hl(fa).trim();
    String n(String x) => x.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final same = g.isEmpty || (n(g).isNotEmpty && n(g) == n(en));
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.ltr,
      children: [
        Flexible(child: Text(en, textDirection: TextDirection.ltr, style: enStyle)),
        if (!same) ...[
          SizedBox(width: gap),
          Flexible(child: Text(g, key: const ValueKey('gloss'), textDirection: helperDir, style: glossStyle)),
        ],
      ],
    );
  }
}
