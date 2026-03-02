class AppConfig {
  // API base URL - change this to your server address
  static const String apiBaseUrl = 'http://192.168.1.37:8000';

  // Scryfall API (free, no key needed) - Magic: The Gathering
  static const String scryfallBaseUrl = 'https://api.scryfall.com';

  // TCGPlayer API (requires key - set in .env or secure storage)
  static const String tcgPlayerBaseUrl = 'https://api.tcgplayer.com';

  // Pokemon TCG API (free, no key needed)
  static const String pokemonTcgBaseUrl = 'https://api.pokemontcg.io/v2';

  // TCDB - Trading Card Database (sports + non-sport)
  static const String tcdbBaseUrl = 'https://www.tcdb.com/api';

  // App settings
  static const String appName = 'VendorBoss';
  static const String appVersion = '1.0.0';

  // Free tier limits
  static const int freeTierCardLimit = 200;

  // ── Supported card categories ─────────────────────────────────────────────
  // Each category has games/sets within it.
  // Image + pricing APIs are mapped per category in the service layer.

  static const Map<String, List<String>> supportedCategories = {
    'Trading Card Games': [
      'Pokemon',
      'Magic: The Gathering',
      'One Piece',
      'Final Fantasy TCG',
      'Yu-Gi-Oh!',
      'Dragon Ball Super',
      'Disney Lorcana',
      'Flesh and Blood',
      'Digimon',
      'Star Wars Unlimited',
      'Weiss Schwarz',
      'Cardfight!! Vanguard',
    ],
    'Sports Cards': [
      'Baseball',
      'Basketball',
      'Football',
      'Hockey',
      'Soccer',
      'Golf',
      'Boxing / MMA',
      'Wrestling',
      'Multi-Sport',
    ],
    'Non-Sport / Entertainment': [
      'Marvel',
      'DC Comics',
      'Star Wars',
      'WWE',
      'Garbage Pail Kids',
      'Topps Chrome',
      'Vintage Non-Sport',
      'Anime Cards',
      'Other Non-Sport',
    ],
    'Graded / Slabs': [
      // Not a separate "game" — graded cards belong to any category above
      // but vendors often want to filter their slab inventory specifically
    ],
  };

  // Flat list for dropdowns and filters
  static List<String> get allGames => supportedCategories.values
      .expand((games) => games)
      .where((g) => g.isNotEmpty)
      .toList();

  // Which categories need which pricing API
  static const Map<String, String> categoryPricingApi = {
    'Trading Card Games': 'tcgplayer',
    'Sports Cards': 'tcdb',         // + eBay completed sales
    'Non-Sport / Entertainment': 'tcdb', // + eBay completed sales
  };

  // Expense types for the expense form
  static const List<Map<String, String>> expenseTypes = [
    {'value': 'table_fee',    'label': 'Table / Booth Fee'},
    {'value': 'travel',       'label': 'Travel'},
    {'value': 'hotel',        'label': 'Hotel / Lodging'},
    {'value': 'food',         'label': 'Food & Drink'},
    {'value': 'card_purchase','label': 'Card Purchase'},
    {'value': 'supplies',     'label': 'Supplies'},
    {'value': 'grading',      'label': 'Grading Fees'},
    {'value': 'shipping',     'label': 'Shipping'},
    {'value': 'other',        'label': 'Other'},
  ];

  // Default buy percentage (what vendors offer below market when buying)
  static const double defaultBuyPercentage = 0.50;
}
