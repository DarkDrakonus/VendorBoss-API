class AppUser {
  final String id;
  final String email;
  final String? username;
  final String? firstName;
  final String? lastName;
  final String? businessName;
  final String subscriptionTier; // free, starter, pro
  final int cardCount;
  final bool isVerified;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.email,
    this.username,
    this.firstName,
    this.lastName,
    this.businessName,
    this.subscriptionTier = 'free',
    this.cardCount = 0,
    this.isVerified = false,
    required this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      username: json['username'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      businessName: json['business_name'],
      subscriptionTier: json['subscription_tier'] ?? 'free',
      cardCount: json['card_count'] ?? 0,
      isVerified: json['is_verified'] ?? false,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  /// Greeting name — business name takes priority, then first name, then email
  String get displayName {
    if (businessName != null && businessName!.isNotEmpty) return businessName!;
    if (firstName != null && firstName!.isNotEmpty) return firstName!;
    return email.split('@').first;
  }

  /// Full personal name for profile display
  String get fullName {
    if (firstName != null && lastName != null) return '$firstName $lastName';
    return displayName;
  }

  bool get isAtFreeLimit => subscriptionTier == 'free' && cardCount >= 200;
}
