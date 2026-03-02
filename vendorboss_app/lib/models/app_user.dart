class AppUser {
  final String id;
  final String email;
  final String? username;
  final String? firstName;
  final String? lastName;
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
      subscriptionTier: json['subscription_tier'] ?? 'free',
      cardCount: json['card_count'] ?? 0,
      isVerified: json['is_verified'] ?? false,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  String get displayName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    return username ?? email;
  }

  bool get isAtFreeLimit => subscriptionTier == 'free' && cardCount >= 200;
}
