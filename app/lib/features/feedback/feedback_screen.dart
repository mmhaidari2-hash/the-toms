import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:british_life/core/i18n/helper_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/app_info.dart';
import '../../core/data/providers.dart';
import '../shared/nav.dart';

enum FeedbackKind { suggestion, bug, content }

const feedbackKinds = {
  FeedbackKind.suggestion: ('Suggestion', 'پیشنهاد'),
  FeedbackKind.bug: ('Bug / something broken', 'خطا / چیزی خراب است'),
  FeedbackKind.content: ('Content error (wrong English, translation or audio)', 'اشتباه محتوا (انگلیسی، ترجمه یا صدا)'),
};

/// Wraps the whole app so the feedback box can offer a screenshot of the screen the learner was on.
final screenBoundaryKey = GlobalKey(debugLabel: 'screen-boundary');

/// Screenshot taken just before the feedback box opened (in memory only; never saved or sent by itself).
abstract final class FeedbackCapture {
  static Uint8List? last;
  static String? fromScreen;

  /// Called from the menu right before opening /feedback: remembers the screen and grabs a PNG of it.
  static Future<void> grab(String screen) async {
    fromScreen = screen;
    last = null;
    try {
      final ro = screenBoundaryKey.currentContext?.findRenderObject();
      if (ro is RenderRepaintBoundary && !ro.debugNeedsPaint) {
        final img = await ro.toImage(pixelRatio: 1.5);
        last = (await img.toByteData(format: ui.ImageByteFormat.png))?.buffer.asUint8List();
      }
    } catch (_) {
      last = null;
    }
  }
}

/// Device facts added to a report. Only what the learner can see in the preview.
class FeedbackDevice {
  final String platform, os, locale, appLang, screen;
  const FeedbackDevice({required this.platform, required this.os, required this.locale, required this.appLang, required this.screen});

  static FeedbackDevice current({required String appLang, required String screen}) => FeedbackDevice(
        platform: kIsWeb ? 'web' : Platform.operatingSystem,
        os: kIsWeb ? 'browser' : Platform.operatingSystemVersion,
        locale: ui.PlatformDispatcher.instance.locale.toLanguageTag(),
        appLang: appLang,
        screen: screen,
      );
}

/// The exact text the learner sees and sends. No names, no progress data, no identifiers.
abstract final class FeedbackReport {
  static String subject(FeedbackKind k) => 'New Life UK ${AppInfo.label} – ${feedbackKinds[k]!.$1.split(' (').first}';

  static String body(FeedbackKind k, String message, FeedbackDevice d, {bool screenshot = false}) => [
        message.trim(),
        '',
        '— — —',
        'Category: ${feedbackKinds[k]!.$1}',
        'App version: ${AppInfo.label}',
        'Platform: ${d.platform}',
        'OS version: ${d.os}',
        'Locale: ${d.locale} (app helper language: ${d.appLang})',
        'Screen: ${d.screen}',
        if (screenshot) 'Screenshot: attached',
      ].join('\n');

  static Uri mailto(String to, FeedbackKind k, String body) =>
      Uri(scheme: 'mailto', path: to, query: 'subject=${Uri.encodeComponent(subject(k))}&body=${Uri.encodeComponent(body)}');
}

/// Feedback & bug-report box (owner t308): category, message, optional screenshot; everything is previewed and the
/// learner's own mail app (or share sheet, for a screenshot) sends it. No backend, nothing sent silently.
class FeedbackScreen extends ConsumerStatefulWidget {
  final String? from;
  const FeedbackScreen({super.key, this.from});
  /// Test seams.
  static Future<bool> Function(Uri)? debugLaunch;
  static Future<bool> Function(String text, String subject, Uint8List png)? debugShare;
  static String? debugEmail;
  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackState();
}

class _FeedbackState extends ConsumerState<FeedbackScreen> {
  FeedbackKind _kind = FeedbackKind.suggestion;
  final _msg = TextEditingController();
  bool _shot = false, _preview = false;
  late final Uint8List? _png = FeedbackCapture.last;

  String get _email => FeedbackScreen.debugEmail ?? SupportConfig.email;
  bool get _configured => SupportConfig.isConfigured(_email);

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  FeedbackDevice get _device => FeedbackDevice.current(appLang: ref.read(progressProvider).lang, screen: widget.from ?? FeedbackCapture.fromScreen ?? 'unknown');
  String get _body => FeedbackReport.body(_kind, _msg.text, _device, screenshot: _shot && _png != null);

  Future<void> _send() async {
    final messenger = ScaffoldMessenger.of(context);
    var ok = false;
    try {
      if (_shot && _png != null) {
        final text = 'To: $_email\n\n$_body';
        final subject = FeedbackReport.subject(_kind);
        if (FeedbackScreen.debugShare != null) {
          ok = await FeedbackScreen.debugShare!(text, subject, _png);
        } else {
          final r = await SharePlus.instance.share(ShareParams(
            text: text,
            subject: subject,
            files: [XFile.fromData(_png, mimeType: 'image/png', name: 'new-life-uk-screen.png')],
            fileNameOverrides: const ['new-life-uk-screen.png'],
          ));
          ok = r.status != ShareResultStatus.unavailable;
        }
      } else {
        final uri = FeedbackReport.mailto(_email, _kind, _body);
        ok = await (FeedbackScreen.debugLaunch ?? (u) => launchUrl(u, mode: LaunchMode.externalApplication))(uri);
      }
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(hl(ok
          ? 'Your mail app is open — check it and press send there. · برنامهٔ ایمیل باز شد؛ آن‌جا بررسی کن و ارسال را بزن.'
          : 'No mail app found. Use "Copy report" and email it to $_email. · برنامهٔ ایمیل پیدا نشد؛ «Copy report» را بزن و به $_email بفرست.')),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final canShot = !kIsWeb && _png != null;
    return Scaffold(
      key: const ValueKey('feedback'),
      backgroundColor: BL.cream,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
            child: Row(children: [
              const NavBack(fallback: '/'),
              const SizedBox(width: 4),
              Expanded(child: Text(hl('Feedback & bug report'), style: BL.display(21))),
            ]),
          ),
          Expanded(child: _preview ? _previewView() : _form(canShot)),
        ]),
      ),
    );
  }

  Widget _form(bool canShot) => ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 28), children: [
        Text(hl('Tell us what to improve or what went wrong. You will see the whole message before anything is sent, and your own mail app sends it.'), style: const TextStyle(height: 1.35)),
        Text('بگو چه چیزی بهتر شود یا چه مشکلی پیش آمد. قبل از ارسال کل پیام را می‌بینی و خود برنامهٔ ایمیلت آن را می‌فرستد.', textDirection: TextDirection.rtl, style: BL.fa(12, color: BL.muted)),
        const SizedBox(height: 14),
        Text(hl('Category · نوع'), style: const TextStyle(fontWeight: FontWeight.w800)),
        for (final e in feedbackKinds.entries)
          ListTile(
            key: ValueKey('fb-kind-${e.key.name}'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            selected: _kind == e.key,
            selectedColor: BL.red,
            leading: Icon(_kind == e.key ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded),
            onTap: () => setState(() => _kind = e.key),
            title: Text(hl(e.value.$1)),
            subtitle: Text(e.value.$2, textDirection: TextDirection.rtl, style: BL.fa(11.5, color: BL.muted)),
          ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('fb-message'),
          controller: _msg,
          minLines: 4,
          maxLines: 10,
          maxLength: 2000,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Your message · پیام تو',
            hintText: 'What happened, or what would help? Please don\'t include passwords or personal documents.',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        if (canShot)
          CheckboxListTile(
            key: const ValueKey('fb-shot'),
            contentPadding: EdgeInsets.zero,
            value: _shot,
            onChanged: (v) => setState(() => _shot = v ?? false),
            title: Text(hl('Attach a screenshot of the screen I was on (optional)')),
            subtitle: Text('پیوست تصویر صفحه‌ای که در آن بودم (اختیاری)', textDirection: TextDirection.rtl, style: BL.fa(11.5, color: BL.muted)),
          ),
        if (canShot && _shot)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(_png!, key: const ValueKey('fb-shot-preview'), height: 180, fit: BoxFit.contain)),
          ),
        const SizedBox(height: 8),
        FilledButton(
          key: const ValueKey('fb-review'),
          style: FilledButton.styleFrom(backgroundColor: BL.red, padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: _msg.text.trim().length < 3 ? null : () => setState(() => _preview = true),
          child: Text(hl('Review before sending · بازبینی قبل از ارسال')),
        ),
      ]);

  Widget _previewView() => ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 28), children: [
        Text(hl('This is exactly what will be sent · دقیقاً همین ارسال می‌شود'), style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: BL.mist)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('To: ${_configured ? _email : '—'}', key: const ValueKey('fb-to'), style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('Subject: ${FeedbackReport.subject(_kind)}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const Divider(),
            SelectableText(_body, key: const ValueKey('fb-preview'), style: const TextStyle(fontSize: 13, height: 1.35)),
            if (_shot && _png != null) ...[const SizedBox(height: 8), Image.memory(_png, height: 140, fit: BoxFit.contain)],
          ]),
        ),
        const SizedBox(height: 8),
        Text(hl(_shot && _png != null
            ? 'Your share menu opens with the screenshot attached; choose your email app. The support address is at the top of the text.'
            : 'Your email app opens with this message filled in. Nothing is sent until you press send there.'), style: const TextStyle(fontSize: 12.5, color: BL.muted)),
        Text(_shot && _png != null ? 'منوی اشتراک با تصویر پیوست باز می‌شود؛ برنامهٔ ایمیل را انتخاب کن. نشانی پشتیبانی بالای متن است.' : 'برنامهٔ ایمیلت با همین پیام باز می‌شود. تا خودت آن‌جا ارسال را نزنی چیزی فرستاده نمی‌شود.',
            textDirection: TextDirection.rtl, style: BL.fa(11.5, color: BL.muted)),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey('fb-send'),
          style: FilledButton.styleFrom(backgroundColor: BL.red, padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: _configured ? _send : null,
          icon: const Icon(Icons.mail_outline_rounded),
          label: Text(hl(_configured ? 'Open my email app · باز کردن ایمیل' : 'Not configured yet · هنوز تنظیم نشده')),
        ),
        if (!_configured)
          Padding(
            key: const ValueKey('fb-not-configured'),
            padding: const EdgeInsets.only(top: 6),
            child: Text(hl('The support email address has not been set up in this version yet. You can copy the report for later. · نشانی ایمیل پشتیبانی هنوز در این نسخه تنظیم نشده؛ می‌توانی گزارش را کپی کنی.'),
                style: const TextStyle(fontSize: 12, color: BL.muted)),
          ),
        TextButton(
          key: const ValueKey('fb-copy'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: 'Subject: ${FeedbackReport.subject(_kind)}\n\n$_body'));
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hl('Copied · کپی شد'))));
          },
          child: Text(hl('Copy report · کپی گزارش')),
        ),
        TextButton(key: const ValueKey('fb-edit'), onPressed: () => setState(() => _preview = false), child: Text(hl('Edit · ویرایش'))),
      ]);
}
