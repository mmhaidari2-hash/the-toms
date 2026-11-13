import 'package:flutter/material.dart';

/// First strong script in [s]: Arabic-block letters are RTL; Latin, Cyrillic, Indic and CJK are LTR.
TextDirection? scriptDirection(String s) {
  for (final c in s.runes) {
    if ((c >= 0x0590 && c <= 0x08FF) ||
        (c >= 0xFB1D && c <= 0xFDFF) ||
        (c >= 0xFE70 && c <= 0xFEFF)) {
      return TextDirection.rtl;
    }
    if ((c >= 0x41 && c <= 0x5A) ||
        (c >= 0x61 && c <= 0x7A) ||
        (c >= 0x00C0 && c <= 0x024F) ||
        (c >= 0x0400 && c <= 0x052F) ||
        (c >= 0x0900 && c <= 0x0DFF) ||
        (c >= 0x1000 && c <= 0x109F) ||
        (c >= 0x1200 && c <= 0x137F) ||
        (c >= 0x4E00 && c <= 0x9FFF) ||
        (c >= 0xAC00 && c <= 0xD7AF) ||
        (c >= 0x3400 && c <= 0x4DBF)) {
      return TextDirection.ltr;
    }
  }
  return null;
}

/// Wraps a run in a Unicode bidi isolate so mixed EN+FA on one line keep their own direction.
String bidiIsolate(String s) {
  final d = scriptDirection(s);
  if (d == null) return s;
  const lri = '\u2066', rli = '\u2067', pdi = '\u2069';
  return '${d == TextDirection.rtl ? rli : lri}$s$pdi';
}

final _split = RegExp(r'(\s*(?:·|•|\n|\||—)\s*)');

/// English and helper-language (FA/AR/UR/PS, …) pieces of a composed "EN · FA" string.
List<String> bilingualParts(String text) {
  if (text.isEmpty) return const [];
  final parts = <String>[];
  var last = 0;
  for (final m in _split.allMatches(text)) {
    if (m.start > last) parts.add(text.substring(last, m.start).trim());
    last = m.end;
  }
  if (last < text.length) parts.add(text.substring(last).trim());
  return [for (final p in parts) if (p.isNotEmpty) p];
}

bool _mixed(List<String> parts) {
  TextDirection? seen;
  for (final p in parts) {
    final d = scriptDirection(p);
    if (d == null) continue;
    if (seen == null) {
      seen = d;
    } else if (seen != d) {
      return true;
    }
  }
  return false;
}

/// Renders a bilingual EN+FA (or other helper) string with each run in its own [TextDirection].
/// Mixed-script lines stack by default so "Now you are Vida · نقش عوض شد" does not wrap mid-bidi.
class BilingualText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  /// When false, pieces stay on one line, each wrapped in a bidi isolate.
  final bool stackMixed;
  const BilingualText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.stackMixed = true,
  });

  @override
  Widget build(BuildContext context) {
    final parts = bilingualParts(text);
    if (parts.length < 2 || !_mixed(parts)) {
      final d = scriptDirection(text);
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        textDirection: d,
      );
    }
    if (!stackMixed) {
      return Text(
        parts.map(bidiIsolate).join('  ·  '),
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }
    final align = textAlign ?? TextAlign.center;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: switch (align) {
        TextAlign.left || TextAlign.start => CrossAxisAlignment.start,
        TextAlign.right || TextAlign.end => CrossAxisAlignment.end,
        _ => CrossAxisAlignment.center,
      },
      children: [
        for (var i = 0; i < parts.length; i++)
          Text(
            parts[i],
            style: i == 0 ? style : (style ?? const TextStyle()).copyWith(fontSize: (style?.fontSize ?? 14) * .95),
            textAlign: align,
            textDirection: scriptDirection(parts[i]),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}
