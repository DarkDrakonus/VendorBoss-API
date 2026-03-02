import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../../theme/app_theme.dart';
import '../../services/mock_data_service.dart';

const _bulkColor = Color(0xFF7B61FF);

class BulkEffectivenessReport extends StatelessWidget {
  const BulkEffectivenessReport({super.key});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$');

    // Sort shows chronologically for the trend chart
    final roiData = List.from(MockDataService.showROIData)
      ..sort((a, b) => a.show.date.compareTo(b.show.date));

    final allSales  = MockDataService.allSalesHistory;
    final allBulk   = allSales.where((s) => s.isBulkSale).toList();
    final allSingle = allSales.where((s) => !s.isBulkSale).toList();

    final totalBulkRev   = allBulk.fold(0.0, (s, sale) => s + sale.totalAmount);
    final totalSingleRev = allSingle.fold(0.0, (s, sale) => s + sale.totalAmount);
    final totalRev       = totalBulkRev + totalSingleRev;
    final bulkPct        = totalRev > 0 ? (totalBulkRev / totalRev) * 100 : 0.0;
    final avgBulkTxValue = allBulk.isNotEmpty ? totalBulkRev / allBulk.length : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Bulk Effectiveness')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [

          // ── Overall summary stats ─────────────────────────────────────
          Row(children: [
            Expanded(child: _StatCard('Bulk Txns',       '${allBulk.length}',                      _bulkColor)),
            const SizedBox(width: 8),
            Expanded(child: _StatCard('Bulk Revenue',    currency.format(totalBulkRev),             _bulkColor)),
            const SizedBox(width: 8),
            Expanded(child: _StatCard('Bulk % of Rev',   '${bulkPct.toStringAsFixed(1)}%',          _bulkColor)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _StatCard('Avg Bulk Sale',   currency.format(avgBulkTxValue),           AppColors.textSecondary)),
            const SizedBox(width: 8),
            Expanded(child: _StatCard('Singles Revenue', currency.format(totalSingleRev),           AppColors.accent)),
            const SizedBox(width: 8),
            Expanded(child: _StatCard('Total Revenue',   currency.format(totalRev),                 AppColors.textSecondary)),
          ]),

          const SizedBox(height: 24),

          // ── Bulk % trend line — the key question ──────────────────────
          const _SectionLabel('BULK % TREND — SHOW OVER SHOW'),
          const SizedBox(height: 4),
          const Text(
            'Is your reliance on bulk increasing or decreasing over time?',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          _BulkTrendChart(roiData: roiData),

          const SizedBox(height: 24),

          // ── Revenue split (this is a composition view — split bar is correct here) ──
          const _SectionLabel('OVERALL REVENUE MIX'),
          const SizedBox(height: 12),
          _RevenueSplitCard(
            bulkRev:    totalBulkRev,
            singleRev:  totalSingleRev,
            bulkPct:    bulkPct,
            currency:   currency,
            insight:    _overallInsight(bulkPct, allBulk.length, avgBulkTxValue, currency),
          ),

          const SizedBox(height: 24),

          // ── Per-show breakdown ────────────────────────────────────────
          const _SectionLabel('BY SHOW'),
          const SizedBox(height: 12),
          ...roiData.map((d) => _ShowBulkCard(roi: d, currency: currency)),

          const SizedBox(height: 20),

          // ── Strategy callout ──────────────────────────────────────────
          _StrategyCard(roiData: roiData, currency: currency),

          const SizedBox(height: 16),

          // ── Reading guide ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:        AppColors.darkSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How to read Bulk %',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                SizedBox(height: 8),
                _GuideLine('< 10%',  'Minor supplement — primarily a singles business'),
                _GuideLine('10–25%', 'Healthy mix — bulk moving without dominating floor space'),
                _GuideLine('25–40%', 'Bulk-heavy — evaluate whether table space is worth it'),
                _GuideLine('> 40%',  'Bulk-dominant — may signal difficulty moving singles'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _overallInsight(
      double bulkPct, int txCount, double avgValue, NumberFormat currency) {
    if (txCount == 0) return 'No bulk sales recorded yet.';
    final avg = currency.format(avgValue);
    if (bulkPct < 10) {
      return 'Bulk is ${bulkPct.toStringAsFixed(1)}% of revenue across $txCount transactions '
          '(avg $avg each). Your business is primarily singles-driven — bulk is just a supplement.';
    } else if (bulkPct < 25) {
      return 'Bulk is ${bulkPct.toStringAsFixed(1)}% of revenue across $txCount transactions '
          '(avg $avg each). Healthy balance — bulk is moving without overshadowing higher-margin singles.';
    } else {
      return 'Bulk is ${bulkPct.toStringAsFixed(1)}% of revenue across $txCount transactions '
          '(avg $avg each). Consider whether the table space and setup time bulk requires '
          'is justified vs focusing on higher-margin singles.';
    }
  }
}

// ── Bulk % trend line chart ───────────────────────────────────────────────────

class _BulkTrendChart extends StatelessWidget {
  final List roiData;
  const _BulkTrendChart({required this.roiData});

  @override
  Widget build(BuildContext context) {
    final showsWithBulk = roiData.where((d) => d.transactionCount > 0).toList();

    if (showsWithBulk.length < 2) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color:        AppColors.darkSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Attend at least 2 shows to see trend data.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        color:        AppColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _Legend('Bulk %', _bulkColor),
            const SizedBox(width: 16),
            _Legend('Singles %', AppColors.accent),
          ]),
          const SizedBox(height: 12),

          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: _BulkTrendPainter(shows: showsWithBulk),
              child: const SizedBox.expand(),
            ),
          ),

          const SizedBox(height: 8),

          // X labels
          Row(
            children: showsWithBulk.map<Widget>((d) {
              final name = d.show.name.length > 10
                  ? '${d.show.name.substring(0, 9)}…'
                  : d.show.name;
              return Expanded(
                child: Text(name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 9)),
              );
            }).toList(),
          ),

          const SizedBox(height: 8),

          // Values
          Row(
            children: showsWithBulk.map<Widget>((d) {
              return Expanded(
                child: Text(
                  '${d.bulkPct.toStringAsFixed(0)}%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color:      _bulkColor,
                      fontSize:   11,
                      fontWeight: FontWeight.w700),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _BulkTrendPainter extends CustomPainter {
  final List shows;
  const _BulkTrendPainter({required this.shows});

  @override
  void paint(Canvas canvas, Size size) {
    if (shows.length < 2) return;

    final bulkPcts   = shows.map<double>((d) => d.bulkPct).toList();
    final singlePcts = bulkPcts.map((p) => 100 - p).toList();
    const minVal = 0.0;
    const maxVal = 100.0;

    _drawLine(canvas, size, bulkPcts,   minVal, maxVal, _bulkColor,        2.0);
    _drawLine(canvas, size, singlePcts, minVal, maxVal, AppColors.accent,   1.5, opacity: 0.6);

    // 25% threshold line (healthy upper bound for bulk)
    final thresholdY = size.height - (25.0 / maxVal) * size.height * 0.9 - 4;
    _drawDashed(canvas, Offset(0, thresholdY), Offset(size.width, thresholdY),
        _bulkColor.withOpacity(0.35), 4, 3);
  }

  void _drawLine(Canvas canvas, Size size, List<double> values,
      double minVal, double maxVal, Color color, double strokeWidth,
      {double opacity = 1.0}) {
    final range = (maxVal - minVal).clamp(1.0, double.infinity);
    final step  = size.width / (values.length - 1);
    final pts   = <Offset>[];

    for (int i = 0; i < values.length; i++) {
      pts.add(Offset(
        i * step,
        size.height - ((values[i] - minVal) / range) * size.height * 0.9 - 4,
      ));
    }

    // Fill
    final fill = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final cp1 = Offset((pts[i - 1].dx + pts[i].dx) / 2, pts[i - 1].dy);
      final cp2 = Offset((pts[i - 1].dx + pts[i].dx) / 2, pts[i].dy);
      fill.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i].dx, pts[i].dy);
    }
    fill
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();

    canvas.drawPath(fill, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end:   Alignment.bottomCenter,
        colors: [color.withOpacity(0.15 * opacity), color.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill);

    // Line
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final cp1 = Offset((pts[i - 1].dx + pts[i].dx) / 2, pts[i - 1].dy);
      final cp2 = Offset((pts[i - 1].dx + pts[i].dx) / 2, pts[i].dy);
      line.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(line, Paint()
      ..color       = color.withOpacity(opacity)
      ..strokeWidth = strokeWidth
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round
      ..strokeJoin  = StrokeJoin.round);

    // Dots
    for (final pt in pts) {
      canvas.drawCircle(pt, 3.5, Paint()..color = color.withOpacity(opacity));
      canvas.drawCircle(pt, 3.5, Paint()
        ..color       = AppColors.darkSurface
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1.5);
    }
  }

  void _drawDashed(Canvas canvas, Offset start, Offset end,
      Color color, double dashLen, double gapLen) {
    final paint  = Paint()..color = color..strokeWidth = 1..strokeCap = StrokeCap.round;
    final total  = (end - start).distance;
    final dir    = (end - start) / total;
    var   drawn  = 0.0;
    var   onDash = true;
    while (drawn < total) {
      final seg  = onDash ? dashLen : gapLen;
      final from = start + dir * drawn;
      final to   = start + dir * math.min(drawn + seg, total);
      if (onDash) canvas.drawLine(from, to, paint);
      drawn  += seg;
      onDash  = !onDash;
    }
  }

  @override
  bool shouldRepaint(covariant _BulkTrendPainter old) => old.shows != shows;
}

// ── Revenue split card ────────────────────────────────────────────────────────

class _RevenueSplitCard extends StatelessWidget {
  final double bulkRev, singleRev, bulkPct;
  final NumberFormat currency;
  final String insight;

  const _RevenueSplitCard({
    required this.bulkRev,
    required this.singleRev,
    required this.bulkPct,
    required this.currency,
    required this.insight,
  });

  @override
  Widget build(BuildContext context) {
    final total    = bulkRev + singleRev;
    final bulkFrac = total > 0 ? bulkRev / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        AppColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

          // Labels
          Row(children: [
            _Legend('Singles  ${currency.format(singleRev)}', AppColors.accent),
            const Spacer(),
            _Legend('Bulk  ${currency.format(bulkRev)}', _bulkColor),
          ]),

          const SizedBox(height: 12),
          Text(insight, style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 12, height: 1.5)),
        ],
      ),
    );
  }
}

// ── Per-show card ─────────────────────────────────────────────────────────────

class _ShowBulkCard extends StatelessWidget {
  final dynamic roi;
  final NumberFormat currency;
  const _ShowBulkCard({required this.roi, required this.currency});

  @override
  Widget build(BuildContext context) {
    final hasBulk = roi.bulkSaleCount > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(roi.show.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
              if (roi.show.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color:        AppColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('ACTIVE',
                      style: TextStyle(color: AppColors.accent, fontSize: 9,
                          fontWeight: FontWeight.w800)),
                ),
            ]),
            const SizedBox(height: 2),
            Text(roi.show.location ?? '',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),

            const SizedBox(height: 12),

            if (!hasBulk)
              const Text('No bulk sales at this show.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13))
            else ...[
              Row(children: [
                _Mini('${roi.bulkSaleCount}',            'Bulk Sales',   _bulkColor),
                const SizedBox(width: 20),
                _Mini(currency.format(roi.bulkRevenue),  'Bulk Rev',     _bulkColor),
                const SizedBox(width: 20),
                _Mini('${roi.bulkPct.toStringAsFixed(0)}%', 'of Revenue', _bulkColor),
                const SizedBox(width: 20),
                _Mini(currency.format(roi.grossRevenue), 'Total Rev',    AppColors.textSecondary),
              ]),
              const SizedBox(height: 10),
              // Compact split bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 8,
                  child: Row(children: [
                    Flexible(
                      flex: (roi.singleRevenue * 10).toInt().clamp(1, 9999),
                      child: Container(color: AppColors.accent),
                    ),
                    Flexible(
                      flex: (roi.bulkRevenue * 10).toInt().clamp(1, 9999),
                      child: Container(color: _bulkColor),
                    ),
                  ]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Strategy callout ──────────────────────────────────────────────────────────

class _StrategyCard extends StatelessWidget {
  final List roiData;
  final NumberFormat currency;
  const _StrategyCard({required this.roiData, required this.currency});

  @override
  Widget build(BuildContext context) {
    final withBulk = roiData.where((d) => d.bulkSaleCount > 0).toList();
    final body     = withBulk.isEmpty
        ? 'Not enough data yet to generate bulk strategy insights.'
        : _insight(withBulk);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        _bulkColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: _bulkColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.lightbulb_outline, color: _bulkColor, size: 16),
            SizedBox(width: 8),
            Text('Bulk Strategy Insight',
                style: TextStyle(color: _bulkColor, fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 12, height: 1.5)),
        ],
      ),
    );
  }

  String _insight(List withBulk) {
    final best  = withBulk.reduce((a, b) => a.bulkRevenue > b.bulkRevenue ? a : b);
    final worst = withBulk.reduce((a, b) => a.bulkPct > b.bulkPct ? a : b);
    return '${best.show.name} generated the most bulk revenue at '
        '${currency.format(best.bulkRevenue)} across ${best.bulkSaleCount} transactions. '
        '${worst.show.name} had the highest bulk reliance at '
        '${worst.bulkPct.toStringAsFixed(0)}% of revenue — '
        'worth evaluating whether that show\'s audience skews toward bulk buyers.';
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
        color: AppColors.darkSurface, borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14),
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

class _Legend extends StatelessWidget {
  final String label;
  final Color color;
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
  final String value, label;
  final Color color;
  const _Mini(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14)),
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
    ],
  );
}

class _GuideLine extends StatelessWidget {
  final String range, meaning;
  const _GuideLine(this.range, this.meaning);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 52,
          child: Text(range, style: const TextStyle(
              color: _bulkColor, fontWeight: FontWeight.w700, fontSize: 12))),
      const SizedBox(width: 8),
      Expanded(child: Text(meaning,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
    ]),
  );
}
