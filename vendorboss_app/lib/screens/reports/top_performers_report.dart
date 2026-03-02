import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/mock_data_service.dart';

class TopPerformersReport extends StatefulWidget {
  const TopPerformersReport({super.key});

  @override
  State<TopPerformersReport> createState() => _TopPerformersReportState();
}

class _TopPerformersReportState extends State<TopPerformersReport> {
  String _gameFilter = 'All';
  String _sortBy     = 'profit'; // profit | margin | revenue | units

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$');
    final allPerf  = MockDataService.topPerformers;

    // Distinct games present in the data
    final games = ['All', ...{...allPerf.map((p) => p.game)}];

    // Filter and sort
    var filtered = _gameFilter == 'All'
        ? allPerf
        : allPerf.where((p) => p.game == _gameFilter).toList();

    switch (_sortBy) {
      case 'margin':  filtered.sort((a, b) => b.margin.compareTo(a.margin));   break;
      case 'revenue': filtered.sort((a, b) => b.revenue.compareTo(a.revenue)); break;
      case 'units':   filtered.sort((a, b) => b.unitsSold.compareTo(a.unitsSold)); break;
      default:        filtered.sort((a, b) => b.profit.compareTo(a.profit));
    }

    final top10     = filtered.take(10).toList();
    final totalProfit  = filtered.fold(0.0, (s, p) => s + p.profit);
    final totalRevenue = filtered.fold(0.0, (s, p) => s + p.revenue);
    final avgMargin    = totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0.0;

    // Game breakdown for buylist insight
    final gameRevenue = <String, double>{};
    for (final p in allPerf) {
      gameRevenue[p.game] = (gameRevenue[p.game] ?? 0) + p.profit;
    }
    final topGame = gameRevenue.entries.isEmpty
        ? null
        : gameRevenue.entries.reduce((a, b) => a.value > b.value ? a : b);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Top Performers'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort by',
            initialValue: _sortBy,
            onSelected: (v) => setState(() => _sortBy = v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'profit',  child: Text('Sort by Profit')),
              const PopupMenuItem(value: 'margin',  child: Text('Sort by Margin %')),
              const PopupMenuItem(value: 'revenue', child: Text('Sort by Revenue')),
              const PopupMenuItem(value: 'units',   child: Text('Sort by Units Sold')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [

          // ── Summary stats ─────────────────────────────────────────────
          Row(children: [
            Expanded(child: _StatCard(
                label: 'Total Profit',
                value: currency.format(totalProfit),
                color: AppColors.success)),
            const SizedBox(width: 8),
            Expanded(child: _StatCard(
                label: 'Total Revenue',
                value: currency.format(totalRevenue),
                color: AppColors.accent)),
            const SizedBox(width: 8),
            Expanded(child: _StatCard(
                label: 'Avg Margin',
                value: '${avgMargin.toStringAsFixed(1)}%',
                color: AppColors.info)),
          ]),

          const SizedBox(height: 16),

          // ── Game portfolio breakdown ──────────────────────────────────
          if (gameRevenue.length > 1) ...[
            const _SectionLabel('PROFIT BY GAME'),
            const SizedBox(height: 10),
            _GamePieBar(gameRevenue: gameRevenue, currency: currency),
            const SizedBox(height: 20),
          ],

          // ── Game filter chips ─────────────────────────────────────────
          if (games.length > 2) ...[
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: games.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final g       = games[i];
                  final selected = _gameFilter == g;
                  return GestureDetector(
                    onTap: () => setState(() => _gameFilter = g),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.accent.withOpacity(0.15)
                            : AppColors.darkSurfaceElevated,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: selected ? AppColors.accent : Colors.transparent,
                        ),
                      ),
                      child: Text(g,
                          style: TextStyle(
                            color:      selected ? AppColors.accent : AppColors.textSecondary,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                            fontSize:   13,
                          )),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Ranked list ───────────────────────────────────────────────
          _SectionLabel(top10.isEmpty
              ? 'NO DATA FOR ${_gameFilter.toUpperCase()}'
              : 'TOP ${top10.length.toString()} — ${_sortByLabel(_sortBy).toUpperCase()}'),
          const SizedBox(height: 12),

          if (top10.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No sales data for this game yet.',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            ...top10.asMap().entries.map((e) => _PerformerRow(
              rank:     e.key + 1,
              perf:     e.value,
              sortBy:   _sortBy,
              currency: currency,
            )),

          // ── Buylist insight ───────────────────────────────────────────
          if (top10.isNotEmpty) ...[
            const SizedBox(height: 8),
            _InsightCard(
              icon:  Icons.lightbulb_outline,
              color: AppColors.accent,
              title: 'Buylist Recommendation',
              body:  _bulistInsight(top10, topGame, currency),
            ),
          ],

          const SizedBox(height: 24),

          // ── Margin analysis ───────────────────────────────────────────
          if (filtered.length >= 3) ...[
            const _SectionLabel('MARGIN DISTRIBUTION'),
            const SizedBox(height: 12),
            _MarginDistribution(performers: filtered, currency: currency),
            const SizedBox(height: 20),
          ],

          // ── Bottom performers / attention needed ──────────────────────
          if (filtered.length >= 3) ...[
            const _SectionLabel('NEEDS ATTENTION'),
            const SizedBox(height: 6),
            const Text(
              'Cards with the lowest margins or highest revenue but thin profit '
              'are the best candidates for pricing review.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 12),

            // Low margin (< 20%)
            ..._lowMarginCards(filtered, currency),
          ],
        ],
      ),
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

  String _bulistInsight(
      List<TopPerformer> top, MapEntry<String, double>? topGame, NumberFormat currency) {
    if (top.isEmpty) return 'Not enough data yet.';
    final best     = top.first;
    final gameNote = topGame != null
        ? ' Your most profitable game overall is ${topGame.key} at ${currency.format(topGame.value)} in total profit.'
        : '';
    final marginNote = best.margin > 50
        ? 'at a ${best.margin.toStringAsFixed(0)}% margin — exceptional.'
        : 'at a ${best.margin.toStringAsFixed(0)}% margin.';
    return '${best.cardName} is your top earner at ${currency.format(best.profit)} profit '
        '$marginNote Prioritize buying more of this type at your next show or buylist.$gameNote';
  }

  List<Widget> _lowMarginCards(List<TopPerformer> all, NumberFormat currency) {
    final low = all.where((p) => p.margin < 20 && p.revenue > 10).toList()
      ..sort((a, b) => a.margin.compareTo(b.margin));
    if (low.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:        AppColors.success.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.cardName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text('${p.game} · ${p.unitsSold} sold',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${p.margin.toStringAsFixed(0)}% margin',
                  style: const TextStyle(
                      color: AppColors.warning, fontWeight: FontWeight.w700, fontSize: 13)),
              Text(currency.format(p.profit),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
        ]),
      ),
    )).toList();
  }
}

// ── Game profit bar chart ─────────────────────────────────────────────────────

class _GamePieBar extends StatelessWidget {
  final Map<String, double> gameRevenue;
  final NumberFormat currency;
  const _GamePieBar({required this.gameRevenue, required this.currency});

  static const _gameColors = [
    AppColors.accent,
    Color(0xFF7B61FF),
    AppColors.info,
    Color(0xFFFF6B35),
    AppColors.success,
    AppColors.warning,
  ];

  @override
  Widget build(BuildContext context) {
    final sorted = gameRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold(0.0, (s, e) => s + e.value);

    return Column(
      children: sorted.asMap().entries.map((entry) {
        final i     = entry.key;
        final game  = entry.value;
        final pct   = total > 0 ? game.value / total : 0.0;
        final color = _gameColors[i % _gameColors.length];

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            SizedBox(
              width: 100,
              child: Text(game.key,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value:           pct,
                  minHeight:       10,
                  backgroundColor: AppColors.darkSurfaceElevated,
                  valueColor:      AlwaysStoppedAnimation(color),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 56,
              child: Text(currency.format(game.value),
                  textAlign: TextAlign.right,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ]),
        );
      }).toList(),
    );
  }
}

// ── Margin distribution ───────────────────────────────────────────────────────

class _MarginDistribution extends StatelessWidget {
  final List<TopPerformer> performers;
  final NumberFormat currency;
  const _MarginDistribution({required this.performers, required this.currency});

  @override
  Widget build(BuildContext context) {
    final buckets = {
      '> 50%':    performers.where((p) => p.margin > 50).length,
      '20–50%':   performers.where((p) => p.margin >= 20 && p.margin <= 50).length,
      '< 20%':    performers.where((p) => p.margin < 20).length,
    };
    final colors = {
      '> 50%':  AppColors.success,
      '20–50%': AppColors.accent,
      '< 20%':  AppColors.warning,
    };
    final total = performers.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        AppColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: buckets.entries.map((e) {
          final pct   = total > 0 ? e.value / total : 0.0;
          final color = colors[e.key]!;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              SizedBox(width: 52, child: Text(e.key,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12))),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value:           pct,
                    minHeight:       8,
                    backgroundColor: AppColors.darkSurfaceElevated,
                    valueColor:      AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${e.value} cards',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ── Performer row ─────────────────────────────────────────────────────────────

class _PerformerRow extends StatelessWidget {
  final int rank;
  final TopPerformer perf;
  final String sortBy;
  final NumberFormat currency;
  const _PerformerRow({
    required this.rank,
    required this.perf,
    required this.sortBy,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final isTop3     = rank <= 3;
    final rankColor  = rank == 1 ? const Color(0xFFFFD700)
                     : rank == 2 ? const Color(0xFFC0C0C0)
                     : rank == 3 ? const Color(0xFFCD7F32)
                     : AppColors.textSecondary;

    final secondaryValue = switch (sortBy) {
      'margin'  => '${perf.margin.toStringAsFixed(0)}% margin',
      'revenue' => '${currency.format(perf.revenue)} rev',
      'units'   => '${perf.unitsSold} sold',
      _         => '${perf.margin.toStringAsFixed(0)}% margin',
    };

    final primaryValue = switch (sortBy) {
      'margin'  => '${perf.margin.toStringAsFixed(0)}%',
      'revenue' => currency.format(perf.revenue),
      'units'   => '${perf.unitsSold} units',
      _         => currency.format(perf.profit),
    };

    final primaryColor = switch (sortBy) {
      'margin'  => perf.margin >= 20 ? AppColors.success : AppColors.warning,
      'revenue' => AppColors.accent,
      'units'   => AppColors.info,
      _         => perf.profit >= 0 ? AppColors.success : AppColors.danger,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          // Rank badge
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isTop3
                  ? rankColor.withOpacity(0.15)
                  : AppColors.darkSurfaceElevated,
            ),
            child: Center(child: Text('$rank',
                style: TextStyle(
                  color:      isTop3 ? rankColor : AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize:   13,
                ))),
          ),
          const SizedBox(width: 12),

          // Card info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(perf.cardName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text('${perf.game} · ${perf.unitsSold} sold',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),

          // Primary metric + secondary
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(primaryValue,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize:   15,
                    color:      primaryColor,
                  )),
              Text(secondaryValue,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
        ]),
      ),
    );
  }
}

// ── Insight card ──────────────────────────────────────────────────────────────

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _InsightCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color:        color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(10),
      border:       Border.all(color: color.withOpacity(0.25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(title, style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
        const SizedBox(height: 6),
        Text(body, style: const TextStyle(
            color: AppColors.textSecondary, fontSize: 12, height: 1.5)),
      ],
    ),
  );
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
        color: AppColors.darkSurface, borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(
          color: color, fontWeight: FontWeight.w800, fontSize: 14),
          maxLines: 1, overflow: TextOverflow.ellipsis),
    ]),
  );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
          color: AppColors.textSecondary, letterSpacing: 1.2));
}
