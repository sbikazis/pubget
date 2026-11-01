import 'fan_work_models.dart';

/// A closed, server-validated category for a Fan Work (spec §17 + owner brief).
///
/// Categories are a *closed* list, never free text: the server is the single
/// source of truth (`functions/src/fanWorksTaxonomy.js`) and this file mirrors
/// it so the picker renders instantly and works offline. Any id that is not in
/// the mirror is rejected by the server, so the two lists are safe to ship in
/// lockstep.
final class FanWorkCategory {
  const FanWorkCategory({required this.id, required this.en, required this.ar});

  final String id;
  final String en;
  final String ar;

  String label({required bool arabic}) => arabic ? ar : en;
}

abstract final class FanWorkCategories {
  /// Narrative categories shared by the two document-backed types.
  static const narrative = <FanWorkCategory>[
    FanWorkCategory(id: 'action', en: 'Action', ar: 'أكشن'),
    FanWorkCategory(id: 'adventure', en: 'Adventure', ar: 'مغامرة'),
    FanWorkCategory(id: 'comedy', en: 'Comedy', ar: 'كوميديا'),
    FanWorkCategory(id: 'drama', en: 'Drama', ar: 'دراما'),
    FanWorkCategory(id: 'romance', en: 'Romance', ar: 'رومانسي'),
    FanWorkCategory(id: 'fantasy', en: 'Fantasy', ar: 'فانتازيا'),
    FanWorkCategory(id: 'sciFi', en: 'Sci-Fi', ar: 'خيال علمي'),
    FanWorkCategory(
      id: 'supernatural',
      en: 'Supernatural',
      ar: 'ما وراء الطبيعة',
    ),
    FanWorkCategory(id: 'horror', en: 'Horror', ar: 'رعب'),
    FanWorkCategory(id: 'mystery', en: 'Mystery', ar: 'غموض'),
    FanWorkCategory(id: 'sliceOfLife', en: 'Slice of Life', ar: 'حياة يومية'),
    FanWorkCategory(id: 'historical', en: 'Historical', ar: 'تاريخي'),
  ];

  /// Categories for a single-artwork upload.
  static const art = <FanWorkCategory>[
    FanWorkCategory(id: 'portrait', en: 'Portrait', ar: 'بورتريه'),
    FanWorkCategory(id: 'characterArt', en: 'Character Art', ar: 'رسم شخصيات'),
    FanWorkCategory(id: 'fullBody', en: 'Full Body', ar: 'جسم كامل'),
    FanWorkCategory(id: 'landscape', en: 'Landscape', ar: 'منظر طبيعي'),
    FanWorkCategory(id: 'conceptArt', en: 'Concept Art', ar: 'فن المفاهيم'),
    FanWorkCategory(id: 'digitalArt', en: 'Digital Art', ar: 'رسم رقمي'),
    FanWorkCategory(
      id: 'traditionalArt',
      en: 'Traditional Art',
      ar: 'رسم تقليدي',
    ),
    FanWorkCategory(id: 'animeStyle', en: 'Anime Style', ar: 'أسلوب أنمي'),
    FanWorkCategory(id: 'chibi', en: 'Chibi', ar: 'تشيبي'),
    FanWorkCategory(id: 'fanArt', en: 'Fan Art', ar: 'فن معجبين'),
  ];

  /// Categories for a standalone character.
  static const character = <FanWorkCategory>[
    FanWorkCategory(id: 'human', en: 'Human', ar: 'بشري'),
    FanWorkCategory(id: 'superhuman', en: 'Superhuman', ar: 'خارق'),
    FanWorkCategory(id: 'demon', en: 'Demon', ar: 'شيطان'),
    FanWorkCategory(id: 'spirit', en: 'Spirit', ar: 'روح'),
    FanWorkCategory(id: 'creature', en: 'Creature', ar: 'كائن خيالي'),
    FanWorkCategory(id: 'android', en: 'Android', ar: 'آلي'),
    FanWorkCategory(id: 'animal', en: 'Animal', ar: 'حيوان'),
    FanWorkCategory(id: 'warrior', en: 'Warrior', ar: 'محارب'),
    FanWorkCategory(id: 'royalty', en: 'Royalty', ar: 'ملك'),
    FanWorkCategory(id: 'antiHero', en: 'Anti-Hero', ar: 'ضد بطل'),
  ];

  /// The closed list for [type]. Legacy-only types have no creator-facing
  /// category — they were never created with one, so inventing one would be
  /// fake data.
  static List<FanWorkCategory> forType(FanWorkType type) => switch (type) {
    FanWorkType.manga || FanWorkType.story => narrative,
    FanWorkType.drawing => art,
    FanWorkType.character => character,
    FanWorkType.worldbuilding || FanWorkType.other => const <FanWorkCategory>[],
  };

  /// Whether [type] can be created with a category at all.
  static bool supportsCategory(FanWorkType type) => forType(type).isNotEmpty;

  static FanWorkCategory? byId(FanWorkType type, String id) {
    if (id.isEmpty) return null;
    for (final category in forType(type)) {
      if (category.id == id) return category;
    }
    return null;
  }

  static List<String> idsFor(FanWorkType type) =>
      forType(type).map((category) => category.id).toList(growable: false);
}

/// How a character came to exist (spec §17.1 explicitly allows AI-assisted
/// characters). Recorded per work so a hand-drawn portrait is never presented
/// as a generated one, or the other way round.
enum FanWorkOrigin {
  handmade,
  aiGenerated;

  static FanWorkOrigin from(Object? raw) =>
      raw == 'aiGenerated' ? FanWorkOrigin.aiGenerated : FanWorkOrigin.handmade;
}
