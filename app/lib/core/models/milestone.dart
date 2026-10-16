class Milestone {
  final String id, title, titleFa, description, descriptionFa;
  final double threshold;
  final List<String> unlocks;
  const Milestone({required this.id, required this.title, required this.titleFa, required this.description, required this.descriptionFa, required this.threshold, this.unlocks = const []});
  factory Milestone.fromJson(Map<String, dynamic> j) => Milestone(
    id: j['id'],
    title: j['title'],
    titleFa: j['titleFa'],
    description: j['description'],
    descriptionFa: j['descriptionFa'],
    threshold: (j['threshold'] as num).toDouble(),
    unlocks: List<String>.from(j['unlocks'] ?? const []),
  );
}
