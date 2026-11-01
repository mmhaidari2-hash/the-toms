import 'dart:convert';
import 'dart:io';

import 'package:british_life/core/i18n/coverage.g.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fails the gate if a language that was independently promoted to READY
/// (tool/i18n/ready_pin.json) is missing from helperComplete after build_tables.
/// Root cause of the 2026-10-31 cadence regression: build_tables rebuilt
/// helperComplete from stale automated quality.json and demoted hi/ps.
void main() {
  test('pinned READY languages stay in helperComplete', () {
    final f = File('tool/i18n/ready_pin.json');
    expect(f.existsSync(), isTrue, reason: 'ready_pin.json must exist');
    final raw = jsonDecode(f.readAsStringSync());
    final pinned = raw is Map
        ? raw.keys.cast<String>().toList()
        : (raw as List).cast<String>();
    expect(pinned, isNotEmpty);
    for (final code in pinned) {
      expect(
        helperComplete.contains(code),
        isTrue,
        reason: '$code is pinned READY but missing from helperComplete — '
            'cadence must not demote via stale quality.json; put it in beta_hold.json to demote deliberately',
      );
      expect(
        (helperCoverage[code] ?? 0) >= 0.85,
        isTrue,
        reason: '$code pinned READY but coverage ${(helperCoverage[code] ?? 0)} < 0.85',
      );
    }
  });
}
