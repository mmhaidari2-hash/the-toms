/// Tappable prop in a painting (teapot, jam jar…): a word, a British phrase and a mini-dialogue.
class Prop {
  final String id, word, fa, phrase, phraseFa;
  final List<List<String>> mini; // [speakerId | 'me', en, fa]
  const Prop({required this.id, required this.word, required this.fa, required this.phrase, required this.phraseFa, this.mini = const []});
  factory Prop.fromJson(Map<String, dynamic> j) => Prop(
    id: j['id'],
    word: j['word'],
    fa: j['fa'],
    phrase: j['phrase'],
    phraseFa: j['phraseFa'],
    mini: [for (final m in j['mini'] ?? const []) List<String>.from(m)],
  );
}

class Hotspot {
  final String characterId;
  final String? sceneId;

  /// Normalised [x, y, w, h] in 0..1 image space (bounding box). Derived from [shape] when given.
  final List<double>? rect;

  /// Invisible polygon hitbox locked to the painted figure, normalised image space.
  final List<List<double>>? shape;
  final String? ambientEn, ambientFa;
  final Prop? prop;
  const Hotspot({required this.characterId, this.sceneId, this.rect, this.shape, this.ambientEn, this.ambientFa, this.prop});
  bool get isProp => prop != null;
  factory Hotspot.fromJson(Map<String, dynamic> j) {
    final shape = j['shape'] == null ? null : [for (final p in j['shape']) <double>[for (final v in p) (v as num).toDouble()]];
    List<double>? rect = j['rect'] == null ? null : [for (final v in j['rect']) (v as num).toDouble()];
    if (rect == null && shape != null) {
      final xs = shape.map((p) => p[0]), ys = shape.map((p) => p[1]);
      final x0 = xs.reduce((a, b) => a < b ? a : b), y0 = ys.reduce((a, b) => a < b ? a : b);
      rect = [x0, y0, xs.reduce((a, b) => a > b ? a : b) - x0, ys.reduce((a, b) => a > b ? a : b) - y0];
    }
    return Hotspot(
      characterId: j['characterId'] ?? '',
      sceneId: j['sceneId'],
      rect: rect,
      shape: shape,
      ambientEn: j['ambient']?['en'],
      ambientFa: j['ambient']?['fa'],
      prop: j['prop'] == null ? null : Prop.fromJson(j['prop']),
    );
  }
}

class Place {
  final String id, title, titleFa, icon;
  final int color;
  final String? image;
  final double aspect;
  final String? requiresCharacter, requiresMilestone;

  /// Seasonal event month (e.g. 12 = Christmas). Opens that month, or early after [earlyAccessChats] chats.
  final int? season;
  static const earlyAccessChats = 3;
  final List<Hotspot> hotspots;
  const Place({
    required this.id,
    required this.title,
    required this.titleFa,
    required this.icon,
    required this.color,
    required this.hotspots,
    this.image,
    this.aspect = 16 / 9,
    this.requiresCharacter,
    this.requiresMilestone,
    this.season,
  });
  Iterable<String> get sceneIds => hotspots.map((h) => h.sceneId).whereType<String>();
  factory Place.fromJson(Map<String, dynamic> j) => Place(
    id: j['id'],
    title: j['title'],
    titleFa: j['titleFa'],
    icon: j['icon'],
    color: int.parse((j['color'] as String).substring(1), radix: 16) | 0xFF000000,
    image: j['image'],
    aspect: (j['aspect'] as num?)?.toDouble() ?? 16 / 9,
    requiresCharacter: j['requires']?['characterId'],
    requiresMilestone: j['requires']?['milestone'],
    hotspots: [for (final h in j['hotspots']) Hotspot.fromJson(h)],
  );
}

class Tier {
  final String id, title, titleFa, subtitle;
  final List<Place> places;
  const Tier({required this.id, required this.title, required this.titleFa, required this.subtitle, required this.places});
  Iterable<String> get sceneIds => places.expand((p) => p.sceneIds);
  factory Tier.fromJson(Map<String, dynamic> j) => Tier(id: j['id'], title: j['title'], titleFa: j['titleFa'], subtitle: j['subtitle'], places: [for (final p in j['places']) Place.fromJson(p)]);
}
