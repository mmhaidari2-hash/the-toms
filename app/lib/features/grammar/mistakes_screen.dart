import 'package:british_life/core/i18n/helper_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../shared/nav.dart';
import 'grammar_data.dart';

/// A lesson pack outside the class ladder: always open, each lesson with practice and a mini test.
class LessonPackScreen extends ConsumerWidget {
  final FutureProvider<List<GTopic>> source;
  final String listKey, kicker, title, titleFa, blurb, blurbFa, back;
  final List<Widget> header;
  const LessonPackScreen({super.key, required this.source, required this.listKey, required this.kicker, required this.title, required this.titleFa, required this.blurb, required this.blurbFa, this.back = '/school', this.header = const []});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(source).value;
    ref.watch(progressProvider);
    if (topics == null) return const NavLoading();
    final ctrl = ref.read(progressProvider.notifier);
    final done = topics.where((t) => ctrl.grammarPassed(t.id)).length;
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: BL.cream,
      body: ListView(
        key: ValueKey(listKey),
        padding: EdgeInsets.fromLTRB(20, pad.top + 6, 20, pad.bottom + 32),
        children: [
          Row(children: [NavBack(fallback: back), const SizedBox(width: 10), Expanded(child: Text(kicker, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w800, color: BL.red)))]),
          const SizedBox(height: 12),
          Text(title, style: BL.display(24)),
          Text(hl(titleFa), textDirection: helperDir, style: BL.fa(14, color: BL.muted)),
          const SizedBox(height: 6),
          Text(hl('$blurb $done of ${topics.length} passed.'), key: const ValueKey('pack-progress'), style: const TextStyle(fontSize: 13.5, height: 1.35, color: BL.ink)),
          Text(hl('$blurbFa $done از ${topics.length} گذرانده شده.'), textDirection: helperDir, style: BL.fa(12, color: BL.muted)),
          ...header,
          const SizedBox(height: 16),
          for (final (n, t) in topics.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: BL.paper,
                borderRadius: BorderRadius.circular(16),
                child: ListTile(
                  key: ValueKey('pack-${t.id}'),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: CircleAvatar(
                    backgroundColor: ctrl.grammarPassed(t.id) ? BL.green : BL.mist,
                    child: ctrl.grammarPassed(t.id) ? const Icon(Icons.check_rounded, color: Colors.white) : Text('${n + 1}', style: const TextStyle(fontWeight: FontWeight.w800, color: BL.ink)),
                  ),
                  title: Text(hl(t.title), style: const TextStyle(fontWeight: FontWeight.w800, color: BL.ink, fontSize: 14.5)),
                  subtitle: Text(hl(t.titleFa), textDirection: helperDir, style: BL.fa(12, color: BL.muted)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: BL.muted),
                  onTap: () => context.push('/grammar/${t.id}'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Common mistakes of Persian speakers": ten short lessons from Mrs Ellis.
class MistakesScreen extends StatelessWidget {
  const MistakesScreen({super.key});
  @override
  Widget build(BuildContext context) => LessonPackScreen(
        source: mistakesProvider,
        listKey: 'mistakes-list',
        kicker: 'COMMON MISTAKES',
        title: 'Mistakes Persian speakers often make',
        titleFa: 'اشتباهات رایج فارسی‌زبان‌ها در انگلیسی',
        blurb: 'Short lessons on the mistakes that come from Persian: articles, he/she, word order, sounds and more.',
        blurbFa: 'درس‌های کوتاه دربارهٔ اشتباه‌هایی که از فارسی می‌آیند: حرف تعریف، he/she، ترتیب کلمات، تلفظ و…',
      );
}

/// IELTS Life Skills A1–B1 preparation: which level is for which visa, the 2027 change, and eight lessons.
class LifeSkillsScreen extends StatelessWidget {
  const LifeSkillsScreen({super.key});
  static const links = [
    ('Test format (ielts.org)', 'https://ielts.org/take-a-test/test-types/ielts-tests-for-uk-visas-and-immigration/ielts-life-skills-test/life-skills-test-format-in-detail'),
    ('Approved English tests (GOV.UK)', 'https://www.gov.uk/guidance/prove-your-english-language-abilities-with-a-secure-english-language-test-selt'),
    ('English for citizenship and settling (GOV.UK)', 'https://www.gov.uk/english-language'),
  ];
  static const levels = [
    ('A1', 'First family visa (partner or parent of a settled person)', 'ویزای اول خانوادگی (همسر یا والدِ فرد مقیم)'),
    ('A2', 'Extending that family visa', 'تمدید همان ویزای خانوادگی'),
    ('B1', 'Settlement before 26 March 2027, and citizenship', 'اقامت دائم پیش از ۲۶ مارس ۲۰۲۷، و شهروندی'),
  ];
  @override
  Widget build(BuildContext context) => LessonPackScreen(
        source: lifeSkillsProvider,
        listKey: 'lifeskills-list',
        kicker: 'IELTS LIFE SKILLS · A1–B1',
        title: 'IELTS Life Skills prep',
        titleFa: 'آمادگی آزمون IELTS Life Skills',
        blurb: 'The speaking and listening test for UK family visas, settlement and citizenship: how it works and what to say.',
        blurbFa: 'آزمون گفتار و شنیدار برای ویزای خانوادگی، اقامت دائم و شهروندی: روند آزمون و جمله‌های لازم.',
        back: '/lifeuk',
        header: [
          const SizedBox(height: 14),
          Container(
            key: const ValueKey('ls-levels'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: BL.paper, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Which level is usually asked for', style: TextStyle(fontWeight: FontWeight.w800, color: BL.ink, fontSize: 14)),
              Text(hl('معمولاً کدام سطح خواسته می‌شود'), textDirection: helperDir, style: BL.fa(12, color: BL.muted)),
              const SizedBox(height: 8),
              for (final (lv, en, fa) in levels)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: 34, padding: const EdgeInsets.symmetric(vertical: 2), alignment: Alignment.center, decoration: BoxDecoration(color: BL.green, borderRadius: BorderRadius.circular(8)), child: Text(lv, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12))),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(hl(en), style: const TextStyle(fontSize: 13, color: BL.ink, height: 1.3)), Text(hl(fa), textDirection: helperDir, style: BL.fa(11.5, color: BL.muted))])),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 10),
          Container(
            key: const ValueKey('ls-2027'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFFFF3E6), borderRadius: BorderRadius.circular(16), border: Border.all(color: BL.red.withValues(alpha: .35))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(hl('Change from 26 March 2027: settlement on many routes needs B2 speaking and listening. Life Skills only goes up to B1, so for those applications you will need a different approved test. Always check the live GOV.UK rules for your route.'), style: const TextStyle(fontSize: 13, color: BL.ink, height: 1.35)),
              const SizedBox(height: 4),
              Text(hl('تغییر از ۲۶ مارس ۲۰۲۷: اقامت دائم در بسیاری از مسیرها گفتار و شنیدار B2 لازم دارد. Life Skills فقط تا B1 است، پس برای آن درخواست‌ها آزمون تأییدشدهٔ دیگری لازم است. همیشه قوانین فعلی GOV.UK را برای مسیر خودتان چک کنید.'), textDirection: helperDir, style: BL.fa(12, color: BL.muted)),
            ]),
          ),
          const SizedBox(height: 8),
          Text(hl('Practice only: New Life UK is not an approved test and does not give immigration advice. Book the real test only with the official provider.'), key: const ValueKey('ls-disclaimer'), style: const TextStyle(fontSize: 12, color: BL.muted, height: 1.35)),
          Text(hl('فقط تمرین: New Life UK آزمون تأییدشده نیست و مشاورهٔ مهاجرتی نمی‌دهد. آزمون واقعی را فقط از برگزارکنندهٔ رسمی رزرو کنید.'), textDirection: helperDir, style: BL.fa(11.5, color: BL.muted)),
          Wrap(spacing: 4, children: [
            for (final (label, url) in links) TextButton.icon(onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication), icon: const Icon(Icons.open_in_new_rounded, size: 16), label: Text(label, style: const TextStyle(fontSize: 12.5))),
          ]),
        ],
      );
}
