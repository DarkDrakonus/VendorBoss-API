import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';
import '../services/mock_data_service.dart';
import '../models/show.dart';
import 'reports/show_roi_report.dart';
import 'reports/channel_performance_report.dart';
import 'reports/top_performers_report.dart';
import 'reports/inventory_health_report.dart';
import 'reports/financial_summary_report.dart';
import 'reports/bulk_effectiveness_report.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final allSales = MockDataService.allSalesHistory;
    final health   = MockDataService.inventoryHealth;
    final roiData  = MockDataService.showROIData;
    final fin      = MockDataService.ytdFinancialSummary;

    // ── YTD hero numbers ──────────────────────────────────────────────────
    final ytdRev     = fin.grossRevenue;
    final ytdNet     = fin.netProfit;
    final profitable = roiData.where((d) => d.isProfitable).length;
    final aged       = health.where((h) => h.isAged).length;

    // ── Monthly revenue for sparkline (last 6 months) ─────────────────────
    final monthlyRev = _buildMonthlyRevenue(allSales, 6);

    // ── Channel share for donut preview ───────────────────────────────────
    final channels    = MockDataService.channelPerformance;
    final totalChRev  = channels.fold(0.0, (s, c) => s + c.revenue);
    final inPersonPct = totalChRev > 0
        ? (channels
                .where((c) => c.channel == 'in_person')
                .fold(0.0, (s, c) => s + c.revenue) /
            totalChRev)
        : 0.5;

    // ── Bulk % preview ────────────────────────────────────────────────────
    final bulkSales  = allSales.where((s) => s.isBulkSale).toList();
    final bulkRev    = bulkSales.fold(0.0, (s, sale) => s + sale.totalAmount);
    final bulkPct    = ytdRev > 0 ? bulkRev / ytdRev : 0.0;

    // ── Inventory capital by age bucket ───────────────────────────────────
    final capFresh  = health.where((h) => h.daysHeld < 30).fold(0.0, (s, h) => s + h.capitalTied);
    final capMod    = health.where((h) => h.daysHeld >= 30 && h.daysHeld < 60).fold(0.0, (s, h) => s + h.capitalTied);
    final capAged   = health.where((h) => h.daysHeld >= 60 && h.daysHeld < 90).fold(0.0, (s, h) => s + h.capitalTied);
    final capStale  = health.where((h) => h.daysHeld >= 90).fold(0.0, (s, h) => s + h.capitalTied);
    final capTotal  = capFresh + capMod + capAged + capStale;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            tooltip: 'Date range',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Date range filter — coming soon')),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [

          // ── YTD Hero strip ──────────────────────────────────────────────
          _HeroStrip(
            revenue:    currency.format(ytdRev),
            netProfit:  currency.format(ytdNet),
            netColor:   ytdNet >= 0 ? AppColors.success : AppColors.danger,
            profitable: '$profitable/${roiData.length} shows',
          ),

          const SizedBox(height: 20),

          // ── Module: Sales & Channel Performance ─────────────────────────
          _ReportModule(
            icon:        Icons.bar_chart_rounded,
            title:       'Sales & Channel Performance',
            accentColor: AppColors.accent,
            primaryStat: currency.format(ytdRev),
            primaryLabel: 'YTD Revenue',
            secondaryStat: '${(inPersonPct * 100).toStringAsFixed(0)}% in-person',
            preview: _SparklinePreview(
              points:      monthlyRev,
              color:       AppColors.accent,
              labelLeft:   _monthLabel(5),
              labelRight:  'Now',
            ),
            quickLinks: [
              _QuickLink('Show ROI',       Icons.storefront_outlined,   () => _push(context, const ShowROIReport())),
              _QuickLink('By Channel',     Icons.swap_horiz_outlined,   () => _push(context, const ChannelPerformanceReport())),
              _QuickLink('Top Performers', Icons.emoji_events_outlined,  () => _push(context, const TopPerformersReport())),
            ],
          ),

          const SizedBox(height: 14),

          // ── Module: Inventory & Stock Health ────────────────────────────
          _ReportModule(
            icon:        Icons.warehouse_outlined,
            title:       'Inventory & Stock Health',
            accentColor: AppColors.info,
            primaryStat: currency.format(capTotal),
            primaryLabel: 'Capital Tied Up',
            secondaryStat: aged > 0 ? '$aged cards aged 60+ days' : 'No aged stock',
            secondaryColor: aged > 0 ? AppColors.warning : AppColors.success,
            preview: _DonutPreview(
              segments: [
                _DonutSegment(capFresh,  AppColors.success),
                _DonutSegment(capMod,    AppColors.accent),
                _DonutSegment(capAged,   AppColors.warning),
                _DonutSegment(capStale,  AppColors.danger),
              ],
              total:      capTotal,
              centerLabel: aged > 0 ? '$aged aged' : 'Healthy',
              centerColor: aged > 0 ? AppColors.warning : AppColors.success,
            ),
            quickLinks: [
              _QuickLink('Stock Health',  Icons.health_and_safety_outlined, () => _push(context, const InventoryHealthReport())),
              _QuickLink('Price Drift',   Icons.price_change_outlined,      () => _push(context, const InventoryHealthReport(startTab: 1))),
            ],
          ),

          const SizedBox(height: 14),

          // ── Module: Financial & Tax ──────────────────────────────────────
          _ReportModule(
            icon:        Icons.receipt_long_outlined,
            title:       'Financial & Tax',
            accentColor: AppColors.success,
            primaryStat: currency.format(ytdNet),
            primaryLabel: 'YTD Net Profit',
            primaryColor: ytdNet >= 0 ? AppColors.success : AppColors.danger,
            secondaryStat: ytdRev >= 600
                ? 'Above \$600 IRS threshold'
                : '\$${(600 - ytdRev).toStringAsFixed(0)} below \$600 threshold',
            secondaryColor: ytdRev >= 600 ? AppColors.warning : AppColors.textSecondary,
            preview: _WaterfallPreview(
              revenue:  fin.grossRevenue,
              cogs:     fin.cogs,
              expenses: fin.totalExpenses,
              net:      fin.netProfit,
            ),
            quickLinks: [
              _QuickLink('YTD Summary',  Icons.account_balance_outlined,   () => _push(context, const FinancialSummaryReport())),
              _QuickLink('Schedule C',   Icons.description_outlined,       () => _push(context, const FinancialSummaryReport(startTab: 1))),
              _QuickLink('Expenses',     Icons.category_outlined,          () => _push(context, const FinancialSummaryReport(startTab: 2))),
            ],
          ),

          const SizedBox(height: 14),

          // ── Module: Bulk Effectiveness ───────────────────────────────────
          _ReportModule(
            icon:        Icons.layers_outlined,
            title:       'Bulk Effectiveness',
            accentColor: const Color(0xFF7B61FF),
            primaryStat: '${(bulkPct * 100).toStringAsFixed(1)}%',
            primaryLabel: 'Bulk % of Revenue',
            secondaryStat: '${bulkSales.length} bulk transactions',
            preview: _SplitBarPreview(
              leftFraction: 1 - bulkPct,
              leftLabel:    'Singles',
              leftColor:    AppColors.accent,
              rightLabel:   'Bulk',
              rightColor:   const Color(0xFF7B61FF),
            ),
            quickLinks: [
              _QuickLink('Bulk Report', Icons.bar_chart_outlined, () => _push(context, const BulkEffectivenessReport())),
            ],
          ),

          const SizedBox(height: 24),

          // ── Coming soon section ──────────────────────────────────────────
          const _ComingSoonSection(),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _push(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  /// Builds a list of monthly revenue totals for the last [months] months.
  static List<double> _buildMonthlyRevenue(List<Sale> sales, int months) {
    final now    = DateTime.now();
    final result = List<double>.filled(months, 0);
    for (final s in sales) {
      final diff = (now.year - s.saleDate.year) * 12 +
          now.month - s.saleDate.month;
      if (diff >= 0 && diff < months) {
        result[months - 1 - diff] += s.totalAmount;
      }
    }
    return result;
  }

  static String _monthLabel(int monthsAgo) {
    final dt = DateTime.now()
        .subtract(Duration(days: 30 * monthsAgo));
    return DateFormat('MMM').format(dt);
  }
}

// ── YTD Hero strip ────────────────────────────────────────────────────────────

class _HeroStrip extends StatelessWidget {
  final String revenue;
  final String netProfit;
  final Color netColor;
  final String profitable;

  const _HeroStrip({
    required this.revenue,
    required this.netProfit,
    required this.netColor,
    required this.profitable,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withOpacity(0.12),
            AppColors.accent.withOpacity(0.04),
          ],
          begin: Alignment.centerLeft,
          end:   Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
      ),
      child: Row(children: [
        Expanded(child: _HeroStat('YTD Revenue',   revenue,    AppColors.accent)),
        _VertDivider(),
        Expanded(child: _HeroStat('Net Profit',    netProfit,  netColor)),
        _VertDivider(),
        Expanded(child: _HeroStat('Shows',         profitable, AppColors.textSecondary)),
      ]),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _HeroStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16),
          textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
          textAlign: TextAlign.center),
    ],
  );
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 32,
    color: AppColors.darkDivider,
    margin: const EdgeInsets.symmetric(horizontal: 8),
  );
}

// ── Report Module card ────────────────────────────────────────────────────────

class _ReportModule extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accentColor;
  final String primaryStat;
  final String primaryLabel;
  final Color? primaryColor;
  final String secondaryStat;
  final Color? secondaryColor;
  final Widget preview;
  final List<_QuickLink> quickLinks;

  const _ReportModule({
    required this.icon,
    required this.title,
    required this.accentColor,
    required this.primaryStat,
    required this.primaryLabel,
    this.primaryColor,
    required this.secondaryStat,
    this.secondaryColor,
    required this.preview,
    required this.quickLinks,
  });

  @override
  Widget build(BuildContext context) {
    final pColor = primaryColor ?? accentColor;
    final sColor = secondaryColor ?? AppColors.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color:        AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Module header ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon badge
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:        accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accentColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize:   15,
                          )),
                      const SizedBox(height: 1),
                      Text(secondaryStat,
                          style: TextStyle(
                            color:    sColor,
                            fontSize: 12,
                          )),
                    ],
                  ),
                ),
                // Primary stat
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(primaryStat,
                        style: TextStyle(
                          color:      pColor,
                          fontWeight: FontWeight.w800,
                          fontSize:   18,
                        )),
                    Text(primaryLabel,
                        style: const TextStyle(
                          color:    AppColors.textSecondary,
                          fontSize: 10,
                        )),
                  ],
                ),
              ],
            ),
          ),

          // ── Mini preview chart ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: SizedBox(height: 72, child: preview),
          ),

          // ── Quick-link chips ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              children: quickLinks.map((ql) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _QuickLinkChip(link: ql, color: accentColor),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick link ────────────────────────────────────────────────────────────────

class _QuickLink {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _QuickLink(this.label, this.icon, this.onTap);
}

class _QuickLinkChip extends StatelessWidget {
  final _QuickLink link;
  final Color color;
  const _QuickLinkChip({required this.link, required this.color});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: link.onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color:        AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(link.icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(link.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color:      color,
                fontSize:   10,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    ),
  );
}

// ── Preview: Sparkline (line chart) ──────────────────────────────────────────

class _SparklinePreview extends StatelessWidget {
  final List<double> points;
  final Color color;
  final String labelLeft;
  final String labelRight;

  const _SparklinePreview({
    required this.points,
    required this.color,
    required this.labelLeft,
    required this.labelRight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: CustomPaint(
            painter: _SparklinePainter(points: points, color: color),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 4),
        Row(children: [
          Text(labelLeft,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 9)),
          const Spacer(),
          Text(labelRight,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 9)),
        ]),
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> points;
  final Color color;
  const _SparklinePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final maxVal = points.reduce(math.max);
    final minVal = points.reduce(math.min);
    final range  = (maxVal - minVal).clamp(1.0, double.infinity);

    // Draw subtle fill
    final fillPath = Path();
    final step     = size.width / (points.length - 1);

    for (int i = 0; i < points.length; i++) {
      final x = i * step;
      final y = size.height - ((points[i] - minVal) / range) * size.height * 0.85 - 4;
      if (i == 0) {
        fillPath.moveTo(x, y);
      } else {
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end:   Alignment.bottomCenter,
          colors: [color.withOpacity(0.18), color.withOpacity(0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill,
    );

    // Draw line
    final linePath = Path();
    for (int i = 0; i < points.length; i++) {
      final x = i * step;
      final y = size.height - ((points[i] - minVal) / range) * size.height * 0.85 - 4;
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }

    canvas.drawPath(
      linePath,
      Paint()
        ..color       = color
        ..strokeWidth = 2.0
        ..style       = PaintingStyle.stroke
        ..strokeCap   = StrokeCap.round
        ..strokeJoin  = StrokeJoin.round,
    );

    // Dot on last point
    final lastX = (points.length - 1) * step;
    final lastY = size.height -
        ((points.last - minVal) / range) * size.height * 0.85 - 4;
    canvas.drawCircle(Offset(lastX, lastY), 3.5, Paint()..color = color);
    canvas.drawCircle(
        Offset(lastX, lastY), 3.5,
        Paint()
          ..color       = Colors.black
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.points != points || old.color != color;
}

// ── Preview: Donut ring ───────────────────────────────────────────────────────

class _DonutSegment {
  final double value;
  final Color color;
  const _DonutSegment(this.value, this.color);
}

class _DonutPreview extends StatelessWidget {
  final List<_DonutSegment> segments;
  final double total;
  final String centerLabel;
  final Color centerColor;

  const _DonutPreview({
    required this.segments,
    required this.total,
    required this.centerLabel,
    required this.centerColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Donut
        SizedBox(
          width: 72, height: 72,
          child: CustomPaint(
            painter: _DonutPainter(
              segments: segments,
              total:    total,
            ),
            child: Center(
              child: Text(
                centerLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color:      centerColor,
                  fontSize:   10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Legend
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DonutLegend('< 30 days',  AppColors.success),
              _DonutLegend('30-60 days', AppColors.accent),
              _DonutLegend('60-90 days', AppColors.warning),
              _DonutLegend('90+ days',   AppColors.danger),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutLegend extends StatelessWidget {
  final String label;
  final Color color;
  const _DonutLegend(this.label, this.color);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(children: [
      Container(
        width: 8, height: 8,
        decoration: BoxDecoration(
          color:        color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(
          color: AppColors.textSecondary, fontSize: 10)),
    ]),
  );
}

class _DonutPainter extends CustomPainter {
  final List<_DonutSegment> segments;
  final double total;
  const _DonutPainter({required this.segments, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;

    final cx    = size.width / 2;
    final cy    = size.height / 2;
    final outer = math.min(cx, cy);
    final inner = outer * 0.58;

    final rect   = Rect.fromCircle(center: Offset(cx, cy), radius: outer);
    var   start  = -math.pi / 2; // 12 o'clock
    const gap    = 0.04;         // small gap between segments

    for (final seg in segments) {
      if (seg.value <= 0) continue;
      final sweep = (seg.value / total) * (2 * math.pi) - gap;
      canvas.drawArc(
        rect,
        start + gap / 2,
        sweep,
        false,
        Paint()
          ..color       = seg.color
          ..strokeWidth = outer - inner
          ..style       = PaintingStyle.stroke
          ..strokeCap   = StrokeCap.butt,
      );
      start += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.total != total;
}

// ── Preview: Waterfall (revenue → net) ───────────────────────────────────────

class _WaterfallPreview extends StatelessWidget {
  final double revenue, cogs, expenses, net;
  const _WaterfallPreview({
    required this.revenue,
    required this.cogs,
    required this.expenses,
    required this.net,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final bars = [
      _WBar('Revenue',  revenue,              AppColors.accent),
      _WBar('COGS',     -(cogs),              AppColors.danger),
      _WBar('Expenses', -(expenses),          AppColors.warning),
      _WBar('Net',      net,                  net >= 0 ? AppColors.success : AppColors.danger),
    ];
    final maxAbs = bars.map((b) => b.value.abs()).reduce(math.max).clamp(1.0, double.infinity);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: bars.map((b) {
        final frac  = b.value.abs() / maxAbs;
        final isPos = b.value >= 0;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  b.value >= 0
                      ? currency.format(b.value)
                      : '-${currency.format(b.value.abs())}',
                  style: TextStyle(
                    color:    b.color,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Container(
                    height: 36 * frac,
                    color:  b.color.withOpacity(isPos ? 0.85 : 0.55),
                  ),
                ),
                const SizedBox(height: 2),
                Text(b.label,
                    style: const TextStyle(
                      color:    AppColors.textSecondary,
                      fontSize: 9,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _WBar {
  final String label;
  final double value;
  final Color color;
  const _WBar(this.label, this.value, this.color);
}

// ── Preview: Split bar ────────────────────────────────────────────────────────

class _SplitBarPreview extends StatelessWidget {
  final double leftFraction;
  final String leftLabel;
  final Color  leftColor;
  final String rightLabel;
  final Color  rightColor;

  const _SplitBarPreview({
    required this.leftFraction,
    required this.leftLabel,
    required this.leftColor,
    required this.rightLabel,
    required this.rightColor,
  });

  @override
  Widget build(BuildContext context) {
    final rightFraction = 1 - leftFraction;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Labels above bar
        Row(children: [
          Expanded(
            flex: (leftFraction * 100).toInt().clamp(1, 99),
            child: Text(
              '${(leftFraction * 100).toStringAsFixed(0)}%\n$leftLabel',
              textAlign: TextAlign.left,
              style: TextStyle(color: leftColor, fontSize: 11, fontWeight: FontWeight.w700, height: 1.3),
            ),
          ),
          Expanded(
            flex: (rightFraction * 100).toInt().clamp(1, 99),
            child: Text(
              '${(rightFraction * 100).toStringAsFixed(0)}%\n$rightLabel',
              textAlign: TextAlign.right,
              style: TextStyle(color: rightColor, fontSize: 11, fontWeight: FontWeight.w700, height: 1.3),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 18,
            child: Row(children: [
              Expanded(
                flex: (leftFraction * 1000).toInt().clamp(1, 999),
                child: Container(color: leftColor),
              ),
              Expanded(
                flex: (rightFraction * 1000).toInt().clamp(1, 999),
                child: Container(color: rightColor),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

// ── Coming Soon section ───────────────────────────────────────────────────────

class _ComingSoonSection extends StatelessWidget {
  const _ComingSoonSection();

  @override
  Widget build(BuildContext context) {
    const items = [
      _SoonItem('Trade Equity Report',     Icons.compare_arrows_outlined),
      _SoonItem('Store Credit Liability',  Icons.credit_card_outlined),
      _SoonItem('Acquisition Source',      Icons.source_outlined),
      _SoonItem('Inventory Aging Deep Dive', Icons.hourglass_bottom_outlined),
      _SoonItem('Cash Flow Forecast',      Icons.account_balance_wallet_outlined),
      _SoonItem('Graded vs Raw ROI',       Icons.grade_outlined),
    ];

    return Container(
      decoration: BoxDecoration(
        color:        AppColors.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: AppColors.darkDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              Icon(Icons.construction_outlined,
                  size: 14, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Text('COMING SOON',
                  style: TextStyle(
                    fontSize:      10,
                    fontWeight:    FontWeight.w800,
                    color:         AppColors.textSecondary,
                    letterSpacing: 1.2,
                  )),
            ]),
          ),
          const Divider(height: 1),
          Wrap(
            children: items.map((item) => _SoonChip(item: item)).toList(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SoonItem {
  final String label;
  final IconData icon;
  const _SoonItem(this.label, this.icon);
}

class _SoonChip extends StatelessWidget {
  final _SoonItem item;
  const _SoonChip({required this.item});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 0, 0),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color:        AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(item.icon, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 5),
        Text(item.label,
            style: const TextStyle(
              color:    AppColors.textSecondary,
              fontSize: 11,
            )),
      ]),
    ),
  );
}
