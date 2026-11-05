import 'dart:io';

import 'package:british_life/core/models/learner_profile.dart';
import 'package:british_life/features/legal/legal_screen.dart';
import 'package:british_life/features/shared/share.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('invite link has no tracking or referral code and is bilingual', () {
    expect(inviteUrl, startsWith('https://'));
    expect(inviteUrl.contains('?'), isFalse);
    final t = inviteText();
    expect(t, contains(inviteUrl));
    expect(RegExp(r'[\u0600-\u06FF]').hasMatch(t), isTrue);
    expect(t.toLowerCase().contains('ref='), isFalse);
  });
  test('invite is blocked for child profiles and share buttons hidden in kid mode', () {
    expect(kidBlocks('#invite'), isTrue);
    final cert = File('lib/features/premium/certificate_screen.dart').readAsStringSync();
    expect(cert, contains('if (done && !ctrl.kidMode) ...['));
    final exam = File('lib/features/grammar/exam_screen.dart').readAsStringSync();
    expect(exam, contains('if (!ctrl.kidMode) ...[const SizedBox(height: 12), CertificateShareRow('));
    expect(cert, contains('RepaintBoundary('));
  });
  test('privacy policy explains sharing', () {
    final p = privacyDoc.sections.map((s) => s.$2).join(' ');
    expect(p, contains('nothing is sent to us'));
    expect(p, contains('hidden in child profiles'));
  });
}
