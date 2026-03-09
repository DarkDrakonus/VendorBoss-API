import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'reports/show_roi_report.dart';
import 'reports/channel_performance_report.dart';
import 'reports/top_performers_report.dart';
import 'reports/inventory_health_report.dart';
import 'reports/financial_summary_report.dart';
import 'reports/bulk_effectiveness_report.dart';

// ── Helper ────────────────────────────────────────────────────────────────────

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

// ── Hub screen ────────────────────────────────────────────────────────────────

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  Map<String, dynamic>? _fin;
  Map<String, dynamic>? _roi;
  Map<String, dynamic>? _health;
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
      final results = await Future.wait([
        ApiService.instance.getFinancialSummary(),
        ApiService.instance.getShowROI(),
        ApiService.instance.getInventoryHealth(),
      ]);
      if (!mounted) return;
      setState(() {
        _fin    = results[0] as Map<String, dynamic>;
        _roi    = results[1] as Map<String, dynamic>;
        _health = results[2] as Map<String, dynamic>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    // Financial
    final ytdRev  = _d(_fin?['total_revenue']);
    final ytdNet  = _d(_fin?['net_profit']);
    final cogs    = _d(_fin?['total_cogs']);
    final exp     = _d(_fin?['total_expenses']);

    // Shows
    final shows      = (_roi?['shows'] as List<dynamic>?) ?? [];
    final profitable = shows.where((s) => _d(s['net_profit']) >= 0).length;

    // Inventory health
    final capTotal  = _d(_health?['total_value_cost']);
    final totalItems = _i(_health?['total_items']);
    final aged30    = _i(_health?['aged_30_plus']);
    final aged60    = _i(_health?['aged_60_plus']);
    final aged90    = _i(_health?['aged_90_plus']);
    final aged180   = _i(_health?['aged_180_plus']);
    final ageFresh  = (totalItems - aged30 - aged60 - aged90 - aged180).clamp(0, totalItems);
    final aged60Plus = aged60 + aged90 + aged180;

    // Monthly sparkline — last 6 months from financial summary
    final monthly   = (_fin?['monthly'] as List<dynamic>?) ?? [];
    final last6     = monthly.length >= 6 ? monthly.sublist(monthly.length - 6) : monthly;
    final sparkline = last6.map<double>((m) => _d(m['revenue'])).toList();
    if (sparkline.isEmpty) sparkline.addAll(List.filled(6, 0.0));
    final leftLabel = last6.isNotEmpty ? (last6.first['month'] as String? ?? '') : '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _error != null && _fin == null
          ? _ErrorView(error: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: [
                  _HeroStrip(
                    revenue:    currency.format(ytdRev),
                    netProfit:  currency.format(ytdNet),
                    netColor:   ytdNet >= 0 ? AppColors.success : AppColors.danger,
                    profitable: '$profitable/${shows.length} shows',
                  ),
                  const SizedBox(height: 20),

                  // Sales & Channel module
                  _ReportModule(
                    icon: Icons.bar_chart_rounded,
                    title: 'Sales & Channel Performance',
                    accentColor: AppColors.accent,
                    primaryStat: currency.format(ytdRev),
                    primaryLabel: 'YTD Revenue',
                    secondaryStat: last6.isNotEmpty
                        ? '${_i(_fin?['total_transactions'])} transactions'
                        : 'No sales data yet',
                    preview: _SparklinePreview(
                      points: sparkline,
                      color: AppColors.accent,
                      labelLeft: leftLabel,
                      labelRight: 'Now',
                    ),
                    quickLinks: [
                      _QuickLink('Show ROI', Icons.storefront_outlined,
                          () => _push(context, const ShowROIReport())),
                      _QuickLink('By Channel', Icons.swap_horiz_outlined,
                          () => _push(context, const ChannelPerformanceReport())),
                      _QuickLink('Top Performers', Icons.emoji_events_outlined,
                          () => _push(context, const TopPerformersReport())),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Inventory module
                  _ReportModule(
                    icon: Icons.warehouse_outlined,
                    title: 'Inventory & Stock Health',
                    accentColor: AppColors.info,
                    primaryStat: currency.format(capTotal),
                    primaryLabel: 'Capital Tied Up',
                    secondaryStat: aged60Plus > 0
                        ? '$aged60Plus cards aged 60+ days'
                        : 'No aged stock',
                    secondaryColor: aged60Plus > 0 ? AppColors.warning : AppColors.success,
                    preview: _DonutPreview(
                      segments: [
                        _DonutSegment(ageFresh.toDouble(), AppColors.success),
                        _DonutSegment(aged30.toDouble(),   AppColors.accent),
                        _DonutSegment(aged60.toDouble(),   AppColors.warning),
                        _DonutSegment((aged90 + aged180).toDouble(), AppColors.danger),
                      ],
                      total: totalItems.toDouble(),
                      centerLabel: aged60Plus > 0 ? '$aged60Plus aged' : 'Healthy',
                      centerColor: aged60Plus > 0 ? AppColors.warning : AppColors.success,
                    ),
                    quickLinks: [
                      _QuickLink('Stock Health', Icons.health_and_safety_outlined,
                          () => _push(context, const InventoryHealthReport())),
                      _QuickLink('Price Drift', Icons.price_change_outlined,
                          () => _push(context, const InventoryHealthReport(startTab: 1))),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Financial module
                  _ReportModule(
                    icon: Icons.receipt_long_outlined,
                    title: 'Financial & Tax',
                    accentColor: AppColors.success,
                    primaryStat: currency.format(ytdNet),
                    primaryLabel: 'YTD Net Profit',
                    primaryColor: ytdNet >= 0 ? AppColors.success : AppColors.danger,
                    secondaryStat: ytdRev >= 600
                        ? 'Above \$600 IRS threshold'
                        : '\$${(600 - ytdRev).toStringAsFixed(0)} below \$600 threshold',
                    secondaryColor: ytdRev >= 600 ? AppColors.warning : AppColors.textSecondary,
                    preview: _WaterfallPreview(
                      revenue: ytdRev, cogs: cogs, expenses: exp, net: ytdNet),
                    quickLinks: [
                      _QuickLink('YTD Summary', Icons.account_balance_outlined,
                          () => _push(context, const FinancialSummaryReport())),
                      _QuickLink('Schedule C', Icons.description_outlined,
                          () => _push(context, const FinancialSummaryReport(startTab: 1))),
                      _QuickLink('Expenses', Icons.category_outlined,
                          () => _push(context, const FinancialSummaryReport(startTab: 2))),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Show performance module
                  _ReportModule(
                    icon: Icons.layers_outlined,
                    title: 'Show Performance',
                    accentColor: const Color(0xFF7B61FF),
                    primaryStat: '${shows.length}',
                    primaryLabel: 'Total Shows',
                    secondaryStat: shows.isEmpty ? 'No shows yet'
                        : '$profitable profitable · ${shows.length - profitable} at loss',
                    secondaryColor: profitable == shows.length && shows.isNotEmpty
                        ? AppColors.success : AppColors.textSecondary,
                    preview: _ShowNetBarsPreview(shows: shows),
                    quickLinks: [
                      _QuickLink('Show ROI', Icons.bar_chart_outlined,
                          () => _push(context, const ShowROIReport())),
                      _QuickLink('Bulk Data', Icons.layers_outlined,
                          () => _push(context, const BulkEffectivenessReport())),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const _ComingSoonSection(),
                ],
              ),
            ),
    );
  }

  void _push(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.wifi_off, size: 48, color: AppColors.textSecondary),
        const SizedBox(height: 16),
        const Text('Could not load reports',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        Text(error, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
      ]),
    ),
  );
}

// ── YTD Hero strip ────────────────────────────────────────────────────────────

class _HeroStrip extends StatelessWidget {
  final String revenue, netProfit, profitable;
  final Color netColor;
  const _HeroStrip({required this.revenue, required this.netProfit,
      required this.netColor, required this.profitable});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [
        AppColors.accent.withOpacity(0.12),
        AppColors.accent.withOpacity(0.04),
      ], begin: Alignment.centerLeft, end: Alignment.centerRight),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.accent.withOpacity(0.2)),
    ),
    child: Row(children: [
      Expanded(child: _HeroStat('YTD Revenue',  revenue,    AppColors.accent)),
      _VertDivider(),
      Expanded(child: _HeroStat('Net Profit',   netProfit,  netColor)),
      _VertDivider(),
      Expanded(child: _HeroStat('Shows',        profitable, AppColors.textSecondary)),
    ]),
  );
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
      width: 1, height: 32, color: AppColors.darkDivider,
      margin: const EdgeInsets.symmetric(horizontal: 8));
}

// ── Report Module card ────────────────────────────────────────────────────────

class _ReportModule extends StatelessWidget {
  final IconData icon;
  final String title, primaryStat, primaryLabel, secondaryStat;
  final Color accentColor;
  final Color? primaryColor, secondaryColor;
  final Widget preview;
  final List<_QuickLink> quickLinks;

  const _ReportModule({
    required this.icon,
    required this.title,
    required this.accentColor,
    required this.primaryStat,
    required this.primaryLabel,
    required this.secondaryStat,
    this.primaryColor,
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
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.18)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: accentColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 1),
              Text(secondaryStat, style: TextStyle(color: sColor, fontSize: 12)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(primaryStat,
                  style: TextStyle(color: pColor, fontWeight: FontWeight.w800, fontSize: 18)),
              Text(primaryLabel,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: SizedBox(height: 72, child: preview),
        ),
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
      ]),
    );
  }
}

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
        color: AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(link.icon, color: color, size: 16),
        const SizedBox(height: 4),
        Text(link.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

// ── Preview: Sparkline ────────────────────────────────────────────────────────

class _SparklinePreview extends StatelessWidget {
  final List<double> points;
  final Color color;
  final String labelLeft, labelRight;

  const _SparklinePreview({required this.points, required this.color,
      required this.labelLeft, required this.labelRight});

  @override
  Widget build(BuildContext context) => Column(children: [
    Expanded(child: CustomPaint(
      painter: _SparklinePainter(points: points, color: color),
      child: const SizedBox.expand(),
    )),
    const SizedBox(height: 4),
    Row(children: [
      Text(labelLeft, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9)),
      const Spacer(),
      Text(labelRight, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9)),
    ]),
  ]);
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
    final step   = size.width / (points.length - 1);

    final fill = Path();
    for (int i = 0; i < points.length; i++) {
      final x = i * step;
      final y = size.height - ((points[i] - minVal) / range) * size.height * 0.85 - 4;
      i == 0 ? fill.moveTo(x, y) : fill.lineTo(x, y);
    }
    fill.lineTo(size.width, size.height);
    fill.lineTo(0, size.height);
    fill.close();

    canvas.drawPath(fill, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.18), color.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill);

    final line = Path();
    for (int i = 0; i < points.length; i++) {
      final x = i * step;
      final y = size.height - ((points[i] - minVal) / range) * size.height * 0.85 - 4;
      i == 0 ? line.moveTo(x, y) : line.lineTo(x, y);
    }
    canvas.drawPath(line, Paint()
      ..color = color ..strokeWidth = 2.0 ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round ..strokeJoin = StrokeJoin.round);

    final lastX = (points.length - 1) * step;
    final lastY = size.height -
        ((points.last - minVal) / range) * size.height * 0.85 - 4;
    canvas.drawCircle(Offset(lastX, lastY), 3.5, Paint()..color = color);
    canvas.drawCircle(Offset(lastX, lastY), 3.5, Paint()
      ..color = Colors.black ..style = PaintingStyle.stroke ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.points != points || old.color != color;
}

// ── Preview: Donut ────────────────────────────────────────────────────────────

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

  const _DonutPreview({required this.segments, required this.total,
      required this.centerLabel, required this.centerColor});

  @override
  Widget build(BuildContext context) => Row(children: [
    SizedBox(width: 72, height: 72,
      child: CustomPaint(
        painter: _DonutPainter(segments: segments, total: total),
        child: Center(child: Text(centerLabel,
            textAlign: TextAlign.center,
            style: TextStyle(color: centerColor, fontSize: 10, fontWeight: FontWeight.w700))),
      ),
    ),
    const SizedBox(width: 16),
    Expanded(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DonutLegend('< 30 days',  AppColors.success),
        _DonutLegend('30-60 days', AppColors.accent),
        _DonutLegend('60-90 days', AppColors.warning),
        _DonutLegend('90+ days',   AppColors.danger),
      ],
    )),
  ]);
}

class _DonutLegend extends StatelessWidget {
  final String label;
  final Color color;
  const _DonutLegend(this.label, this.color);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(children: [
      Container(width: 8, height: 8,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
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
    final cx = size.width / 2, cy = size.height / 2;
    final outer = math.min(cx, cy);
    final inner = outer * 0.58;
    final rect  = Rect.fromCircle(center: Offset(cx, cy), radius: outer);
    var   start = -math.pi / 2;
    const gap   = 0.04;

    for (final seg in segments) {
      if (seg.value <= 0) continue;
      final sweep = (seg.value / total) * (2 * math.pi) - gap;
      canvas.drawArc(rect, start + gap / 2, sweep, false, Paint()
        ..color = seg.color ..strokeWidth = outer - inner
        ..style = PaintingStyle.stroke ..strokeCap = StrokeCap.butt);
      start += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.total != total;
}

// ── Preview: Waterfall ────────────────────────────────────────────────────────

class _WaterfallPreview extends StatelessWidget {
  final double revenue, cogs, expenses, net;
  const _WaterfallPreview({required this.revenue, required this.cogs,
      required this.expenses, required this.net});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final bars = [
      _WBar('Revenue',  revenue,   AppColors.accent),
      _WBar('COGS',     -cogs,     AppColors.danger),
      _WBar('Expenses', -expenses, AppColors.warning),
      _WBar('Net',      net,       net >= 0 ? AppColors.success : AppColors.danger),
    ];
    final maxAbs = bars.map((b) => b.value.abs()).reduce(math.max).clamp(1.0, double.infinity);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: bars.map((b) {
        final frac = b.value.abs() / maxAbs;
        return Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text(b.value >= 0 ? currency.format(b.value) : '-${currency.format(b.value.abs())}',
                style: TextStyle(color: b.color, fontSize: 8, fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 1),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Container(height: 36 * frac,
                  color: b.color.withOpacity(b.value >= 0 ? 0.85 : 0.55)),
            ),
            const SizedBox(height: 2),
            Text(b.label,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 9),
                textAlign: TextAlign.center, maxLines: 1),
          ]),
        ));
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

// ── Preview: Show net profit mini bars ────────────────────────────────────────

class _ShowNetBarsPreview extends StatelessWidget {
  final List<dynamic> shows;
  const _ShowNetBarsPreview({required this.shows});

  @override
  Widget build(BuildContext context) {
    if (shows.isEmpty) {
      return const Center(child: Text('No show data yet',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12)));
    }
    final recent = shows.take(6).toList();
    final netValues = recent.map((s) => _d(s['net_profit'])).toList();
    final maxAbs = netValues.map((v) => v.abs()).reduce(math.max).clamp(1.0, double.infinity);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: recent.asMap().entries.map((e) {
        final net   = netValues[e.key];
        final frac  = net.abs() / maxAbs;
        final color = net >= 0 ? const Color(0xFF7B61FF) : AppColors.danger;
        final name  = (e.value['show_name'] as String? ?? '').length > 5
            ? (e.value['show_name'] as String).substring(0, 5)
            : (e.value['show_name'] as String? ?? '');
        return Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Container(height: (48 * frac).clamp(4.0, 48.0),
                  color: color.withOpacity(0.75)),
            ),
            const SizedBox(height: 3),
            Text(name,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 8),
                maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
          ]),
        ));
      }).toList(),
    );
  }
}

// ── Coming Soon section ───────────────────────────────────────────────────────

class _ComingSoonSection extends StatelessWidget {
  const _ComingSoonSection();

  @override
  Widget build(BuildContext context) {
    const items = [
      _SoonItem('Trade Equity Report',       Icons.compare_arrows_outlined),
      _SoonItem('Store Credit Liability',    Icons.credit_card_outlined),
      _SoonItem('Acquisition Source',        Icons.source_outlined),
      _SoonItem('Cash Flow Forecast',        Icons.account_balance_wallet_outlined),
      _SoonItem('Graded vs Raw ROI',         Icons.grade_outlined),
      _SoonItem('Bulk Sale Tracking',        Icons.layers_outlined),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkDivider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Icon(Icons.construction_outlined, size: 14, color: AppColors.textSecondary),
            SizedBox(width: 8),
            Text('COMING SOON', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                color: AppColors.textSecondary, letterSpacing: 1.2)),
          ]),
        ),
        const Divider(height: 1),
        Wrap(children: items.map((item) => _SoonChip(item: item)).toList()),
        const SizedBox(height: 8),
      ]),
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
          color: AppColors.darkSurfaceElevated,
          borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(item.icon, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 5),
        Text(item.label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ]),
    ),
  );
}
