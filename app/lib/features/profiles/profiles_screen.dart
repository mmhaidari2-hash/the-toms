import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/i18n/helper_text.dart';
import '../../core/models/learner_profile.dart';
import '../shared/nav.dart';

/// Parent–child dual profiles on one device: separate calm progress, kid-friendly mode.
class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    final pad = MediaQuery.paddingOf(context);
    final profiles = ctrl.allProfiles;
    final active = ctrl.profile;

    return Scaffold(
      key: const ValueKey('profiles-screen'),
      backgroundColor: BL.cream,
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, pad.top + 6, 20, pad.bottom + 32),
        children: [
          const Row(
            children: [
              NavButtons(),
              SizedBox(width: 10),
              Text(
                'PROFILES',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w800,
                  color: BL.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(hl('Who is learning?'), style: BL.display(26)),
          Text(
            hl('هر کسی روی این دستگاه پیشرفت آرام و جدا دارد'),
            textDirection: helperDir,
            style: BL.fa(13.5, color: BL.muted),
          ),
          const SizedBox(height: 6),
          Text(
            hl(
              'Parent and child can share one phone. Streaks and lessons stay separate. '
              'Kid mode hides adult paperwork practice. Profiles stay locally; online downloads still contact the host. See Privacy before using optional speech services with children.',
            ),
            style: const TextStyle(fontSize: 13.5, height: 1.45, color: BL.ink),
          ),
          Text(
            hl(
              'والد و فرزند می‌توانند یک گوشی را شریک شوند. رکورد روزانه و درس‌ها جدا می‌مانند. '
              'حالت کودک تمرین فرم بزرگسال را پنهان می‌کند. پروفایل محلی است، اما دانلود به میزبان وصل می‌شود. پیش از گفتار اختیاری کودک، حریم خصوصی را بخوانید.',
            ),
            textDirection: helperDir,
            style: BL.fa(12.5, color: BL.muted),
          ),
          const SizedBox(height: 14),
          for (final p in profiles)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: p.id == active?.id ? const Color(0xFFFFF4D6) : BL.paper,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  key: ValueKey('profile-${p.id}'),
                  borderRadius: BorderRadius.circular(18),
                  onTap: () async {
                    if (p.id == active?.id) return;
                    await ctrl.switchProfile(p.id);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: p.isChild
                              ? const Color(0xFFD6EAF8)
                              : BL.navy,
                          child: Icon(
                            p.isChild
                                ? Icons.child_care_rounded
                                : Icons.person_rounded,
                            color: p.isChild ? BL.navy : Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hl(p.displayName),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                              Text(
                                hl(
                                  p.isChild
                                      ? 'Kid-friendly · calm park & stories'
                                      : 'Adult · forms, settlement, full map',
                                ),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: BL.muted,
                                ),
                              ),
                              Text(
                                hl(
                                  p.isChild
                                      ? 'حالت کودک · پارک و داستان‌های آرام'
                                      : 'بزرگسال · فرم‌ها، اقامت، نقشهٔ کامل',
                                ),
                                textDirection: helperDir,
                                style: BL.fa(11.5, color: BL.muted),
                              ),
                            ],
                          ),
                        ),
                        if (p.id == active?.id)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: BL.green,
                            size: 28,
                          )
                        else
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: BL.muted,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (profiles.length < 4) ...[
            const SizedBox(height: 6),
            OutlinedButton.icon(
              key: const ValueKey('add-child-profile'),
              onPressed: () => _add(context, ref, ProfileKind.child),
              icon: const Icon(Icons.child_care_rounded),
              label: Text(hl('Add child profile')),
            ),
            TextButton(
              key: const ValueKey('add-adult-profile'),
              onPressed: () => _add(context, ref, ProfileKind.adult),
              child: Text(hl('Add another adult profile')),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            key: const ValueKey('profiles-privacy'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: BL.paper,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BL.mist),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hl('Privacy note'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'A child profile keeps a name and learning progress on this device. We do not create a learner account, and this app does not upload that profile to a server of ours. Downloading lesson audio can still contact the audio host. Switching profiles is not a lock for parents or carers. See Privacy for the UK Children\'s Code note.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: BL.ink,
                  ),
                ),
                Text(
                  'پروفایل کودک نام و پیشرفت یادگیری را روی همین دستگاه نگه می‌دارد. حساب یادگیرنده نمی‌سازیم و این برنامه آن پروفایل را به سرور ما نمی‌فرستد. دانلود صدای درس هنوز می‌تواند به میزبان صدا وصل شود. عوض کردن پروفایل قفل والد یا سرپرست نیست.',
                  textDirection: helperDir,
                  style: BL.fa(12, color: BL.muted),
                ),
                TextButton(
                  onPressed: () => context.push('/legal?tab=privacy'),
                  child: Text(hl('Open privacy policy')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    ProfileKind kind,
  ) async {
    final nameCtrl = TextEditingController(
      text: kind == ProfileKind.child ? 'Child' : 'Me',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          hl(kind == ProfileKind.child ? 'Child profile' : 'Adult profile'),
        ),
        content: TextField(
          controller: nameCtrl,
          decoration: InputDecoration(labelText: hl('Display name')),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(hl('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(hl('Add')),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final ctrl = ref.read(progressProvider.notifier);
    final p = await ctrl.addProfile(displayName: nameCtrl.text, kind: kind);
    await ctrl.switchProfile(p.id);
  }
}
