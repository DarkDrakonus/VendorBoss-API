double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

class InventoryItem {
  final String id;
  final String cardId;
  final String cardName;
  final String game;
  final String setName;
  final String cardNumber;
  final String finish;
  final String condition; // NM, LP, MP, HP, DMG
  final String language;
  final String? imageUrl;
  final bool isGraded;
  final String? gradingCompany;
  final String? grade;

  final int quantity;
  final double? purchasePrice; // What vendor paid
  final double? marketPrice;   // Current market price
  final double? askingPrice;   // What vendor is selling for
  final String? notes;

  final DateTime acquiredDate;
  final DateTime createdAt;

  const InventoryItem({
    required this.id,
    required this.cardId,
    required this.cardName,
    required this.game,
    required this.setName,
    required this.cardNumber,
    required this.finish,
    required this.condition,
    this.language = 'English',
    this.imageUrl,
    this.isGraded = false,
    this.gradingCompany,
    this.grade,
    required this.quantity,
    this.purchasePrice,
    this.marketPrice,
    this.askingPrice,
    this.notes,
    required this.acquiredDate,
    required this.createdAt,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] ?? '',
      cardId: json['card_id'] ?? '',
      cardName: json['card_name'] ?? '',
      game: json['game'] ?? '',
      setName: json['set_name'] ?? '',
      cardNumber: json['card_number'] ?? '',
      finish: json['finish'] ?? 'normal',
      condition: json['condition'] ?? 'NM',
      language: json['language'] ?? 'English',
      imageUrl: json['image_url'],
      isGraded: json['is_graded'] ?? false,
      gradingCompany: json['grading_company'],
      grade: json['grade'],
      quantity: json['quantity'] ?? 1,
      purchasePrice: (json['purchase_price'] as num?)?.toDouble(),
      marketPrice: (json['market_price'] as num?)?.toDouble(),
      askingPrice: (json['asking_price'] as num?)?.toDouble(),
      notes: json['notes'],
      acquiredDate: DateTime.parse(json['acquired_date'] ?? DateTime.now().toIso8601String()),
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  /// Maps the enriched API response (inventory_id, card_name, game, etc)
  factory InventoryItem.fromApiJson(Map<String, dynamic> json) {
    return InventoryItem(
      id:             json['inventory_id'] ?? '',
      cardId:         json['product_id'] ?? '',
      cardName:       json['card_name'] ?? json['player'] ?? 'Unknown Card',
      game:           json['game'] ?? '',
      setName:        json['set_name'] ?? '',
      cardNumber:     json['card_number'] ?? '',
      finish:         json['is_foil'] == true ? 'foil' : 'normal',
      condition:      json['condition'] ?? 'NM',
      imageUrl:       json['image_url'],
      isGraded:       json['graded'] ?? false,
      gradingCompany: json['grading_company'],
      grade:          json['grade'],
      quantity:       json['quantity'] ?? 1,
      purchasePrice:  _toDouble(json['purchase_price']),
      marketPrice:    _toDouble(json['current_market_price']),
      askingPrice:    _toDouble(json['asking_price']),
      notes:          json['notes'],
      acquiredDate:   json['acquired_date'] != null
                        ? DateTime.parse(json['acquired_date'])
                        : DateTime.now(),
      createdAt:      json['created_at'] != null
                        ? DateTime.parse(json['created_at'])
                        : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'card_id': cardId,
        'card_name': cardName,
        'game': game,
        'set_name': setName,
        'card_number': cardNumber,
        'finish': finish,
        'condition': condition,
        'language': language,
        'image_url': imageUrl,
        'is_graded': isGraded,
        'grading_company': gradingCompany,
        'grade': grade,
        'quantity': quantity,
        'purchase_price': purchasePrice,
        'market_price': marketPrice,
        'asking_price': askingPrice,
        'notes': notes,
        'acquired_date': acquiredDate.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  double? get profitMargin {
    if (askingPrice != null && purchasePrice != null && purchasePrice! > 0) {
      return askingPrice! - purchasePrice!;
    }
    return null;
  }

  double? get marketMarkup {
    if (askingPrice != null && marketPrice != null && marketPrice! > 0) {
      return ((askingPrice! - marketPrice!) / marketPrice!) * 100;
    }
    return null;
  }

  String get displayName {
    if (isGraded && gradingCompany != null && grade != null) {
      return '$cardName ($gradingCompany $grade)';
    }
    return cardName;
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
