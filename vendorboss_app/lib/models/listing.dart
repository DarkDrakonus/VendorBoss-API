/// Represents a single active or historical listing of an inventory item
/// on an external platform (eBay, TCGPlayer, COMC, Whatnot, etc.).
///
/// One inventory item can have multiple concurrent listings across
/// different platforms. A listing closes when a sale is recorded.

class Listing {
  final String id;
  final String inventoryItemId;
  final String platform;       // ebay, tcgplayer, comc, whatnot, mercari
  final String listingType;    // fixed, auction, best_offer, consignment
  final String status;         // active, sold, cancelled, expired
  final double listedPrice;
  final double? soldPrice;     // populated when sold
  final String? platformListingId;  // the ID on the external platform
  final String? platformUrl;        // direct link to the listing
  final DateTime listedAt;
  final DateTime? endsAt;      // auction end time or expiry
  final DateTime? soldAt;
  final DateTime? cancelledAt;
  final String? notes;

  const Listing({
    required this.id,
    required this.inventoryItemId,
    required this.platform,
    required this.listingType,
    required this.status,
    required this.listedPrice,
    this.soldPrice,
    this.platformListingId,
    this.platformUrl,
    required this.listedAt,
    this.endsAt,
    this.soldAt,
    this.cancelledAt,
    this.notes,
  });

  bool get isActive => status == 'active';
  bool get isSold => status == 'sold';
  bool get isAuction => listingType == 'auction';

  /// Human-readable platform name
  String get platformDisplay {
    switch (platform) {
      case 'tcgplayer':   return 'TCGPlayer';
      case 'ebay':        return 'eBay';
      case 'comc':        return 'COMC';
      case 'whatnot':     return 'Whatnot';
      case 'mercari':     return 'Mercari';
      case 'facebook':    return 'Facebook';
      default:            return platform;
    }
  }

  /// Human-readable listing type
  String get listingTypeDisplay {
    switch (listingType) {
      case 'fixed':       return 'Fixed Price';
      case 'auction':     return 'Auction';
      case 'best_offer':  return 'Best Offer';
      case 'consignment': return 'Consignment';
      default:            return listingType;
    }
  }

  factory Listing.fromJson(Map<String, dynamic> json) {
    return Listing(
      id: json['id'] ?? '',
      inventoryItemId: json['inventory_item_id'] ?? '',
      platform: json['platform'] ?? '',
      listingType: json['listing_type'] ?? 'fixed',
      status: json['status'] ?? 'active',
      listedPrice: (json['listed_price'] as num?)?.toDouble() ?? 0.0,
      soldPrice: (json['sold_price'] as num?)?.toDouble(),
      platformListingId: json['platform_listing_id'],
      platformUrl: json['platform_url'],
      listedAt: DateTime.parse(json['listed_at'] ?? DateTime.now().toIso8601String()),
      endsAt: json['ends_at'] != null ? DateTime.parse(json['ends_at']) : null,
      soldAt: json['sold_at'] != null ? DateTime.parse(json['sold_at']) : null,
      cancelledAt: json['cancelled_at'] != null ? DateTime.parse(json['cancelled_at']) : null,
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'inventory_item_id': inventoryItemId,
    'platform': platform,
    'listing_type': listingType,
    'status': status,
    'listed_price': listedPrice,
    'sold_price': soldPrice,
    'platform_listing_id': platformListingId,
    'platform_url': platformUrl,
    'listed_at': listedAt.toIso8601String(),
    'ends_at': endsAt?.toIso8601String(),
    'sold_at': soldAt?.toIso8601String(),
    'cancelled_at': cancelledAt?.toIso8601String(),
    'notes': notes,
  };

  /// Returns a copy of this listing with updated fields
  Listing copyWith({
    String? status,
    double? soldPrice,
    DateTime? soldAt,
    DateTime? cancelledAt,
  }) {
    return Listing(
      id: id,
      inventoryItemId: inventoryItemId,
      platform: platform,
      listingType: listingType,
      status: status ?? this.status,
      listedPrice: listedPrice,
      soldPrice: soldPrice ?? this.soldPrice,
      platformListingId: platformListingId,
      platformUrl: platformUrl,
      listedAt: listedAt,
      endsAt: endsAt,
      soldAt: soldAt ?? this.soldAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      notes: notes,
    );
  }
}
