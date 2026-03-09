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

class TopPerformersReport extends StatefulWidget {
  const TopPerformersReport({super.key});

  @override
  State<TopPerformersReport> createState() => _TopPerformersReportState();
}

class _TopPerformersReportState extends State<TopPerformersReport> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String _gameFilter = 'All';
  String _sortBy = 'profit'; // profit | margin | revenue | units

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.instance.getTopPerformers(limit: 50);
      if (!mounted) return;
      final items = (data['items'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      setState(() { _items = items; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    var list = List<Map<String, dynamic>>.from(_items);
    if (_gameFilter != 'All') {
      list = list.where((p) => (p['game'] ?? '') == _gameFilter).toList();
    }
    switch (_sortBy) {
      case 'margin':  list.sort((a, b) => _d(b['margin_percent']).compareTo(_d(a['margin_percent']))); break;
      case 'revenue': list.sort((a, b) => _d(b['total_revenue']).compareTo(_d(a['total_revenue']))); break;
      case 'units':   list.sort((a, b) => _i(b['units_sold']).compareTo(_i(a['units_sold']))); break;
      default:        list.sort((a, b) => _d(b['profit']).compareTo(_d(a['profit'])));
    }
    return list;
  }

  List<String> get _games {
    final games = {'All', ..._items.map((p) => (p['game'] as String? ?? 'Other'))};
    return games.toList();
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Top Performers'),
        actions: [
          if (_loading)
            const Padding(padding: EdgeInsets.all(16),
                child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)))
          else
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort by',
            initialValue: _sortBy,
            onSelected: (v) => setState(() => _sortBy = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'profit',  child: Text('Sort by Profit')),
              PopupMenuItem(value: 'margin',  child: Text('Sort by Margin %')),
              PopupMenuItem(value: 'revenue', child: Text('Sort by Revenue')),
              PopupMenuItem(value: 'units',   child: Text('Sort by Units Sold')),
            ],
          ),
        ],
      ),
      body: _error != null && _items.isEmpty
          ? _ErrorBody(error: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: _buildBody(currency),
            ),
    );
  }

  Widget _buildBody(NumberFormat currency) {
    final filtered = _filtered;
    final top10 = filtered.take(10).toList();

    final totalProfit  = filtered.fold(0.0, (s, p) => s + _d(p['profit']));
    final totalRevenue = filtered.fold(0.0, (s, p) => s + _d(p['total_revenue']));
    final avgMargin    = totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0.0;

    // Game profit breakdown
    final gameProfit = <String, double>{};
    for (final p in _items) {
      final g = (p['game'] as String? ?? 'Other');
      gameProfit[g] = (gameProfit[g] ?? 0) + _d(p['profit']);
    }
    final topGame = gameProfit.isEmpty
        ? null
        : gameProfit.entries.reduce((a, b) => a.value > b.value ? a : b);

    if (_items.isEmpty && !_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.emoji_events_outlined, size: 56, color: AppColors.textSecondary),
            SizedBox(height: 16),
            Text('No sales recorded yet.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            SizedBox(height: 8),
            Text('Complete some sales to see your top performers.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textLight, fontSize: 13)),
          ]),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        // Summary
        Row(children: [
          Expanded(child: _StatCard(label: 'Total Profit',   value: currency.format(totalProfit),  color: AppColors.success)),
          const SizedBox(width: 8),
          Expanded(child: _StatCard(label: 'Total Revenue',  value: currency.format(totalRevenue), color: AppColors.accent)),
          const SizedBox(width: 8),
          Expanded(child: _StatCard(label: 'Avg Margin',     value: '${avgMargin.toStringAsFixed(1)}%', color: AppColors.info)),
        ]),

        const SizedBox(height: 16),

        // Game profit bars
        if (gameProfit.length > 1) ...[
          const _SectionLabel('PROFIT BY GAME'),
          const SizedBox(height: 10),
          _GameProfitBars(gameProfit: gameProfit, currency: currency),
          const SizedBox(height: 20),
        ],

        // Game filter chips
        if (_games.length > 2) ...[
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _games.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final g = _games[i];
                final selected = _gameFilter == g;
                return GestureDetector(
                  onTap: () => setState(() => _gameFilter = g),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.accent.withOpacity(0.15) : AppColors.darkSurfaceElevated,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: selected ? AppColors.accent : Colors.transparent),
                    ),
                    child: Text(g, style: TextStyle(
                      color: selected ? AppColors.accent : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                      fontSize: 13,
                    )),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Ranked list
        _SectionLabel(top10.isEmpty
            ? 'NO DATA FOR ${_gameFilter.toUpperCase()}'
            : 'TOP ${top10.length} — ${_sortByLabel(_sortBy).toUpperCase()}'),
        const SizedBox(height: 12),

        if (top10.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No sales data for this game yet.',
                style: TextStyle(color: AppColors.textSecondary))),
          )
        else
          ...top10.asMap().entries.map((e) => _PerformerRow(
            rank: e.key + 1,
            item: e.value,
            sortBy: _sortBy,
            currency: currency,
          )),

        // Buylist insight
        if (top10.isNotEmpty) ...[
          const SizedBox(height: 8),
          _InsightCard(
            icon: Icons.lightbulb_outline,
            color: AppColors.accent,
            title: 'Buylist Recommendation',
            body: _bulistInsight(top10, topGame, currency),
          ),
        ],

        const SizedBox(height: 24),

        // Margin distribution
        if (filtered.length >= 3) ...[
          const _SectionLabel('MARGIN DISTRIBUTION'),
          const SizedBox(height: 12),
          _MarginDistribution(items: filtered),
          const SizedBox(height: 20),
        ],

        // Low margin attention items
        if (filtered.length >= 3) ...[
          const _SectionLabel('NEEDS ATTENTION'),
          const SizedBox(height: 6),
          const Text(
            'Cards with the lowest margins — best candidates for pricing review.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          ..._lowMarginCards(filtered, currency),
        ],
      ],
    );
  }

  String _sortByLabel(String s) {
    switch (s) {
      case 'margin':  return 'Margin %';
      case 'revenue': return 'Revenue';
      case 'units':   return 'Units Sold';
      default:        return 'Profit';
    }
  }

  String _bulistInsight(List<Map<String, dynamic>> top,
      MapEntry<String, double>? topGame, NumberFormat currency) {
    if (top.isEmpty) return 'Not enough data yet.';
    final best = top.first;
    final name = best['card_name'] ?? 'Unknown';
    final profit = _d(best['profit']);
    final margin = _d(best['margin_percent']);
    final marginNote = margin > 50
        ? 'at a ${margin.toStringAsFixed(0)}% margin — exceptional.'
        : 'at a ${margin.toStringAsFixed(0)}% margin.';
    final gameNote = topGame != null
        ? ' Your most profitable game is ${topGame.key} at ${currency.format(topGame.value)} total profit.'
        : '';
    return '$name is your top earner at ${currency.format(profit)} profit $marginNote '
        'Prioritize buying more of this type at your next show.$gameNote';
  }

  List<Widget> _lowMarginCards(List<Map<String, dynamic>> all, NumberFormat currency) {
    final low = all.where((p) => _d(p['margin_percent']) < 20 && _d(p['total_revenue']) > 10).toList()
      ..sort((a, b) => _d(a['margin_percent']).compareTo(_d(b['margin_percent'])));
    if (low.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
          child: const Row(children: [
            Icon(Icons.check_circle_outline, color: AppColors.success, size: 16),
            SizedBox(width: 8),
            Text('All cards have healthy margins above 20%.',
                style: TextStyle(color: AppColors.success, fontSize: 13)),
          ]),
        ),
      ];
    }
    return low.take(5).map((p) => Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          const Icon(Icons.warning_amber_outlined, color: AppColors.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p['card_name'] ?? 'Unknown',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            Text('${p['game'] ?? ''} · ${_i(p['units_sold'])} sold',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${_d(p['margin_percent']).toStringAsFixed(0)}% margin',
                style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700, fontSize: 13)),
            Text(currency.format(_d(p['profit'])),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ]),
        ]),
      ),
    )).toList();
  }
}

// ── Game profit bars ──────────────────────────────────────────────────────────

class _GameProfitBars extends StatelessWidget {
  final Map<String, double> gameProfit;
  final NumberFormat currency;
  const _GameProfitBars({required this.gameProfit, required this.currency});

  static const _colors = [
    AppColors.accent, Color(0xFF7B61FF), AppColors.info,
    Color(0xFFFF6B35), AppColors.success, AppColors.warning,
  ];

  @override
  Widget build(BuildContext context) {
    final sorted = gameProfit.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold(0.0, (s, e) => s + e.value);
    return Column(
      children: sorted.asMap().entries.map((e) {
        final color = _colors[e.key % _colors.length];
        final pct = total > 0 ? e.value.value / total : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            SizedBox(width: 100, child: Text(e.value.key,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Expanded(child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct, minHeight: 10,
                backgroundColor: AppColors.darkSurfaceElevated,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            )),
            const SizedBox(width: 8),
            SizedBox(width: 60,
              child: Text(currency.format(e.value.value),
                  textAlign: TextAlign.right,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12))),
          ]),
        );
      }).toList(),
    );
  }
}

// ── Performer row ─────────────────────────────────────────────────────────────

class _PerformerRow extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> item;
  final String sortBy;
  final NumberFormat currency;
  const _PerformerRow({required this.rank, required this.item,
      required this.sortBy, required this.currency});

  @override
  Widget build(BuildContext context) {
    final isTop3    = rank <= 3;
    final rankColor = rank == 1 ? const Color(0xFFFFD700)
                    : rank == 2 ? const Color(0xFFC0C0C0)
                    : rank == 3 ? const Color(0xFFCD7F32)
                    : AppColors.textSecondary;
    final margin    = _d(item['margin_percent']);
    final profit    = _d(item['profit']);
    final revenue   = _d(item['total_revenue']);
    final units     = _i(item['units_sold']);

    final primaryValue = switch (sortBy) {
      'margin'  => '${margin.toStringAsFixed(0)}%',
      'revenue' => currency.format(revenue),
      'units'   => '$units units',
      _         => currency.format(profit),
    };
    final primaryColor = switch (sortBy) {
      'margin'  => margin >= 20 ? AppColors.success : AppColors.warning,
      'revenue' => AppColors.accent,
      'units'   => AppColors.info,
      _         => profit >= 0 ? AppColors.success : AppColors.danger,
    };
    final secondaryValue = switch (sortBy) {
      'margin'  => '${margin.toStringAsFixed(0)}% margin',
      'revenue' => '${currency.format(revenue)} rev',
      'units'   => '$units sold',
      _         => '${margin.toStringAsFixed(0)}% margin',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isTop3 ? rankColor.withOpacity(0.15) : AppColors.darkSurfaceElevated,
            ),
            child: Center(child: Text('$rank', style: TextStyle(
                color: isTop3 ? rankColor : AppColors.textSecondary,
                fontWeight: FontWeight.w800, fontSize: 13))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item['card_name'] ?? 'Unknown',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            Text('${item['game'] ?? ''} · $units sold',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(primaryValue, style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 15, color: primaryColor)),
            Text(secondaryValue, style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 11)),
          ]),
        ]),
      ),
    );
  }
}

// ── Margin distribution ───────────────────────────────────────────────────────

class _MarginDistribution extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _MarginDistribution({required this.items});

  @override
  Widget build(BuildContext context) {
    final buckets = {
      '> 50%':  items.where((p) => _d(p['margin_percent']) > 50).length,
      '20–50%': items.where((p) { final m = _d(p['margin_percent']); return m >= 20 && m <= 50; }).length,
      '< 20%':  items.where((p) => _d(p['margin_percent']) < 20).length,
    };
    final colors = {'> 50%': AppColors.success, '20–50%': AppColors.accent, '< 20%': AppColors.warning};
    final total = items.length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(12)),
      child: Column(children: buckets.entries.map((e) {
        final pct = total > 0 ? e.value / total : 0.0;
        final color = colors[e.key]!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            SizedBox(width: 52, child: Text(e.key,
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12))),
            const SizedBox(width: 8),
            Expanded(child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct, minHeight: 8,
                backgroundColor: AppColors.darkSurfaceElevated,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            )),
            const SizedBox(width: 8),
            Text('${e.value} cards', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ]),
        );
      }).toList()),
    );
  }
}

// ── Insight card ──────────────────────────────────────────────────────────────

class _InsightCard extends StatelessWidget {
  final IconData icon; final Color color; final String title, body;
  const _InsightCard({required this.icon, required this.color,
      required this.title, required this.body});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withOpacity(0.07), borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.25))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: color, size: 16), const SizedBox(width: 6),
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
      const SizedBox(height: 6),
      Text(body, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5)),
    ]),
  );
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value; final Color color;
  const _StatCard({required this.label, required this.value, required this.color});
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
