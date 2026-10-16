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
  const Unit(this.id, this.title, this.titleFa, this.place, this.canDo, this.canDoFa, this.lessons, [this.level = 1]);
  factory Unit.fromJson(Map<String, dynamic> j) =>
      Unit(j['id'], j['title'], j['titleFa'], j['place'], j['canDo'], j['canDoFa'], [for (final l in j['lessons']) Lesson.fromJson(l)], j['level'] ?? 1);
  List<NewWord> get words => [for (final l in lessons) ...l.words];
}

class Course {
  final List<Unit> units;
  const Course(this.units);
  factory Course.fromJson(Map<String, dynamic> j) => Course([for (final u in j['units']) Unit.fromJson(u)]);
  Iterable<Lesson> get lessons => units.expand((u) => u.lessons);
  Lesson? lesson(String id) => lessons.where((l) => l.id == id).firstOrNull;
  Unit? unit(String id) => units.where((u) => u.id == id).firstOrNull;
  Unit? unitOf(String lessonId) => units.where((u) => u.lessons.any((l) => l.id == lessonId)).firstOrNull;
  static const levelInfo = {1: ('A0 → A1', 'Life with the Toms', 'زندگی با تامزها'), 2: ('A1 → A2', 'Out and about', 'بیرون از خانه'), 3: ('A2 → B1', 'Getting things done', 'از پسِ کارها برآمدن'), 4: ('B1 → B2', 'Work & community', 'کار و محله'), 5: ('B2 → C1', 'Sounding British', 'مثل یک بریتانیایی')};
  /// 1-based number of a unit inside its own level.
  int numberInLevel(Unit u) => units.where((x) => x.level == u.level).toList().indexOf(u) + 1;
  String? placeOfScene(String sceneId) => lessons.where((l) => l.sceneIds.contains(sceneId)).firstOrNull?.place;
}
