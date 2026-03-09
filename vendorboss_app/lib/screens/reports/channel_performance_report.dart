import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
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

class ChannelPerformanceReport extends StatefulWidget {
  const ChannelPerformanceReport({super.key});

  @override
  State<ChannelPerformanceReport> createState() => _ChannelPerformanceReportState();
}

class _ChannelPerformanceReportState extends State<ChannelPerformanceReport> {
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
      final data = await ApiService.instance.getChannelPerformance();
      if (!mounted) return;
      setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$');
    final channels = (_data?['channels'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final totalRevenue = _d(_data?['total_revenue']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Channel Performance'),
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
              child: _buildBody(channels, totalRevenue, currency),
            ),
    );
  }

  Widget _buildBody(List<Map<String, dynamic>> channels, double totalRevenue, NumberFormat currency) {
    if (channels.isEmpty && !_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.bar_chart_outlined, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            const Text('No sales recorded yet.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Complete some sales to see channel breakdown.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textLight, fontSize: 13)),
          ]),
        ),
      );
    }

    final totalTxns = channels.fold(0, (s, c) => s + _i(c['transaction_count']));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        // Summary
        Row(children: [
          Expanded(child: _StatCard('Total Revenue',    currency.format(totalRevenue), AppColors.accent)),
          const SizedBox(width: 8),
          Expanded(child: _StatCard('Transactions',     '$totalTxns',                  AppColors.info)),
          const SizedBox(width: 8),
          Expanded(child: _StatCard('Channels Active',  '${channels.length}',          AppColors.textSecondary)),
        ]),

        const SizedBox(height: 24),

        // Revenue share bars
        const _Label('REVENUE SHARE BY CHANNEL'),
        const SizedBox(height: 12),
        ...channels.map((c) => _ChannelBar(channel: c, totalRevenue: totalRevenue, currency: currency)),

        const SizedBox(height: 24),

        // Detailed cards
        const _Label('BREAKDOWN'),
        const SizedBox(height: 12),
        ...channels.map((c) => _ChannelCard(channel: c, currency: currency)),

        const SizedBox(height: 20),

        // Note about channels
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.darkSurface, borderRadius: BorderRadius.circular(10)),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Channels reflect the payment method selected at the time of each sale '
              '(cash, card, or trade). Marketplace platform integration (TCGPlayer, eBay, Whatnot) '
              'is coming in a future update.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5))),
          ]),
        ),
      ],
    );
  }
}

// ── Channel share bar ─────────────────────────────────────────────────────────

class _ChannelBar extends StatelessWidget {
  final Map<String, dynamic> channel;
  final double totalRevenue;
  final NumberFormat currency;
  const _ChannelBar({required this.channel, required this.totalRevenue, required this.currency});

  @override
  Widget build(BuildContext context) {
    final ch = channel['channel'] as String? ?? 'unknown';
    final rev = _d(channel['total_revenue']);
    final pct = totalRevenue > 0 ? rev / totalRevenue : 0.0;
    final color = _channelColor(ch);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(_channelLabel(ch),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          Text('${(pct * 100).toStringAsFixed(0)}%  ·  ${currency.format(rev)}',
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct, minHeight: 8,
            backgroundColor: AppColors.darkSurfaceElevated,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ]),
    );
  }
}

// ── Channel detail card ───────────────────────────────────────────────────────

class _ChannelCard extends StatelessWidget {
  final Map<String, dynamic> channel;
  final NumberFormat currency;
  const _ChannelCard({required this.channel, required this.currency});

  @override
  Widget build(BuildContext context) {
    final ch = channel['channel'] as String? ?? 'unknown';
    final rev = _d(channel['total_revenue']);
    final count = _i(channel['transaction_count']);
    final avg = _d(channel['avg_sale']);
    final color = _channelColor(ch);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.35))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_channelIcon(ch), color: color, size: 14),
                const SizedBox(width: 6),
                Text(_channelLabel(ch),
                    style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
            ),
            const Spacer(),
            Text('$count sale${count == 1 ? '' : 's'}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _Metric('Gross Revenue', currency.format(rev), AppColors.accent)),
            Expanded(child: _Metric('Transactions',  '$count',             AppColors.textSecondary)),
            Expanded(child: _Metric('Avg Sale',      currency.format(avg), color)),
          ]),
        ]),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label, value; final Color color;
  const _Metric(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
    const SizedBox(height: 2),
    Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14),
        maxLines: 1, overflow: TextOverflow.ellipsis),
  ]);
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Color _channelColor(String ch) {
  switch (ch.toLowerCase()) {
    case 'cash':     return AppColors.success;
    case 'card':     return AppColors.accent;
    case 'trade':    return const Color(0xFF7B61FF);
    case 'tcgplayer':return const Color(0xFF1DA0F2);
    case 'ebay':     return const Color(0xFF86B817);
    case 'whatnot':  return const Color(0xFF9B59B6);
    default:         return AppColors.textSecondary;
  }
}

String _channelLabel(String ch) {
  switch (ch.toLowerCase()) {
    case 'cash':     return 'Cash';
    case 'card':     return 'Card';
    case 'trade':    return 'Trade';
    case 'tcgplayer':return 'TCGPlayer';
    case 'ebay':     return 'eBay';
    case 'whatnot':  return 'Whatnot';
    case 'untracked':return 'Untracked';
    default:         return ch;
  }
}

IconData _channelIcon(String ch) {
  switch (ch.toLowerCase()) {
    case 'cash':  return Icons.payments_outlined;
    case 'card':  return Icons.credit_card_outlined;
    case 'trade': return Icons.swap_horiz_outlined;
    default:      return Icons.storefront_outlined;
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

class _Label extends StatelessWidget {
  final String text; const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(
      fontSize: 10, fontWeight: FontWeight.w800,
      color: AppColors.textSecondary, letterSpacing: 1.2));
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
