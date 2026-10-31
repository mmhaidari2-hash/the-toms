import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Map buildings -> lessons: each lesson lives in exactly ONE building, and pack lessons
/// (Primrose Lane Nursery, Hartley & Wren Homes) never leak into another building's sheet.
void main() {
  final course = jsonDecode(File('assets/data/course.json').readAsStringSync()) as Map<String, dynamic>;
  final spots = (jsonDecode(File('assets/data/spots.json').readAsStringSync()) as List).cast<Map<String, dynamic>>();
  // Radio shows and real-life missions link to lessons that belong to other buildings.
  const linkSpots = {'radio', 'missions'};
  final packOf = <String, String>{};
  final all = <String>{};
  for (final u in (course['units'] as List).cast<Map<String, dynamic>>()) {
    for (final l in (u['lessons'] as List).cast<Map<String, dynamic>>()) {
      all.add(l['id'] as String);
    }
  }
  for (final p in (course['packs'] as List).cast<Map<String, dynamic>>()) {
    for (final u in (p['units'] as List).cast<Map<String, dynamic>>()) {
      for (final l in (u['lessons'] as List).cast<Map<String, dynamic>>()) {
        all.add(l['id'] as String);
        packOf[l['id'] as String] = p['id'] as String;
      }
    }
  }
  List<String> ids(Map<String, dynamic> s) => (s['lessons'] as List).cast<String>();

  test('every lesson belongs to exactly one building', () {
    final owners = <String, List<String>>{};
    for (final s in spots.where((s) => !linkSpots.contains(s['id']))) {
      for (final id in ids(s)) {
        (owners[id] ??= []).add(s['id'] as String);
      }
    }
    final shared = {for (final e in owners.entries) if (e.value.length > 1) e.key: e.value};
    expect(shared, isEmpty, reason: 'lessons listed under several buildings');
    expect(all.difference(owners.keys.toSet()), isEmpty, reason: 'lessons with no building');
  });

  test('pack lessons only appear in their own pack building', () {
    for (final s in spots) {
      for (final id in ids(s)) {
        final pk = packOf[id];
        if (pk != null) expect(s['pack'], pk, reason: '$id ($pk) is listed under ${s['id']}');
      }
      if (s['pack'] != null) {
        expect(ids(s).every((id) => packOf[id] == s['pack']), isTrue, reason: '${s['id']} lists lessons from outside its pack');
      }
    }
  });

  test("Maple Grove Primary does not list Primrose Lane Nursery lessons", () {
    final school = spots.firstWhere((s) => s['id'] == 'school');
    expect(ids(school).where((id) => packOf[id] == 'nursery'), isEmpty);
    expect(ids(school).where((id) => id.startsWith('nur')), isEmpty);
  });

  test('link spots only point at real lessons', () {
    for (final s in spots.where((s) => linkSpots.contains(s['id']))) {
      expect(ids(s).every(all.contains), isTrue);
    }
  });
}
