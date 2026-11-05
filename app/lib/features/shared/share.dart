import 'dart:ui' as ui;

import 'package:british_life/core/i18n/helper_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme.dart';

/// Public link used in invitations. Nothing about the learner is added to it
/// (no referral code, no tracking parameters).
const inviteUrl = 'https://mmhaidari2-hash.github.io/the-toms/';

String inviteText() =>
    'I am learning everyday British English with New Life UK: stories with Tom, Leslie and the family in Hackney. Try it free: $inviteUrl\n'
    'دارم انگلیسی روزمرهٔ بریتانیایی را با New Life UK یاد می‌گیرم؛ با داستان تام، لزلی و خانواده. رایگان امتحانش کن: $inviteUrl';

/// Opens the system share sheet. If the platform has none (some desktop
/// browsers), the text is copied to the clipboard instead.
Future<void> shareTextOrCopy(BuildContext context, String text, {String? subject}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final r = await SharePlus.instance.share(ShareParams(text: text, subject: subject));
    if (r.status != ShareResultStatus.unavailable) return;
  } catch (_) {}
  await Clipboard.setData(ClipboardData(text: text));
  messenger?.showSnackBar(SnackBar(content: Text(hl('Copied. Paste it into a message. · کپی شد؛ در پیام بچسبانید.'))));
}

Future<void> shareInvite(BuildContext context) => shareTextOrCopy(context, inviteText(), subject: 'New Life UK');

/// Captures the widget under [boundary] as a PNG and shares it with [text].
/// Falls back to sharing text only if the image cannot be made or shared.
Future<void> shareBoundaryImage(BuildContext context, GlobalKey boundary, {required String text, String fileName = 'new-life-uk-certificate.png'}) async {
  Uint8List? png;
  try {
    final ro = boundary.currentContext?.findRenderObject();
    if (ro is RenderRepaintBoundary) {
      final img = await ro.toImage(pixelRatio: 3);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      png = data?.buffer.asUint8List();
    }
  } catch (_) {}
  if (!context.mounted) return;
  if (png != null) {
    try {
      final r = await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: 'New Life UK',
          files: [XFile.fromData(png, mimeType: 'image/png', name: fileName)],
          fileNameOverrides: [fileName],
        ),
      );
      if (r.status != ShareResultStatus.unavailable) return;
    } catch (_) {}
  }
  if (!context.mounted) return;
  await shareTextOrCopy(context, text, subject: 'New Life UK');
}

/// "Share certificate" + "Invite a friend" buttons shown under a certificate.
class CertificateShareRow extends StatelessWidget {
  final GlobalKey boundary;
  final String text;
  final String keyPrefix;
  const CertificateShareRow({super.key, required this.boundary, required this.text, this.keyPrefix = 'cert'});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FilledButton.icon(
        key: ValueKey('$keyPrefix-share'),
        style: FilledButton.styleFrom(
          backgroundColor: BL.navy,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () => shareBoundaryImage(context, boundary, text: text),
        icon: const Icon(Icons.ios_share_rounded),
        label: Text(hl('Share certificate · اشتراک گواهی'), style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        key: ValueKey('$keyPrefix-invite'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () => shareInvite(context),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(hl('Invite a friend · دعوت از دوست'), style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      const SizedBox(height: 6),
      Text(
        hl('Only what you see is shared, and only when you tap. Nothing is sent to us.'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, color: BL.muted),
      ),
      Text(
        hl('فقط همین تصویر و فقط وقتی خودتان بزنید فرستاده می‌شود؛ چیزی برای ما ارسال نمی‌شود.'),
        textAlign: TextAlign.center,
        textDirection: helperDir,
        style: BL.fa(11, color: BL.muted),
      ),
    ],
  );
}
