/// API configuration
/// Update baseUrl when deploying to production or using a different environment.
class ApiConfig {
  // ── Local network (home / show) ────────────────────────────────────────────
  static const String _localUrl = 'http://192.168.1.37:8001';

  // ── Production (public IP or domain) ──────────────────────────────────────
  // static const String _productionUrl = 'https://api.vendorboss.com';

  static const String baseUrl = _localUrl;

  // Endpoints
  static const String login      = '/auth/login';
  static const String register   = '/auth/register';
  static const String me         = '/auth/me';
  static const String inventory  = '/inventory';
  static const String shows      = '/shows';
  static const String sales      = '/sales';
  static const String expenses   = '/expenses';
  static const String reports    = '/reports';
  static const String cards      = '/cards';
  static const String scan       = '/scan';
}
