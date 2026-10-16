/// Character growth over time: the family's own calendar. Chapters advance with the learner's progress
/// (completed stories + passed units), so the children visibly grow up as you do.
class Chapter {
  final String id, season, seasonFa, title, titleFa, story, storyFa;
  final int year, threshold;
  final Map<String, int> ages;
  final Map<String, (String, String)> stages;
  final List<String> opens;
  const Chapter({required this.id, required this.year, required this.season, required this.seasonFa, required this.title, required this.titleFa, required this.threshold, required this.story, required this.storyFa, required this.ages, required this.stages, required this.opens});
  factory Chapter.fromJson(Map<String, dynamic> j) => Chapter(
    id: j['id'],
    year: j['year'],
    season: j['season'],
    seasonFa: j['seasonFa'],
    title: j['title'],
    titleFa: j['titleFa'],
    threshold: j['threshold'],
    story: j['story'],
    storyFa: j['storyFa'],
    ages: Map<String, int>.from(j['ages']),
    stages: {for (final e in (j['stages'] as Map<String, dynamic>).entries) e.key: (e.value[0] as String, e.value[1] as String)},
    opens: List<String>.from(j['opens'] ?? const []),
  );
}

class Timeline {
  final List<Chapter> chapters;
  const Timeline(this.chapters);
  factory Timeline.fromJson(Map<String, dynamic> j) => Timeline([for (final c in j['chapters']) Chapter.fromJson(c)]);
  int indexFor(int points) {
    var i = 0;
    for (var k = 0; k < chapters.length; k++) {
      if (points >= chapters[k].threshold) i = k;
    }
    return i;
  }
}
