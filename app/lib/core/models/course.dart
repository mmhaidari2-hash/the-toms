import 'dialogue_node.dart';

/// Level 1 (and later levels): units → lessons; each lesson = story dialogue(s) + practice.
class Lesson {
  final String id, title, titleFa, lead, place, grammar, grammarFa;
  final List<String> sceneIds;
  final List<NewWord> words;
  final int turns;
  const Lesson(this.id, this.title, this.titleFa, this.lead, this.place, this.grammar, this.grammarFa, this.sceneIds, this.words, this.turns);
  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(j['id'], j['title'], j['titleFa'], j['lead'], j['place'], j['grammar'], j['grammarFa'], List<String>.from(j['sceneIds']),
      [for (final w in j['words']) NewWord.fromJson(w)], j['turns'] ?? 0);
}

class Unit {
  final String id, title, titleFa, place, canDo, canDoFa;
  final List<Lesson> lessons;
  final int level;
  /// CEFR band for Career Pack units (main-course units use [level]).
  final String? cefr;
  const Unit(this.id, this.title, this.titleFa, this.place, this.canDo, this.canDoFa, this.lessons, [this.level = 1, this.cefr]);
  factory Unit.fromJson(Map<String, dynamic> j) =>
      Unit(j['id'], j['title'], j['titleFa'], j['place'], j['canDo'], j['canDoFa'], [for (final l in j['lessons']) Lesson.fromJson(l)], j['level'] ?? 1, j['cefr']);
  List<NewWord> get words => [for (final l in lessons) ...l.words];
}

/// A Career Pack: a premium, profession-specific track with its own lead character (e.g. Vida's Nursery).
class Pack {
  final String id, title, titleFa, lead, place, blurb, blurbFa, levels;
  final bool premium;
  final List<Unit> units;
  const Pack(this.id, this.title, this.titleFa, this.lead, this.place, this.blurb, this.blurbFa, this.levels, this.premium, this.units);
  factory Pack.fromJson(Map<String, dynamic> j) => Pack(j['id'], j['title'], j['titleFa'], j['lead'], j['place'], j['blurb'] ?? '', j['blurbFa'] ?? '', j['levels'] ?? '', j['premium'] ?? false,
      [for (final u in j['units']) Unit.fromJson(u)]);
  Iterable<Lesson> get lessons => units.expand((u) => u.lessons);
  /// No payments yet: every pack is unlocked for now.
  bool get unlocked => true;
}

class Course {
  /// The main course path (Levels 1–5). Career Packs live in [packs] and don't affect main progression.
  final List<Unit> units;
  final List<Pack> packs;
  const Course(this.units, [this.packs = const []]);
  factory Course.fromJson(Map<String, dynamic> j) => Course([for (final u in j['units']) Unit.fromJson(u)], [for (final p in (j['packs'] ?? const [])) Pack.fromJson(p)]);
  Iterable<Lesson> get lessons => units.expand((u) => u.lessons);
  Iterable<Unit> get allUnits => [...units, for (final p in packs) ...p.units];
  Pack? pack(String id) => packs.where((p) => p.id == id).firstOrNull;
  Pack? packOf(Unit u) => packs.where((p) => p.units.contains(u)).firstOrNull;
  Lesson? lesson(String id) => allUnits.expand((u) => u.lessons).where((l) => l.id == id).firstOrNull;
  Unit? unit(String id) => allUnits.where((u) => u.id == id).firstOrNull;
  Unit? unitOf(String lessonId) => allUnits.where((u) => u.lessons.any((l) => l.id == lessonId)).firstOrNull;
  static const levelInfo = {1: ('A0 → A1', 'Life with the Toms', 'زندگی با تامزها'), 2: ('A1 → A2', 'Out and about', 'بیرون از خانه'), 3: ('A2 → B1', 'Getting things done', 'از پسِ کارها برآمدن'), 4: ('B1 → B2', 'Work & community', 'کار و محله'), 5: ('B2 → C1', 'Sounding British', 'مثل یک بریتانیایی')};
  /// 1-based number of a unit inside its own level.
  int numberInLevel(Unit u) => packOf(u) != null ? packOf(u)!.units.indexOf(u) + 1 : units.where((x) => x.level == u.level).toList().indexOf(u) + 1;
  String? placeOfScene(String sceneId) => allUnits.expand((u) => u.lessons).where((l) => l.sceneIds.contains(sceneId)).firstOrNull?.place;
}
