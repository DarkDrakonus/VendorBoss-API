class CardModel {
  final String id;
  final String game;
  final String name;
  final String setName;
  final String setCode;
  final String cardNumber;
  final String rarity;
  final String finish; // normal, holo, reverse_holo, foil, etched, etc.
  final String language;
  final String? imageUrl;

  // Pricing
  final double? marketPrice;
  final double? lowPrice;
  final double? midPrice;
  final double? highPrice;

  // Grading (optional)
  final bool isGraded;
  final String? gradingCompany; // PSA, BGS, CGC
  final String? grade;

  const CardModel({
    required this.id,
    required this.game,
    required this.name,
    required this.setName,
    required this.setCode,
    required this.cardNumber,
    required this.rarity,
    required this.finish,
    this.language = 'English',
    this.imageUrl,
    this.marketPrice,
    this.lowPrice,
    this.midPrice,
    this.highPrice,
    this.isGraded = false,
    this.gradingCompany,
    this.grade,
  });

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      id: json['id'] ?? '',
      game: json['game'] ?? '',
      name: json['name'] ?? '',
      setName: json['set_name'] ?? '',
      setCode: json['set_code'] ?? '',
      cardNumber: json['card_number'] ?? '',
      rarity: json['rarity'] ?? '',
      finish: json['finish'] ?? 'normal',
      language: json['language'] ?? 'English',
      imageUrl: json['image_url'],
      marketPrice: (json['market_price'] as num?)?.toDouble(),
      lowPrice: (json['low_price'] as num?)?.toDouble(),
      midPrice: (json['mid_price'] as num?)?.toDouble(),
      highPrice: (json['high_price'] as num?)?.toDouble(),
      isGraded: json['is_graded'] ?? false,
      gradingCompany: json['grading_company'],
      grade: json['grade'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'game': game,
        'name': name,
        'set_name': setName,
        'set_code': setCode,
        'card_number': cardNumber,
        'rarity': rarity,
        'finish': finish,
        'language': language,
        'image_url': imageUrl,
        'market_price': marketPrice,
        'low_price': lowPrice,
        'mid_price': midPrice,
        'high_price': highPrice,
        'is_graded': isGraded,
        'grading_company': gradingCompany,
        'grade': grade,
      };

  String get displayName {
    if (isGraded && gradingCompany != null && grade != null) {
      return '$name ($gradingCompany $grade)';
    }
    return name;
  }

  String get finishDisplay {
    switch (finish.toLowerCase()) {
      case 'holo':
        return 'Holo';
      case 'reverse_holo':
        return 'Reverse Holo';
      case 'foil':
        return 'Foil';
      case 'etched':
        return 'Etched Foil';
      case 'full_art':
        return 'Full Art';
      case 'alt_art':
        return 'Alt Art';
      default:
        return 'Normal';
    }
  }
}
