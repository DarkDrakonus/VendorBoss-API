import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/mock_data_service.dart';

class InventoryHealthReport extends StatefulWidget {
  final int startTab;
  const InventoryHealthReport({super.key, this.startTab = 0});

  @override
  State<InventoryHealthReport> createState() => _InventoryHealthReportState();
}

class _InventoryHealthReportState extends State<InventoryHealthReport>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this, initialIndex: widget.startTab);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Health'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Aged Inventory'),
            Tab(text: 'Price Drift'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _AgedInventoryTab(),
          _PriceDriftTab(),
        ],
      ),
    );
  }
}

// ── Aged Inventory Tab ────────────────────────────────────────────────────────

class _AgedInventoryTab extends StatelessWidget {
  const _AgedInventoryTab();

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$');
    final health   = MockDataService.inventoryHealth;

    final fresh    = health.where((h) => h.daysHeld < 30).toList();
    final moderate = health.where((h) => h.daysHeld >= 30 && h.daysHeld < 60).toList();
    final aged     = health.where((h) => h.daysHeld >= 60 && h.daysHeld < 90).toList();
    final stale    = health.where((h) => h.daysHeld >= 90).toList();

    final capitalFresh    = fresh.fold(0.0,    (s, h) => s + h.capitalTied);
    final capitalModerate = moderate.fold(0.0, (s, h) => s + h.capitalTied);
    final capitalAged     = aged.fold(0.0,     (s, h) => s + h.capitalTied);
    final capitalStale    = stale.fold(0.0,    (s, h) => s + h.capitalTied);
    final totalCapital    = capitalFresh + capitalModerate + capitalAged + capitalStale;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // Capital at risk summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:        AppColors.darkSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Capital Tied Up',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              const SizedBox(height: 8),
              Text(currency.format(totalCapital),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              _AgeBar('< 30 days',  capitalFresh,    totalCapital, AppColors.success),
              _AgeBar('30-60 days', capitalModerate, totalCapital, AppColors.accent),
              _AgeBar('60-90 days', capitalAged,     totalCapital, AppColors.warning),
              _AgeBar('90+ days',   capitalStale,    totalCapital, AppColors.danger),
            ],
          ),
        ),

        const SizedBox(height: 20),

        if (stale.isNotEmpty) ...[
          _AgeGroupHeader('90+ DAYS  —  CONSIDER MARKDOWNS', AppColors.danger),
          ...stale.map((h) => _HealthRow(h: h, currency: currency)),
          const SizedBox(height: 16),
        ],

        if (aged.isNotEmpty) ...[
          _AgeGroupHeader('60-90 DAYS  —  MONITOR PRICING', AppColors.warning),
          ...aged.map((h) => _HealthRow(h: h, currency: currency)),
          const SizedBox(height: 16),
        ],

        if (moderate.isNotEmpty) ...[
          _AgeGroupHeader('30-60 DAYS', AppColors.accent),
          ...moderate.map((h) => _HealthRow(h: h, currency: currency)),
          const SizedBox(height: 16),
        ],

        if (fresh.isNotEmpty) ...[
          _AgeGroupHeader('FRESH  (<30 DAYS)', AppColors.success),
          ...fresh.map((h) => _HealthRow(h: h, currency: currency)),
        ],
      ],
    );
  }
}

class _AgeBar extends StatelessWidget {
  final String label;
  final double value;
  final double total;
  final Color color;
  const _AgeBar(this.label, this.value, this.total, this.color);

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$');
    final pct      = total > 0 ? value / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(width: 80,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value:           pct,
              minHeight:       6,
              backgroundColor: AppColors.darkSurfaceElevated,
              valueColor:      AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(currency.format(value),
              textAlign: TextAlign.right,
              style: TextStyle(
                  color:      color,
                  fontWeight: FontWeight.w600,
                  fontSize:   11)),
        ),
      ]),
    );
  }
}

// Used only in Aged tab
class _AgeGroupHeader extends StatelessWidget {
  final String text;
  final Color color;
  const _AgeGroupHeader(this.text, this.color);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text,
        style: TextStyle(
            fontSize:      10,
            fontWeight:    FontWeight.w800,
            color:         color,
            letterSpacing: 1.2)),
  );
}

class _HealthRow extends StatelessWidget {
  final InventoryHealthItem h;
  final NumberFormat currency;
  const _HealthRow({required this.h, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.item.displayName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                Text('${h.item.setName} · ${h.daysHeld}d in stock',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(currency.format(h.capitalTied),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const Text('paid',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
        ]),
      ),
    );
  }
}

// ── Price Drift Tab ───────────────────────────────────────────────────────────

class _PriceDriftTab extends StatelessWidget {
  const _PriceDriftTab();

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$');
    final health   = MockDataService.inventoryHealth
        .where((h) => h.priceDrift != null)
        .toList()
      ..sort((a, b) => (b.priceDrift!.abs()).compareTo(a.priceDrift!.abs()));

    final overpriced  = health.where((h) => (h.priceDrift ?? 0) > 10).toList();
    final underpriced = health.where((h) => (h.priceDrift ?? 0) < -5).toList();
    final onMarket    = health
        .where((h) =>
            (h.priceDrift ?? 0).abs() <= 10 && (h.priceDrift ?? 0) >= -5)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // Summary chips
        Row(children: [
          Expanded(child: _SummaryChip(
              '${overpriced.length}', 'Overpriced', AppColors.danger)),
          const SizedBox(width: 10),
          Expanded(child: _SummaryChip(
              '${onMarket.length}', 'On Market', AppColors.success)),
          const SizedBox(width: 10),
          Expanded(child: _SummaryChip(
              '${underpriced.length}', 'Underpriced', AppColors.warning)),
        ]),

        const SizedBox(height: 20),

        if (overpriced.isNotEmpty) ...[
          _DriftGroupHeader('OVERPRICED  (>10% above market)', AppColors.danger),
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'These cards may be sitting unsold because your asking price is '
              'above current market. Consider a markdown.',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 12, height: 1.4),
            ),
          ),
          ...overpriced.map((h) => _DriftRow(h: h, currency: currency)),
          const SizedBox(height: 16),
        ],

        if (underpriced.isNotEmpty) ...[
          _DriftGroupHeader('UNDERPRICED  (>5% below market)', AppColors.warning),
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'You may be leaving money on the table. '
              'Consider raising your asking price.',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 12, height: 1.4),
            ),
          ),
          ...underpriced.map((h) => _DriftRow(h: h, currency: currency)),
          const SizedBox(height: 16),
        ],

        if (onMarket.isNotEmpty) ...[
          _DriftGroupHeader('ON MARKET  (within 10%)', AppColors.success),
          ...onMarket.map((h) => _DriftRow(h: h, currency: currency)),
        ],
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String count, label;
  final Color color;
  const _SummaryChip(this.count, this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color:        color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      border:       Border.all(color: color.withOpacity(0.3)),
    ),
    child: Column(children: [
      Text(count,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w800, fontSize: 22)),
      Text(label,
          style: TextStyle(color: color.withOpacity(0.8), fontSize: 11)),
    ]),
  );
}

// Used only in Price Drift tab — named differently to avoid collision
class _DriftGroupHeader extends StatelessWidget {
  final String text;
  final Color color;
  const _DriftGroupHeader(this.text, this.color);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text,
        style: TextStyle(
            fontSize:      10,
            fontWeight:    FontWeight.w800,
            color:         color,
            letterSpacing: 1.2)),
  );
}

class _DriftRow extends StatelessWidget {
  final InventoryHealthItem h;
  final NumberFormat currency;
  const _DriftRow({required this.h, required this.currency});

  @override
  Widget build(BuildContext context) {
    final drift      = h.priceDrift ?? 0;
    final driftColor = drift > 10  ? AppColors.danger
                     : drift < -5  ? AppColors.warning
                     : AppColors.success;
    final driftStr   = drift >= 0
        ? '+${drift.toStringAsFixed(1)}%'
        : '${drift.toStringAsFixed(1)}%';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.item.displayName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                Text(h.item.setName,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(children: [
                Text(currency.format(h.item.askingPrice),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const Text(' ask',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              ]),
              Row(children: [
                Text(currency.format(h.item.marketPrice),
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
                const Text(' mkt',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              ]),
            ],
          ),
          const SizedBox(width: 12),
          Container(
            padding:    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:        driftColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(driftStr,
                style: TextStyle(
                    color:      driftColor,
                    fontWeight: FontWeight.w800,
                    fontSize:   13)),
          ),
        ]),
      ),
    );
  }
}
