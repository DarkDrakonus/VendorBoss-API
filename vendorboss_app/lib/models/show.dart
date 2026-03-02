class Show {
  final String id;
  final String userId;
  final String name;
  final DateTime date;
  final String? location;
  final String? venue;
  final String? tableNumber;
  final double? tableCost;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;

  const Show({
    required this.id,
    required this.userId,
    required this.name,
    required this.date,
    this.location,
    this.venue,
    this.tableNumber,
    this.tableCost,
    this.notes,
    required this.isActive,
    required this.createdAt,
  });

  factory Show.fromJson(Map<String, dynamic> json) {
    return Show(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      name: json['name'] ?? '',
      date: DateTime.parse(json['date']),
      location: json['location'],
      venue: json['venue'],
      tableNumber: json['table_number'],
      tableCost: (json['table_cost'] as num?)?.toDouble(),
      notes: json['notes'],
      isActive: json['is_active'] ?? false,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  /// Maps API response fields (show_id, show_name, show_date)
  factory Show.fromApiJson(Map<String, dynamic> json) {
    return Show(
      id:          json['show_id'] ?? '',
      userId:      json['user_id'] ?? '',
      name:        json['show_name'] ?? '',
      date:        DateTime.parse(json['show_date']),
      location:    json['location'],
      venue:       json['venue'],
      tableNumber: json['table_number'],
      tableCost:   (json['table_cost'] as num?)?.toDouble(),
      notes:       json['notes'],
      isActive:    json['is_active'] ?? false,
      createdAt:   json['created_at'] != null
                     ? DateTime.parse(json['created_at'])
                     : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'date': date.toIso8601String(),
        'location': location,
        'venue': venue,
        'table_number': tableNumber,
        'table_cost': tableCost,
        'notes': notes,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
      };
}

class SaleItem {
  final String inventoryItemId;
  final String cardName;
  final String game;
  final int quantity;
  final double marketPrice;
  final double salePrice; // Adjusted price for this sale
  final String? imageUrl;

  const SaleItem({
    required this.inventoryItemId,
    required this.cardName,
    required this.game,
    required this.quantity,
    required this.marketPrice,
    required this.salePrice,
    this.imageUrl,
  });

  double get lineTotal => salePrice * quantity;

  double get discount => ((marketPrice - salePrice) / marketPrice) * 100;
}

class Sale {
  final String id;
  final String? showId; // null = General Sales
  final String userId;
  final List<SaleItem> items;
  final double totalAmount;
  final String paymentMethod; // cash, card, trade
  final String saleChannel;   // in_person, tcgplayer, ebay, whatnot
  final String? notes;
  final DateTime saleDate;
  final bool isBulkSale;
  final String? bulkDescription;

  const Sale({
    required this.id,
    this.showId,
    required this.userId,
    required this.items,
    required this.totalAmount,
    required this.paymentMethod,
    this.saleChannel = 'in_person',
    this.notes,
    required this.saleDate,
    this.isBulkSale = false,
    this.bulkDescription,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: json['id'] ?? '',
      showId: json['show_id'],
      userId: json['user_id'] ?? '',
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => SaleItem(
                inventoryItemId: e['inventory_item_id'] ?? '',
                cardName: e['card_name'] ?? '',
                game: e['game'] ?? '',
                quantity: e['quantity'] ?? 1,
                marketPrice: (e['market_price'] as num?)?.toDouble() ?? 0.0,
                salePrice: (e['sale_price'] as num?)?.toDouble() ?? 0.0,
                imageUrl: e['image_url'],
              ))
          .toList(),
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method'] ?? 'cash',
      saleChannel: json['sale_channel'] ?? 'in_person',
      notes: json['notes'],
      saleDate: DateTime.parse(json['sale_date'] ?? DateTime.now().toIso8601String()),
      isBulkSale: json['is_bulk_sale'] ?? false,
      bulkDescription: json['bulk_description'],
    );
  }

  /// Maps API response (transaction_id, unit_price, total_amount, etc)
  factory Sale.fromApiJson(Map<String, dynamic> json) {
    return Sale(
      id:              json['transaction_id'] ?? '',
      showId:          null, // not returned directly — filtered by show_id query
      userId:          json['user_id'] ?? '',
      items:           [], // API returns flat transaction, not line items
      totalAmount:     (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod:   json['payment_method'] ?? 'cash',
      saleChannel:     json['payment_method'] ?? 'in_person',
      notes:           json['notes'],
      saleDate:        DateTime.parse(
                         json['transaction_date'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class Expense {
  final String id;
  final String? showId; // null = general business expense not tied to a show
  final String userId;
  final String type; // table_fee, travel, food, supplies, card_purchase, other
  final String description;
  final double amount;
  final String paymentMethod;
  final String? notes;
  final DateTime expenseDate;

  const Expense({
    required this.id,
    this.showId,
    required this.userId,
    required this.type,
    required this.description,
    required this.amount,
    this.paymentMethod = 'cash',
    this.notes,
    required this.expenseDate,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] ?? '',
      showId: json['show_id'],
      userId: json['user_id'] ?? '',
      type: json['type'] ?? 'other',
      description: json['description'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method'] ?? 'cash',
      notes: json['notes'],
      expenseDate: DateTime.parse(json['expense_date'] ?? DateTime.now().toIso8601String()),
    );
  }

  /// Maps API response (expense_id, expense_type, expense_date)
  factory Expense.fromApiJson(Map<String, dynamic> json) {
    return Expense(
      id:            json['expense_id'] ?? '',
      showId:        json['show_id'],
      userId:        json['user_id'] ?? '',
      type:          json['expense_type'] ?? 'other',
      description:   json['description'] ?? '',
      amount:        (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method'] ?? 'cash',
      notes:         json['notes'],
      expenseDate:   DateTime.parse(
                       json['expense_date'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'show_id': showId,
        'user_id': userId,
        'type': type,
        'description': description,
        'amount': amount,
        'payment_method': paymentMethod,
        'notes': notes,
        'expense_date': expenseDate.toIso8601String(),
      };

  String get typeDisplay {
    switch (type) {
      case 'table_fee':
        return 'Table Fee';
      case 'travel':
        return 'Travel';
      case 'food':
        return 'Food & Drink';
      case 'supplies':
        return 'Supplies';
      case 'card_purchase':
        return 'Card Purchase';
      default:
        return 'Other';
    }
  }
}

class ShowSummary {
  final Show show;
  final double totalSales;
  final double totalExpenses;
  final double netProfit;
  final int totalTransactions;
  final int cardsSold;

  const ShowSummary({
    required this.show,
    required this.totalSales,
    required this.totalExpenses,
    required this.netProfit,
    required this.totalTransactions,
    required this.cardsSold,
  });
}
