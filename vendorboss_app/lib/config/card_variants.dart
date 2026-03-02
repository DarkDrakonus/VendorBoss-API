/// Game-specific card variant/finish types.
///
/// In the backend this will be a variant_type table:
///   id, game_key, value, label, sort_order
///
/// Each game key maps to the game strings used in AppConfig.supportedCategories.
/// The 'default' key is used as a fallback for any game not explicitly listed.

class CardVariants {
  CardVariants._();

  /// Returns the variant list for a given game name.
  static List<CardVariant> forGame(String game) {
    final key = _gameKey(game);
    return _variants[key] ?? _variants['default']!;
  }

  /// Normalise game name to a lookup key
  static String _gameKey(String game) {
    final lower = game.toLowerCase();
    if (lower.contains('pokemon'))            return 'pokemon';
    if (lower.contains('magic'))              return 'mtg';
    if (lower.contains('one piece'))          return 'one_piece';
    if (lower.contains('yu-gi-oh'))           return 'yugioh';
    if (lower.contains('dragon ball'))        return 'dragonball';
    if (lower.contains('lorcana'))            return 'lorcana';
    if (lower.contains('flesh and blood'))    return 'fab';
    if (lower.contains('digimon'))            return 'digimon';
    if (lower.contains('final fantasy'))      return 'fftcg';
    if (lower.contains('star wars'))          return 'starwars_tcg';
    if (lower.contains('weiss'))              return 'weiss';
    if (lower.contains('vanguard'))           return 'vanguard';
    // Sports & non-sport share a finish set
    if (_isSports(lower) || _isNonSport(lower)) return 'sports';
    return 'default';
  }

  static bool _isSports(String lower) =>
      ['baseball', 'basketball', 'football', 'hockey', 'soccer',
       'golf', 'boxing', 'wrestling', 'mma', 'multi-sport']
          .any(lower.contains);

  static bool _isNonSport(String lower) =>
      ['marvel', 'dc comics', 'star wars', 'wwe', 'garbage pail',
       'topps', 'vintage non-sport', 'anime', 'non-sport']
          .any(lower.contains);

  static const Map<String, List<CardVariant>> _variants = {

    // ── Pokémon ────────────────────────────────────────────────────────────
    'pokemon': [
      CardVariant('normal',            'Normal'),
      CardVariant('holo',              'Holo'),
      CardVariant('reverse_holo',      'Reverse Holo'),
      CardVariant('full_art',          'Full Art'),
      CardVariant('alt_art',           'Alt Art'),
      CardVariant('illustration_rare', 'Illustration Rare'),
      CardVariant('special_ill_rare',  'Special Illustration Rare'),
      CardVariant('rainbow_rare',      'Rainbow Rare'),
      CardVariant('gold_card',         'Gold Card'),
      CardVariant('trainer_gallery',   'Trainer Gallery'),
      CardVariant('promo',             'Promo'),
    ],

    // ── Magic: The Gathering ───────────────────────────────────────────────
    'mtg': [
      CardVariant('normal',            'Normal'),
      CardVariant('foil',              'Foil'),
      CardVariant('borderless',        'Borderless'),
      CardVariant('extended_art',      'Extended Art'),
      CardVariant('showcase',          'Showcase'),
      CardVariant('surge_foil',        'Surge Foil'),
      CardVariant('etched_foil',       'Etched Foil'),
      CardVariant('retro_frame',       'Retro Frame'),
      CardVariant('gilded_foil',       'Gilded Foil'),
      CardVariant('textured_foil',     'Textured Foil'),
      CardVariant('double_rainbow',    'Double Rainbow Foil'),
      CardVariant('galaxy_foil',       'Galaxy Foil'),
      CardVariant('step_compleat',     'Step-and-Compleat Foil'),
      CardVariant('serialized',        'Serialized'),
      CardVariant('promo',             'Promo'),
    ],

    // ── One Piece ──────────────────────────────────────────────────────────
    'one_piece': [
      CardVariant('normal',            'Normal'),
      CardVariant('parallel',          'Parallel'),
      CardVariant('alt_art',           'Alt Art'),
      CardVariant('full_art',          'Full Art'),
      CardVariant('leader_alt',        'Leader Alt Art'),
      CardVariant('manga_art',         'Manga Art'),
      CardVariant('promo',             'Promo'),
    ],

    // ── Yu-Gi-Oh ───────────────────────────────────────────────────────────
    'yugioh': [
      CardVariant('common',            'Common'),
      CardVariant('rare',              'Rare'),
      CardVariant('super_rare',        'Super Rare'),
      CardVariant('ultra_rare',        'Ultra Rare'),
      CardVariant('secret_rare',       'Secret Rare'),
      CardVariant('prismatic_secret',  'Prismatic Secret Rare'),
      CardVariant('ghost_rare',        'Ghost Rare'),
      CardVariant('starlight_rare',    'Starlight Rare'),
      CardVariant('qcsr',              'Quarter Century Secret Rare'),
      CardVariant('collector_rare',    'Collector\'s Rare'),
      CardVariant('short_print',       'Short Print'),
    ],

    // ── Dragon Ball Super ──────────────────────────────────────────────────
    'dragonball': [
      CardVariant('normal',            'Normal'),
      CardVariant('rare',              'Rare'),
      CardVariant('super_rare',        'Super Rare'),
      CardVariant('special_rare',      'Special Rare'),
      CardVariant('secret_rare',       'Secret Rare'),
      CardVariant('ultimate_rare',     'Ultimate Rare'),
      CardVariant('zenkai_series',     'Zenkai Series'),
    ],

    // ── Disney Lorcana ─────────────────────────────────────────────────────
    'lorcana': [
      CardVariant('normal',            'Normal'),
      CardVariant('foil',              'Foil'),
      CardVariant('enchanted',         'Enchanted'),
      CardVariant('alt_art',           'Alt Art'),
      CardVariant('promo',             'Promo'),
    ],

    // ── Flesh and Blood ────────────────────────────────────────────────────
    'fab': [
      CardVariant('normal',            'Normal'),
      CardVariant('rainbow_foil',      'Rainbow Foil'),
      CardVariant('cold_foil',         'Cold Foil'),
      CardVariant('gold_foil',         'Gold Foil'),
      CardVariant('extended_art',      'Extended Art'),
      CardVariant('alt_art',           'Alt Art'),
    ],

    // ── Digimon ────────────────────────────────────────────────────────────
    'digimon': [
      CardVariant('normal',            'Normal'),
      CardVariant('parallel',          'Parallel Rare'),
      CardVariant('secret_rare',       'Secret Rare'),
      CardVariant('alt_art',           'Alt Art'),
      CardVariant('promo',             'Promo'),
    ],

    // ── Final Fantasy TCG ──────────────────────────────────────────────────
    'fftcg': [
      CardVariant('normal',            'Normal'),
      CardVariant('foil',              'Foil'),
      CardVariant('full_art',          'Full Art'),
      CardVariant('alt_art',           'Alt Art'),
      CardVariant('opus_promo',        'Opus Promo'),
    ],

    // ── Star Wars Unlimited ────────────────────────────────────────────────
    'starwars_tcg': [
      CardVariant('normal',            'Normal'),
      CardVariant('foil',              'Foil'),
      CardVariant('hyperspace',        'Hyperspace'),
      CardVariant('showcase',          'Showcase'),
    ],

    // ── Weiss Schwarz ──────────────────────────────────────────────────────
    'weiss': [
      CardVariant('normal',            'Normal'),
      CardVariant('foil',              'Foil'),
      CardVariant('special_rare',      'Special Rare'),
      CardVariant('signed',            'Signed'),
      CardVariant('promo',             'Promo'),
    ],

    // ── Cardfight!! Vanguard ───────────────────────────────────────────────
    'vanguard': [
      CardVariant('normal',            'Normal'),
      CardVariant('rr',                'RR'),
      CardVariant('rrr',               'RRR'),
      CardVariant('vr',                'VR'),
      CardVariant('svr',               'SVR'),
      CardVariant('gr',                'GR'),
      CardVariant('or',                'OR'),
      CardVariant('xvr',               'XVR'),
    ],

    // ── Sports & Non-Sport ─────────────────────────────────────────────────
    'sports': [
      CardVariant('base',              'Base'),
      CardVariant('parallel',          'Parallel'),
      CardVariant('refractor',         'Refractor'),
      CardVariant('prizm',             'Prizm'),
      CardVariant('chrome',            'Chrome'),
      CardVariant('auto',              'Autograph'),
      CardVariant('patch',             'Patch / Relic'),
      CardVariant('auto_patch',        'Auto Patch'),
      CardVariant('rookie',            'Rookie'),
      CardVariant('numbered',          'Numbered'),
      CardVariant('superfractor',      'Superfractor 1/1'),
      CardVariant('printing_plate',    'Printing Plate'),
      CardVariant('variation',         'Short Print / Variation'),
    ],

    // ── Generic fallback ───────────────────────────────────────────────────
    'default': [
      CardVariant('normal',            'Normal'),
      CardVariant('foil',              'Foil'),
      CardVariant('full_art',          'Full Art'),
      CardVariant('alt_art',           'Alt Art'),
      CardVariant('promo',             'Promo'),
      CardVariant('numbered',          'Numbered'),
      CardVariant('other',             'Other'),
    ],
  };
}

class CardVariant {
  final String value;
  final String label;
  const CardVariant(this.value, this.label);
}
