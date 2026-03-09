import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

double _d(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

int _i(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

class InventoryHealthReport extends StatefulWidget {
  final int startTab;
  const InventoryHealthReport({super.key, this.startTab = 0});

  @override
  State<InventoryHealthReport> createState() => _InventoryHealthReportState();
}

class _InventoryHealthReportState extends State<InventoryHealthReport>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this, initialIndex: widget.startTab);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.instance.getInventoryHealth();
      if (!mounted) return;
      setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Health'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.darkTextSecondary,
          tabs: const [
            Tab(text: 'Aged Inventory'),
            Tab(text: 'Price Drift'),
          ],
        ),
        actions: [
          if (_loading)
            const Padding(padding: EdgeInsets.all(16),
                child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)))
          else
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _data == null
              ? _ErrorBody(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _AgedInventoryTab(data: _data!),
                      _PriceDriftTab(data: _data!),
                    ],
                  ),
                ),
    );
  }
}

// ── Aged Inventory Tab ────────────────────────────────────────────────────────

class _AgedInventoryTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AgedInventoryTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$');
    final items = (data['items'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    final totalCapital = _d(data['total_value_cost']);
    final aged30  = _i(data['aged_30_plus']);
    final aged60  = _i(data['aged_60_plus']);
    final aged90  = _i(data['aged_90_plus']);
    final aged180 = _i(data['aged_180_plus']);
    final total   = _i(data['total_items']);

    final fresh    = items.where((h) => _i(h['days_held']) <  30).toList();
    final moderate = items.where((h) { final d = _i(h['days_held']); return d >= 30 && d < 60; }).toList();
    final aged     = items.where((h) { final d = _i(h['days_held']); return d >= 60 && d < 90; }).toList();
    final stale    = items.where((h) => _i(h['days_held']) >= 90).toList();

    final capFresh    = fresh.fold(0.0,    (s, h) => s + _d(h['capital_tied']));
    final capModerate = moderate.fold(0.0, (s, h) => s + _d(h['capital_tied']));
    final capAged     = aged.fold(0.0,     (s, h) => s + _d(h['capital_tied']));
    final capStale    = stale.fold(0.0,    (s, h) => s + _d(h['capital_tied']));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.darkSurface, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Capital Tied Up',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            const SizedBox(height: 8),
            Text(currency.format(totalCapital),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _AgeBar('< 30 days',  capFresh,    totalCapital, AppColors.success),
            _AgeBar('30-60 days', capModerate, totalCapital, AppColors.accent),
            _AgeBar('60-90 days', capAged,     totalCapital, AppColors.warning),
            _AgeBar('90+ days',   capStale,    totalCapital, AppColors.danger),
          ]),
        ),

        if (total == 0) ...[
          const SizedBox(height: 40),
          const Center(child: Text('No inventory items found.',
              style: TextStyle(color: AppColors.textSecondary))),
        ],

        const SizedBox(height: 20),

        if (stale.isNotEmpty) ...[
          _AgeHeader('90+ DAYS  —  CONSIDER MARKDOWNS', AppColors.danger),
          ...stale.map((h) => _HealthRow(h: h, currency: currency)),
          const SizedBox(height: 16),
        ],
        if (aged.isNotEmpty) ...[
          _AgeHeader('60-90 DAYS  —  MONITOR PRICING', AppColors.warning),
          ...aged.map((h) => _HealthRow(h: h, currency: currency)),
          const SizedBox(height: 16),
        ],
        if (moderate.isNotEmpty) ...[
          _AgeHeader('30-60 DAYS', AppColors.accent),
          ...moderate.map((h) => _HealthRow(h: h, currency: currency)),
          const SizedBox(height: 16),
        ],
        if (fresh.isNotEmpty) ...[
          _AgeHeader('FRESH  (<30 DAYS)', AppColors.success),
          ...fresh.map((h) => _HealthRow(h: h, currency: currency)),
        ],
      ],
    );
  }
}

class _AgeBar extends StatelessWidget {
  final String label;
  final double value, total;
  final Color color;
  const _AgeBar(this.label, this.value, this.total, this.color);

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$');
    final pct = total > 0 ? value / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(width: 80, child: Text(label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11))),
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: pct, minHeight: 6,
            backgroundColor: AppColors.darkSurfaceElevated,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        )),
        const SizedBox(width: 8),
        SizedBox(width: 70, child: Text(currency.format(value),
            textAlign: TextAlign.right,
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11))),
      ]),
    );
  }
}

class _AgeHeader extends StatelessWidget {
  final String text; final Color color;
  const _AgeHeader(this.text, this.color);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: TextStyle(
        fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: 1.2)),
  );
}

class _HealthRow extends StatelessWidget {
  final Map<String, dynamic> h;
  final NumberFormat currency;
  const _HealthRow({required this.h, required this.currency});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(h['card_name'] ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          Text('${h['set_name'] ?? h['game'] ?? ''} · ${_i(h['days_held'])}d in stock',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(currency.format(_d(h['capital_tied'])),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const Text('paid', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ]),
      ]),
    ),
  );
}

// ── Price Drift Tab ───────────────────────────────────────────────────────────

class _PriceDriftTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PriceDriftTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$');
    final items = (data['items'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .where((h) => h['price_drift_pct'] != null)
        .toList()
      ..sort((a, b) => _d(b['price_drift_pct']).abs().compareTo(_d(a['price_drift_pct']).abs()));

    final overpriced  = items.where((h) => _d(h['price_drift_pct']) > 10).toList();
    final underpriced = items.where((h) => _d(h['price_drift_pct']) < -5).toList();
    final onMarket    = items.where((h) {
      final drift = _d(h['price_drift_pct']);
      return drift <= 10 && drift >= -5;
    }).toList();

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.price_change_outlined, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            const Text('No price data available.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Price drift requires market prices to be set on your inventory items.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textLight, fontSize: 13)),
          ]),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        Row(children: [
          Expanded(child: _SummaryChip('${overpriced.length}',  'Overpriced',  AppColors.danger)),
          const SizedBox(width: 10),
          Expanded(child: _SummaryChip('${onMarket.length}',    'On Market',   AppColors.success)),
          const SizedBox(width: 10),
          Expanded(child: _SummaryChip('${underpriced.length}', 'Underpriced', AppColors.warning)),
        ]),

        const SizedBox(height: 20),

        if (overpriced.isNotEmpty) ...[
          _DriftHeader('OVERPRICED  (>10% above market)', AppColors.danger),
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text('These cards may be sitting unsold. Consider a markdown.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
          ),
          ...overpriced.map((h) => _DriftRow(h: h, currency: currency)),
          const SizedBox(height: 16),
        ],

        if (underpriced.isNotEmpty) ...[
          _DriftHeader('UNDERPRICED  (>5% below market)', AppColors.warning),
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text('You may be leaving money on the table. Consider raising your price.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
          ),
          ...underpriced.map((h) => _DriftRow(h: h, currency: currency)),
          const SizedBox(height: 16),
        ],

        if (onMarket.isNotEmpty) ...[
          _DriftHeader('ON MARKET  (within 10%)', AppColors.success),
          ...onMarket.map((h) => _DriftRow(h: h, currency: currency)),
        ],
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String count, label; final Color color;
  const _SummaryChip(this.count, this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.3))),
    child: Column(children: [
      Text(count, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 22)),
      Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 11)),
    ]),
  );
}

class _DriftHeader extends StatelessWidget {
  final String text; final Color color;
  const _DriftHeader(this.text, this.color);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: TextStyle(
        fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: 1.2)),
  );
}

class _DriftRow extends StatelessWidget {
  final Map<String, dynamic> h;
  final NumberFormat currency;
  const _DriftRow({required this.h, required this.currency});

  @override
  Widget build(BuildContext context) {
    final drift = _d(h['price_drift_pct']);
    final driftColor = drift > 10 ? AppColors.danger
                     : drift < -5 ? AppColors.warning
                     : AppColors.success;
    final driftStr = drift >= 0
        ? '+${drift.toStringAsFixed(1)}%'
        : '${drift.toStringAsFixed(1)}%';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(h['card_name'] ?? 'Unknown',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            Text(h['set_name'] ?? h['game'] ?? '',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ])),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (h['asking_price'] != null)
              Row(children: [
                Text(currency.format(_d(h['asking_price'])),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const Text(' ask', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ]),
            if (h['market_price'] != null)
              Row(children: [
                Text(currency.format(_d(h['market_price'])),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                const Text(' mkt', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ]),
          ]),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: driftColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Text(driftStr, style: TextStyle(
                color: driftColor, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
        ]),
      ),
    );
  }
}

// ── Error body ────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  final String error; final VoidCallback onRetry;
  const _ErrorBody({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.wifi_off, size: 48, color: AppColors.textSecondary),
      const SizedBox(height: 12),
      Text(error, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          textAlign: TextAlign.center),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
    ]),
  ));
}
