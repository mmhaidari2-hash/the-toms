import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/i18n/helper_text.dart';
import 'bilingual_text.dart';

/// System-gesture / 3-button nav inset. Uses [MediaQuery.viewPadding], which is
/// not consumed by a parent [SafeArea], so a sheet opened from a padded screen
/// still clears the Android navigation bar.
double sheetBottomInset(BuildContext context) => MediaQuery.viewPaddingOf(context).bottom;

/// List / scroll padding that always clears the system inset, plus [extra] breathing room.
EdgeInsets sheetScrollPadding(
  BuildContext context, {
  double extra = 18,
  double left = 18,
  double right = 18,
  double top = 0,
}) =>
    EdgeInsets.fromLTRB(left, top, right, sheetBottomInset(context) + extra);

/// [SafeArea] that still sees the bottom system inset after a parent has consumed [MediaQuery.padding].
class SheetSafeArea extends StatelessWidget {
  final Widget child;
  final bool top;
  const SheetSafeArea({super.key, required this.child, this.top = false});
  @override
  Widget build(BuildContext context) => SafeArea(top: top, maintainBottomViewPadding: true, child: child);
}

/// Title or button label that wraps up to [maxLines] and shrinks slightly before ellipsizing.
class AdaptiveTitle extends StatelessWidget {
  final String text;
  final TextStyle style;
  final int maxLines;
  final double minScale;
  final TextAlign textAlign;
  const AdaptiveTitle(
    this.text, {
    super.key,
    required this.style,
    this.maxLines = 2,
    this.minScale = 0.7,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final width = box.maxWidth.isFinite ? box.maxWidth : MediaQuery.sizeOf(context).width;
      final scaler = MediaQuery.textScalerOf(context);
      final base = style.fontSize ?? 16;
      final minSize = base * minScale;
      final dir = scriptDirection(text) ?? Directionality.maybeOf(context) ?? TextDirection.ltr;
      final height = style.height ?? 1.2;
      // Merge the ambient button/theme style so TextPainter and the real Text use the same font.
      final inherited = DefaultTextStyle.of(context).style.merge(style);
      double fs = base;
      TextStyle styled(double size) => inherited.copyWith(fontSize: size, height: height);
      bool overflowed(double size) {
        final tp = TextPainter(
          text: TextSpan(text: text, style: styled(size)),
          textDirection: dir,
          maxLines: maxLines,
          textScaler: scaler,
          ellipsis: '…',
        )..layout(maxWidth: width < 1 ? 1 : width);
        return tp.didExceedMaxLines;
      }

      while (fs > minSize + 0.25 && overflowed(fs)) {
        fs -= 0.5;
      }
      return SizedBox(
        width: box.maxWidth.isFinite ? box.maxWidth : null,
        child: Text(
          text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          textDirection: dir,
          style: styled(fs),
        ),
      );
    });
  }
}

/// Two-line, shrink-to-fit label for a primary CTA (e.g. "Start: The nursery interview").
class AdaptiveCtaText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const AdaptiveCtaText(this.text, {super.key, this.style});
  @override
  Widget build(BuildContext context) => AdaptiveTitle(
        text,
        style: style ?? const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white),
        maxLines: 2,
        minScale: 0.6,
        textAlign: TextAlign.center,
      );
}

/// The place-sheet primary button. Kept here so it can be tested without editing map_spots.dart
/// while another worker has that file open; the map sheet should switch to this widget.
class SpotStartCta extends StatelessWidget {
  final String? lessonTitle;
  final VoidCallback? onPressed;
  const SpotStartCta({super.key, this.lessonTitle, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final label = hl(
      lessonTitle == null ? 'Locked for now — keep going on the course' : 'Start: $lessonTitle',
    );
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        key: const ValueKey('spot-start'),
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: BL.red,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_arrow_rounded),
            const SizedBox(width: 8),
            Flexible(child: AdaptiveCtaText(label)),
          ],
        ),
      ),
    );
  }
}

/// A sheet body whose list padding always clears [MediaQuery.viewPadding].bottom.
class SafeSheetList extends StatelessWidget {
  final List<Widget> children;
  final ScrollController? controller;
  final double extra;
  final Key? listKey;
  const SafeSheetList({
    super.key,
    required this.children,
    this.controller,
    this.extra = 18,
    this.listKey,
  });

  @override
  Widget build(BuildContext context) => ListView(
        key: listKey ?? const ValueKey('safe-sheet-list'),
        controller: controller,
        padding: sheetScrollPadding(context, extra: extra),
        children: children,
      );
}
