import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

const _bulkColor = Color(0xFF7B61FF);

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

class BulkEffectivenessReport extends StatefulWidget {
  const BulkEffectivenessReport({super.key});

  @override
  State<BulkEffectivenessReport> createState() => _BulkEffectivenessReportState();
}

class _BulkEffectivenessReportState extends State<BulkEffectivenessReport> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.instance.getBulkSales();
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
        title: const Text('Bulk Effectiveness'),
        actions: [
          if (_loading)
            const Padding(padding: EdgeInsets.all(16),
                child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)))
          else
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _error != null && _data == null
          ? _ErrorBody(error: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: _buildBody(),
            ),
    );
  }

  Widget _buildBody() {
    if (_data == null) return const Center(child: CircularProgressIndicator());
    final currency = NumberFormat.currency(symbol: '\$');

    final totalBulkRev   = _d(_data!['total_bulk_revenue']);
    final totalSingleRev = _d(_data!['total_single_revenue']);
    final totalRev       = _d(_data!['total_revenue']);
    final bulkCount      = _i(_data!['bulk_count']);
    final singleCount    = _i(_data!['single_count']);
    final bulkPct        = _d(_data!['bulk_pct']);
    final avgBulk        = _d(_data!['avg_bulk_sale']);
    final byShow = (_data!['by_show'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    if (totalRev == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.layers_outlined, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            const Text('No sales recorded yet.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Complete bulk and card sales to see effectiveness data.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textLight, fontSize: 13)),
          ]),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        // Stats
        Row(children: [
          Expanded(child: _StatCard('Bulk Txns',    '$bulkCount',                    _bulkColor)),
          const SizedBox(width: 8),
          Expanded(child: _StatCard('Bulk Revenue', currency.format(totalBulkRev),   _bulkColor)),
          const SizedBox(width: 8),
          Expanded(child: _StatCard('Bulk % Rev',   '${bulkPct.toStringAsFixed(1)}%', _bulkColor)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _StatCard('Avg Bulk Sale',    currency.format(avgBulk),           AppColors.textSecondary)),
          const SizedBox(width: 8),
          Expanded(child: _StatCard('Singles Revenue',  currency.format(totalSingleRev),    AppColors.accent)),
          const SizedBox(width: 8),
          Expanded(child: _StatCard('Total Revenue',    currency.format(totalRev),          AppColors.textSecondary)),
        ]),

        const SizedBox(height: 24),

        // Revenue mix bar
        const _SectionLabel('OVERALL REVENUE MIX'),
        const SizedBox(height: 12),
        _RevenueMixCard(
          bulkRev: totalBulkRev,
          singleRev: totalSingleRev,
          bulkPct: bulkPct,
          bulkCount: bulkCount,
          avgBulk: avgBulk,
          currency: currency,
        ),

        const SizedBox(height: 24),

        // Per-show breakdown
        if (byShow.isNotEmpty) ...[
          const _SectionLabel('BY SHOW / CATEGORY'),
          const SizedBox(height: 12),
          ...byShow.map((d) => _ShowBulkCard(data: d, currency: currency)),
        ],

        const SizedBox(height: 20),

        // Reading guide
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.darkSurface, borderRadius: BorderRadius.circular(10)),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('How to read Bulk %',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            SizedBox(height: 8),
            _GuideLine('< 10%',  'Minor supplement — primarily a singles business'),
            _GuideLine('10–25%', 'Healthy mix — bulk moving without dominating floor space'),
            _GuideLine('25–40%', 'Bulk-heavy — evaluate if table space is worth it'),
            _GuideLine('> 40%',  'Bulk-dominant — may signal difficulty moving singles'),
          ]),
        ),
      ],
    );
  }
}

// ── Revenue mix card ──────────────────────────────────────────────────────────

class _RevenueMixCard extends StatelessWidget {
  final double bulkRev, singleRev, bulkPct, avgBulk;
  final int bulkCount;
  final NumberFormat currency;
  const _RevenueMixCard({required this.bulkRev, required this.singleRev,
      required this.bulkPct, required this.bulkCount, required this.avgBulk,
      required this.currency});

  @override
  Widget build(BuildContext context) {
    final total = bulkRev + singleRev;
    final bulkFrac = total > 0 ? bulkRev / total : 0.0;
    final insight = _insight();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkSurface, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Split bar
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 18,
            child: Row(children: [
              Flexible(
                flex: ((1 - bulkFrac) * 1000).toInt().clamp(1, 999),
                child: Container(color: AppColors.accent),
              ),
              Flexible(
                flex: (bulkFrac * 1000).toInt().clamp(1, 999),
                child: Container(color: _bulkColor),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          _Legend('Singles  ${currency.format(singleRev)}', AppColors.accent),
          const Spacer(),
          _Legend('Bulk  ${currency.format(bulkRev)}', _bulkColor),
        ]),
        const SizedBox(height: 12),
        Text(insight, style: const TextStyle(
            color: AppColors.textSecondary, fontSize: 12, height: 1.5)),
      ]),
    );
  }

  String _insight() {
    if (bulkCount == 0) return 'No bulk sales recorded yet.';
    final avg = currency.format(avgBulk);
    if (bulkPct < 10) {
      return 'Bulk is ${bulkPct.toStringAsFixed(1)}% of revenue across $bulkCount transactions '
          '(avg $avg each). Your business is primarily singles-driven.';
    } else if (bulkPct < 25) {
      return 'Bulk is ${bulkPct.toStringAsFixed(1)}% of revenue across $bulkCount transactions '
          '(avg $avg each). Healthy balance — bulk is moving without overshadowing singles.';
    } else {
      return 'Bulk is ${bulkPct.toStringAsFixed(1)}% of revenue across $bulkCount transactions '
          '(avg $avg each). Consider whether the setup time bulk requires '
          'is justified vs focusing on higher-margin singles.';
    }
  }
}

// ── Per-show card ─────────────────────────────────────────────────────────────

class _ShowBulkCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final NumberFormat currency;
  const _ShowBulkCard({required this.data, required this.currency});

  @override
  Widget build(BuildContext context) {
    final bulkRev    = _d(data['bulk_revenue']);
    final singleRev  = _d(data['single_revenue']);
    final totalRev   = _d(data['total_revenue']);
    final bulkCount  = _i(data['bulk_count']);
    final bulkPct    = _d(data['bulk_pct']);
    final showName   = data['show_name'] as String? ?? 'Unknown';
    final hasBulk    = bulkCount > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(showName,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 12),
          if (!hasBulk)
            const Text('No bulk sales at this show.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13))
          else ...[
            Row(children: [
              _Mini('$bulkCount',                         'Bulk Sales',   _bulkColor),
              const SizedBox(width: 20),
              _Mini(currency.format(bulkRev),             'Bulk Rev',     _bulkColor),
              const SizedBox(width: 20),
              _Mini('${bulkPct.toStringAsFixed(0)}%',     'of Revenue',   _bulkColor),
              const SizedBox(width: 20),
              _Mini(currency.format(totalRev),            'Total Rev',    AppColors.textSecondary),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Row(children: [
                  Flexible(
                    flex: (singleRev * 10).toInt().clamp(1, 9999),
                    child: Container(color: AppColors.accent),
                  ),
                  Flexible(
                    flex: (bulkRev * 10).toInt().clamp(1, 9999),
                    child: Container(color: _bulkColor),
                  ),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value; final Color color;
  const _StatCard(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14),
          maxLines: 1, overflow: TextOverflow.ellipsis),
    ]),
  );
}

class _SectionLabel extends StatelessWidget {
  final String text; const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(
      fontSize: 10, fontWeight: FontWeight.w800,
      color: AppColors.textSecondary, letterSpacing: 1.2));
}

class _Legend extends StatelessWidget {
  final String label; final Color color;
  const _Legend(this.label, this.color);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 5),
    Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
  ]);
}

class _Mini extends StatelessWidget {
  final String value, label; final Color color;
  const _Mini(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14)),
    Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
  ]);
}

class _GuideLine extends StatelessWidget {
  final String range, meaning;
  const _GuideLine(this.range, this.meaning);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 52, child: Text(range, style: const TextStyle(
          color: _bulkColor, fontWeight: FontWeight.w700, fontSize: 12))),
      const SizedBox(width: 8),
      Expanded(child: Text(meaning,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
    ]),
  );
}

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
