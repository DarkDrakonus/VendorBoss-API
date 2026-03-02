import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/app_user.dart';

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  static const _storage = FlutterSecureStorage();
  static const _tokenKey   = 'auth_token';
  static const _userKey    = 'current_user';
  static const _expiryKey  = 'token_expiry';

  // ── Token management ───────────────────────────────────────────────────────

  Future<String?> getToken() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null) return null;

    // Check expiry — token lasts 30 min, refresh if within 5 min of expiry
    final expiryStr = await _storage.read(key: _expiryKey);
    if (expiryStr != null) {
      final expiry = DateTime.parse(expiryStr);
      if (DateTime.now().isAfter(expiry)) {
        // Token expired — clear and return null to force re-login
        await clearAuth();
        return null;
      }
    }
    return token;
  }

  Future<void> _saveToken(String token) async {
    // Save token and set expiry 25 minutes from now (5 min buffer before 30 min expiry)
    final expiry = DateTime.now().add(const Duration(minutes: 25));
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _expiryKey, value: expiry.toIso8601String());
  }

  Future<void> clearAuth() => _storage.deleteAll();

  Future<bool> get isLoggedIn async => (await getToken()) != null;

  // ── Cached user ────────────────────────────────────────────────────────────

  Future<AppUser?> getCachedUser() async {
    final json = await _storage.read(key: _userKey);
    if (json == null) return null;
    try {
      return AppUser.fromJson(jsonDecode(json));
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveUser(AppUser user) =>
      _storage.write(key: _userKey, value: jsonEncode({
        'id':                user.id,
        'email':             user.email,
        'username':          user.username,
        'first_name':        user.firstName,
        'last_name':         user.lastName,
        'subscription_tier': user.subscriptionTier,
        'card_count':        user.cardCount,
        'is_verified':       user.isVerified,
        'created_at':        user.createdAt.toIso8601String(),
      }));

  // ── Login ──────────────────────────────────────────────────────────────────

  Future<AppUser> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.login}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw ApiException(body['detail'] ?? 'Login failed', response.statusCode);
    }

    final data = jsonDecode(response.body);
    await _saveToken(data['access_token']);

    final user = await getMe(data['access_token']);
    await _saveUser(user);
    return user;
  }

  // ── Register ───────────────────────────────────────────────────────────────

  Future<AppUser> register({
    required String email,
    required String password,
    String? username,
    String? firstName,
    String? lastName,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.register}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email':      email,
        'password':   password,
        'username':   username,
        'first_name': firstName,
        'last_name':  lastName,
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200 && response.statusCode != 201) {
      final body = jsonDecode(response.body);
      throw ApiException(body['detail'] ?? 'Registration failed', response.statusCode);
    }

    final data = jsonDecode(response.body);
    await _saveToken(data['access_token']);

    final user = await getMe(data['access_token']);
    await _saveUser(user);
    return user;
  }

  // ── Get current user profile ───────────────────────────────────────────────

  Future<AppUser> getMe(String? token) async {
    final t = token ?? await getToken();
    if (t == null) throw const ApiException('Not authenticated', 401);

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.me}'),
      headers: {'Authorization': 'Bearer $t'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw ApiException('Failed to get user profile', response.statusCode);
    }

    final data = jsonDecode(response.body);
    return AppUser(
      id:               data['user_id'] ?? '',
      email:            data['email'] ?? '',
      username:         data['username'],
      firstName:        data['first_name'],
      lastName:         data['last_name'],
      subscriptionTier: 'free',
      cardCount:        0,
      isVerified:       data['is_verified'] ?? false,
      createdAt:        DateTime.parse(
                          data['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  Future<void> logout() => clearAuth();
}

// ── Exception ──────────────────────────────────────────────────────────────

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}
