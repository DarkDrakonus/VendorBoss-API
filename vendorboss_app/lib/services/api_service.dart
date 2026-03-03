import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/inventory_item.dart';
import '../models/show.dart';
import '../models/app_user.dart';
import 'auth_service.dart';

/// Real API service — replaces MockDataService.
/// All methods mirror MockDataService signatures so screens need minimal changes.
class ApiService {
  static final ApiService instance = ApiService._();
  ApiService._();

  // ── Auth headers ───────────────────────────────────────────────────────────

  Future<Map<String, String>> get _headers async {
    final token = await AuthService.instance.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Generic request helpers ────────────────────────────────────────────────

  Future<dynamic> _get(String path, {Map<String, String>? params}) async {
    var uri = Uri.parse('${ApiConfig.baseUrl}$path');
    if (params != null) uri = uri.replace(queryParameters: params);

    final response = await http.get(uri, headers: await _headers);
    return _handle(response);
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: await _headers,
      body: jsonEncode(body),
    );
    return _handle(response);
  }

  Future<dynamic> _put(String path, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: await _headers,
      body: jsonEncode(body),
    );
    return _handle(response);
  }

  Future<void> _delete(String path) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: await _headers,
    );
    if (response.statusCode != 204) _handle(response);
  }

  dynamic _handle(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    if (response.statusCode == 401) {
      throw const ApiException('Session expired — please log in again', 401);
    }
    try {
      final body = jsonDecode(response.body);
      throw ApiException(body['detail'] ?? 'Request failed', response.statusCode);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Request failed (${response.statusCode})', response.statusCode);
    }
  }

  // ── Inventory ──────────────────────────────────────────────────────────────

  Future<List<InventoryItem>> getInventory({
    int page = 1,
    int pageSize = 50,
    bool? forSale,
    String? condition,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
      if (forSale != null) 'for_sale': '$forSale',
      if (condition != null) 'condition': condition,
    };
    final data = await _get(ApiConfig.inventory, params: params);
    final items = data['items'] as List<dynamic>;
    return items.map((e) => InventoryItem.fromApiJson(e)).toList();
  }

  Future<InventoryItem> getInventoryItem(String inventoryId) async {
    final data = await _get('${ApiConfig.inventory}/$inventoryId');
    return InventoryItem.fromApiJson(data);
  }

  Future<InventoryItem> addInventoryItem({
    required String productId,
    int quantity = 1,
    double? purchasePrice,
    double? askingPrice,
    double? minimumPrice,
    String condition = 'NM',
    String? notes,
    String? storageLocation,
    DateTime? acquiredDate,
  }) async {
    final data = await _post(ApiConfig.inventory, {
      'product_id':     productId,
      'quantity':       quantity,
      'purchase_price': purchasePrice,
      'asking_price':   askingPrice,
      'minimum_price':  minimumPrice,
      'condition':      condition,
      'notes':          notes,
      'storage_location': storageLocation,
      'acquired_date':  acquiredDate?.toIso8601String().split('T')[0],
    });
    return InventoryItem.fromApiJson(data);
  }

  Future<InventoryItem> updateInventoryItem(
    String inventoryId,
    Map<String, dynamic> updates,
  ) async {
    final data = await _put('${ApiConfig.inventory}/$inventoryId', updates);
    return InventoryItem.fromApiJson(data);
  }

  Future<void> deleteInventoryItem(String inventoryId) =>
      _delete('${ApiConfig.inventory}/$inventoryId');

  // ── Shows ──────────────────────────────────────────────────────────────────

  Future<List<Show>> getShows({bool activeOnly = false}) async {
    final data = await _get(ApiConfig.shows,
        params: activeOnly ? {'active_only': 'true'} : null);
    return (data as List<dynamic>).map((e) => Show.fromApiJson(e)).toList();
  }

  Future<Show> getShow(String showId) async {
    final data = await _get('/shows/$showId');
    return Show.fromApiJson(data['show']);
  }

  Future<ShowSummary> getShowSummary(String showId) async {
    final data = await _get('/shows/$showId');
    final show = Show.fromApiJson(data['show']);
    return ShowSummary(
      show:              show,
      totalSales:        _parseDouble(data['total_sales']),
      totalExpenses:     _parseDouble(data['total_expenses']),
      netProfit:         _parseDouble(data['net_profit']),
      totalTransactions: data['transaction_count'] ?? 0,
      cardsSold:         0,
    );
  }

  Future<Show> createShow({
    required String name,
    required DateTime date,
    String? location,
    String? venue,
    String? tableNumber,
    double? tableCost,
    String? notes,
  }) async {
    final data = await _post(ApiConfig.shows, {
      'show_name':    name,
      'show_date':    date.toIso8601String().split('T')[0],
      'location':     location,
      'venue':        venue,
      'table_number': tableNumber,
      'table_cost':   tableCost,
      'notes':        notes,
    });
    return Show.fromApiJson(data);
  }

  Future<Show> updateShow(String showId, Map<String, dynamic> updates) async {
    final data = await _put('/shows/$showId', updates);
    return Show.fromApiJson(data);
  }

  Future<ShowSummary> closeShow(String showId) async {
    final data = await _post('/shows/$showId/close', {});
    final show = Show.fromApiJson(data['show']);
    return ShowSummary(
      show:              show,
      totalSales:        _parseDouble(data['total_sales']),
      totalExpenses:     _parseDouble(data['total_expenses']),
      netProfit:         _parseDouble(data['net_profit']),
      totalTransactions: data['transaction_count'] ?? 0,
      cardsSold:         0,
    );
  }

  static double _parseDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  // ── Sales ──────────────────────────────────────────────────────────────────

  Future<List<Sale>> getSales({
    String? showId,
    DateTime? dateFrom,
    DateTime? dateTo,
    int page = 1,
    int pageSize = 50,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
      if (showId != null) 'show_id': showId,
      if (dateFrom != null) 'date_from': dateFrom.toIso8601String().split('T')[0],
      if (dateTo != null) 'date_to': dateTo.toIso8601String().split('T')[0],
    };
    final data = await _get(ApiConfig.sales, params: params);
    return (data['items'] as List<dynamic>)
        .map((e) => Sale.fromApiJson(e))
        .toList();
  }

  Future<Sale> recordSale({
    required String inventoryId,
    required double unitPrice,
    int quantity = 1,
    String paymentMethod = 'cash',
    String? showId,
    String? customerName,
    String? notes,
  }) async {
    final data = await _post(ApiConfig.sales, {
      'inventory_id':   inventoryId,
      'unit_price':     unitPrice,
      'quantity':       quantity,
      'payment_method': paymentMethod,
      'show_id':        showId,
      'customer_name':  customerName,
      'notes':          notes,
    });
    return Sale.fromApiJson(data);
  }

  Future<void> voidSale(String transactionId) =>
      _delete('${ApiConfig.sales}/$transactionId');

  // ── Expenses ───────────────────────────────────────────────────────────────

  Future<List<Expense>> getExpenses({String? showId}) async {
    final data = await _get(ApiConfig.expenses,
        params: showId != null ? {'show_id': showId} : null);
    return (data['items'] as List<dynamic>)
        .map((e) => Expense.fromApiJson(e))
        .toList();
  }

  Future<Expense> addExpense({
    required String type,
    required String description,
    required double amount,
    String? showId,
    String paymentMethod = 'cash',
    String? notes,
    DateTime? expenseDate,
  }) async {
    final data = await _post(ApiConfig.expenses, {
      'expense_type':   type,
      'description':    description,
      'amount':         amount,
      'show_id':        showId,
      'payment_method': paymentMethod,
      'notes':          notes,
      'expense_date':   expenseDate?.toIso8601String().split('T')[0],
    });
    return Expense.fromApiJson(data);
  }

  Future<Expense> updateExpense({
    required String expenseId,
    required String type,
    required String description,
    required double amount,
    String paymentMethod = 'cash',
    String? notes,
    DateTime? expenseDate,
  }) async {
    final data = await _put('${ApiConfig.expenses}/$expenseId', {
      'expense_type':   type,
      'description':    description,
      'amount':         amount,
      'payment_method': paymentMethod,
      'notes':          notes,
      'expense_date':   expenseDate?.toIso8601String().split('T')[0],
    });
    return Expense.fromApiJson(data);
  }

  Future<void> deleteExpense(String expenseId) =>
      _delete('${ApiConfig.expenses}/$expenseId');

  // ── Reports ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getShowROI({int? year}) async {
    return await _get('${ApiConfig.reports}/show-roi',
        params: year != null ? {'year': '$year'} : null);
  }

  Future<Map<String, dynamic>> getFinancialSummary({int? year}) async {
    return await _get('${ApiConfig.reports}/financial-summary',
        params: year != null ? {'year': '$year'} : null);
  }

  Future<Map<String, dynamic>> getTopPerformers({int limit = 20, int? year}) async {
    final params = <String, String>{'limit': '$limit'};
    if (year != null) params['year'] = '$year';
    return await _get('${ApiConfig.reports}/top-performers', params: params);
  }

  Future<Map<String, dynamic>> getInventoryHealth() async {
    return await _get('${ApiConfig.reports}/inventory-health');
  }

  Future<Map<String, dynamic>> getChannelPerformance({int? year}) async {
    return await _get('${ApiConfig.reports}/channel-performance',
        params: year != null ? {'year': '$year'} : null);
  }

  // ── Card search ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> searchCards(
    String query, {
    String? category,
    int limit = 20,
  }) async {
    return await _get('${ApiConfig.cards}/search', params: {
      'q': query,
      'limit': '$limit',
      if (category != null) 'category': category,
    });
  }

  Future<Map<String, dynamic>> getCardDetail(String productId) async {
    return await _get('${ApiConfig.cards}/$productId');
  }

  // ── AI Scan ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> scanCard(File imageFile) async {
    final token = await AuthService.instance.getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.scan}'),
    );
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _handle(response);
  }

  Future<Map<String, dynamic>> confirmScan({
    required String scanId,
    required String productId,
    double? purchasePrice,
    double? askingPrice,
    String? condition,
    int quantity = 1,
    String? showId,
  }) async {
    return await _post('${ApiConfig.scan}/confirm', {
      'scan_id':        scanId,
      'product_id':     productId,
      'purchase_price': purchasePrice,
      'asking_price':   askingPrice,
      'condition':      condition,
      'quantity':       quantity,
      'show_id':        showId,
    });
  }
}
