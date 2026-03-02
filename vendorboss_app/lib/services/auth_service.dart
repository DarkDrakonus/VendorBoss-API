import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/app_user.dart';

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _userKey  = 'current_user';

  // ── Token management ───────────────────────────────────────────────────────

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<void> clearToken() => _storage.delete(key: _tokenKey);

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
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': email, 'password': password},
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw ApiException(body['detail'] ?? 'Login failed', response.statusCode);
    }

    final data = jsonDecode(response.body);
    await saveToken(data['access_token']);

    // Fetch full user profile
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
    );

    if (response.statusCode != 201 && response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw ApiException(body['detail'] ?? 'Registration failed', response.statusCode);
    }

    // Auto-login after register
    return login(email, password);
  }

  // ── Get current user ───────────────────────────────────────────────────────

  Future<AppUser> getMe(String? token) async {
    final t = token ?? await getToken();
    if (t == null) throw const ApiException('Not authenticated', 401);

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.me}'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to get user profile', response.statusCode);
    }

    final data = jsonDecode(response.body);
    // Map API field names to model
    return AppUser(
      id:               data['user_id'] ?? '',
      email:            data['email'] ?? '',
      username:         data['username'],
      firstName:        data['first_name'],
      lastName:         data['last_name'],
      subscriptionTier: data['subscription_tier'] ?? 'free',
      cardCount:        data['card_count'] ?? 0,
      isVerified:       data['is_verified'] ?? false,
      createdAt:        DateTime.parse(
                          data['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    await _storage.deleteAll();
  }
}

// ── Exception ──────────────────────────────────────────────────────────────

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}
