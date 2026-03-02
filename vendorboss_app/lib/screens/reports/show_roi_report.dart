import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../../theme/app_theme.dart';
import '../../services/mock_data_service.dart';
import '../../models/show.dart';

class ShowROIReport extends StatefulWidget {
  const ShowROIReport({super.key});

  @override
  State<ShowROIReport> createState() => _ShowROIReportState();
}

class _ShowROIReportState extends State<ShowROIReport> {
  String _sortBy = 'date';

  @override
  Widget build(BuildContext context) {
    final currency   = NumberFormat.currency(symbol: '\$');
    final dateFormat = DateFormat('MMM d, yyyy');

    // Chronological order for trend chart (always oldest → newest)
    final chronological = List<ShowROI>.from(MockDataService.showROIData)
      ..sort((a, b) => a.show.date.compareTo(b.show.date));

    // Sorted order for the detail cards
    var sorted = List<ShowROI>.from(MockDataService.showROIData);
    switch (_sortBy) {
      case 'roi':     sorted.sort((a, b) => b.roi.compareTo(a.roi));                   break;
      case 'revenue': sorted.sort((a, b) => b.grossRevenue.compareTo(a.grossRevenue)); break;
      case 'net':     sorted.sort((a, b) => b.netProfit.compareTo(a.netProfit));       break;
      default:        sorted.sort((a, b) => b.show.date.compareTo(a.show.date));
    }

    final totalRevenue = sorted.fold(0.0, (s, d) => s + d.grossRevenue);
    final totalCOA     = sorted.fold(0.0, (s, d) => s + d.costOfAttendance);
    final totalNet     = sorted.fold(0.0, (s, d) => s + d.netProfit);
    final profitable   = sorted.where((d) => d.isProfitable).length;
    final bestShow     = sorted.reduce((a, b) => a.roi > b.roi ? a : b);
    final worstShow    = sorted.reduce((a, b) => a.roi < b.roi ? a : b);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Show ROI Tracker'),
        actions: [
          PopupMenuButton<String>(
            icon:         const Icon(Icons.sort),
            tooltip:      'Sort shows',
            initialValue: _sortBy,
            onSelected:   (v) => setState(() => _sortBy = v),
            itemBuilder:  (_) => const [
              PopupMenuItem(value: 'date',    child: Text('Sort by Date')),
              PopupMenuItem(value: 'roi',     child: Text('Sort by ROI %')),
              PopupMenuItem(value: 'revenue', child: Text('Sort by Revenue')),
              PopupMenuItem(value: 'net',     child: Text('Sort by Net Profit')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [

          // ── Summary strip ─────────────────────────────────────────────
          Row(children: [
            Expanded(child: _StatCard('Total Revenue', currency.format(totalRevenue), AppColors.accent)),
            const SizedBox(width: 8),
            Expanded(child: _StatCard('Attend. Cost',  currency.format(totalCOA),    AppColors.warning)),
            const SizedBox(width: 8),
            Expanded(child: _StatCard('Net Profit',    currency.format(totalNet),
                totalNet >= 0 ? AppColors.success : AppColors.danger)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _StatCard('Shows', '${sorted.length}',            AppColors.textSecondary)),
            const SizedBox(width: 8),
            Expanded(child: _StatCard('Profitable', '$profitable/${sorted.length}',
                profitable == sorted.length ? AppColors.success : AppColors.warning)),
            const SizedBox(width: 8),
            Expanded(child: _StatCard('Overall ROI',
                totalCOA > 0 ? '${((totalNet / totalCOA) * 100).toStringAsFixed(0)}%' : '—',
                totalNet >= 0 ? AppColors.success : AppColors.danger)),
          ]),

          const SizedBox(height: 24),

          // ── ROI trend line chart ──────────────────────────────────────
          const _SectionLabel('ROI TREND — SHOW OVER SHOW'),
          const SizedBox(height: 4),
          const Text(
            'Is your show performance improving over time?',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          _TrendChart(shows: chronological, currency: currency),

          const SizedBox(height: 24),

          // ── Best / worst callouts ─────────────────────────────────────
          Row(children: [
            Expanded(child: _CalloutCard(
              icon:  Icons.emoji_events_outlined,
              color: AppColors.success,
              label: 'Best ROI',
              title: bestShow.show.name,
              sub:   '${bestShow.roi.toStringAsFixed(0)}% ROI · ${currency.format(bestShow.netProfit)} net',
            )),
            const SizedBox(width: 10),
            Expanded(child: _CalloutCard(
              icon:  Icons.trending_down_outlined,
              color: worstShow.isProfitable ? AppColors.warning : AppColors.danger,
              label: 'Needs Review',
              title: worstShow.show.name,
              sub:   '${worstShow.roi.toStringAsFixed(0)}% ROI · ${currency.format(worstShow.netProfit)} net',
            )),
          ]),

          const SizedBox(height: 24),

          // ── Per-show detail cards ─────────────────────────────────────
          const _SectionLabel('ALL SHOWS'),
          const SizedBox(height: 10),
          ...sorted.map((d) => _ShowROICard(
            data:       d,
            currency:   currency,
            dateFormat: dateFormat,
          )),
        ],
      ),
    );
  }
}

// ── ROI Trend Chart (line) ────────────────────────────────────────────────────

class _TrendChart extends StatelessWidget {
  final List<ShowROI> shows;
  final NumberFormat currency;
  const _TrendChart({required this.shows, required this.currency});

  @override
  Widget build(BuildContext context) {
    if (shows.length < 2) {
      return const _EmptyChart(
          message: 'Attend at least 2 shows to see trend data.');
    }

    final shortDate = DateFormat('MMM d');

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        color:        AppColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Legend
          Row(children: [
            _Legend('Net Profit',  AppColors.accent),
            const SizedBox(width: 16),
            _Legend('ROI %',       AppColors.info),
            const SizedBox(width: 16),
            _Legend('Break-even',  AppColors.textSecondary),
          ]),
          const SizedBox(height: 12),

          // Chart canvas
          SizedBox(
            height: 140,
            child: CustomPaint(
              painter: _TrendChartPainter(shows: shows),
              child: const SizedBox.expand(),
            ),
          ),

          const SizedBox(height: 8),

          // X-axis labels
          Row(
            children: shows.asMap().entries.map((e) {
              final name = e.value.show.name.length > 10
                  ? '${e.value.show.name.substring(0, 9)}…'
                  : e.value.show.name;
              return Expanded(
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color:    AppColors.textSecondary,
                    fontSize: 9,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          // Data points summary row
          Row(
            children: shows.map((d) {
              final color = d.isProfitable ? AppColors.success : AppColors.danger;
              return Expanded(
                child: Column(children: [
                  Text(
                    '${d.roi.toStringAsFixed(0)}%',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color:      color,
                      fontSize:   11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    currency.format(d.netProfit),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color:    AppColors.textSecondary,
                      fontSize: 9,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ]),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  final List<ShowROI> shows;
  const _TrendChartPainter({required this.shows});

  @override
  void paint(Canvas canvas, Size size) {
    if (shows.length < 2) return;

    final netProfits = shows.map((s) => s.netProfit).toList();
    final roiPcts    = shows.map((s) => s.roi).toList();

    // ── Break-even line ───────────────────────────────────────────────
    final minNet = netProfits.reduce(math.min);
    final maxNet = netProfits.reduce(math.max);
    final netRange = (maxNet - minNet).clamp(1.0, double.infinity);

    // Y position of zero on the net profit axis
    final zeroY = size.height - ((-minNet) / netRange) * size.height * 0.9 - 4;

    canvas.drawLine(
      Offset(0, zeroY),
      Offset(size.width, zeroY),
      Paint()
        ..color       = AppColors.textSecondary.withOpacity(0.3)
        ..strokeWidth = 1
        ..style       = PaintingStyle.stroke
        ..strokeCap   = StrokeCap.round
        ..strokeJoin  = StrokeJoin.round
        ..shader      = null
        // dashed via DashPainter workaround — draw as path
        ,
    );

    // Draw dashed line manually
    _drawDashed(canvas, Offset(0, zeroY), Offset(size.width, zeroY),
        AppColors.textSecondary.withOpacity(0.4), 4, 3);

    // ── Net profit line (teal) ────────────────────────────────────────
    _drawLine(
      canvas, size,
      values:   netProfits,
      minVal:   minNet,
      maxVal:   maxNet,
      color:    AppColors.accent,
      dotColor: AppColors.accent,
    );

    // ── ROI % line (blue) — normalized to same scale ──────────────────
    final minRoi = roiPcts.reduce(math.min);
    final maxRoi = roiPcts.reduce(math.max);
    _drawLine(
      canvas, size,
      values:      roiPcts,
      minVal:      minRoi,
      maxVal:      maxRoi,
      color:       AppColors.info,
      dotColor:    AppColors.info,
      dashed:      false,
      strokeWidth: 1.5,
      opacity:     0.65,
    );
  }

  void _drawLine(
    Canvas canvas,
    Size size, {
    required List<double> values,
    required double minVal,
    required double maxVal,
    required Color color,
    required Color dotColor,
    bool dashed       = false,
    double strokeWidth = 2.0,
    double opacity     = 1.0,
  }) {
    final range  = (maxVal - minVal).clamp(1.0, double.infinity);
    final step   = size.width / (values.length - 1);
    final points = <Offset>[];

    for (int i = 0; i < values.length; i++) {
      final x = i * step;
      final y = size.height - ((values[i] - minVal) / range) * size.height * 0.9 - 4;
      points.add(Offset(x, y));
    }

    // Fill
    final fillPath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      // Smooth bezier
      final cp1 = Offset(
        (points[i - 1].dx + points[i].dx) / 2,
        points[i - 1].dy,
      );
      final cp2 = Offset(
        (points[i - 1].dx + points[i].dx) / 2,
        points[i].dy,
      );
      fillPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, points[i].dx, points[i].dy);
    }
    fillPath
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end:   Alignment.bottomCenter,
          colors: [
            color.withOpacity(0.15 * opacity),
            color.withOpacity(0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill,
    );

    // Line
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final cp1 = Offset((points[i - 1].dx + points[i].dx) / 2, points[i - 1].dy);
      final cp2 = Offset((points[i - 1].dx + points[i].dx) / 2, points[i].dy);
      linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, points[i].dx, points[i].dy);
    }

    canvas.drawPath(
      linePath,
      Paint()
        ..color       = color.withOpacity(opacity)
        ..strokeWidth = strokeWidth
        ..style       = PaintingStyle.stroke
        ..strokeCap   = StrokeCap.round
        ..strokeJoin  = StrokeJoin.round,
    );

    // Dots
    for (final pt in points) {
      canvas.drawCircle(pt, 4,  Paint()..color = dotColor.withOpacity(opacity));
      canvas.drawCircle(pt, 4,  Paint()
        ..color       = AppColors.darkSurface
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 2.0);
    }
  }

  void _drawDashed(Canvas canvas, Offset start, Offset end,
      Color color, double dashLen, double gapLen) {
    final paint = Paint()
      ..color       = color
      ..strokeWidth = 1
      ..strokeCap   = StrokeCap.round;
    final total  = (end - start).distance;
    final dir    = (end - start) / total;
    var   drawn  = 0.0;
    var   onDash = true;
    while (drawn < total) {
      final segLen = onDash ? dashLen : gapLen;
      final from   = start + dir * drawn;
      final to     = start + dir * math.min(drawn + segLen, total);
      if (onDash) canvas.drawLine(from, to, paint);
      drawn  += segLen;
      onDash  = !onDash;
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter old) => old.shows != shows;
}

// ── Per-show expandable card ──────────────────────────────────────────────────

class _ShowROICard extends StatefulWidget {
  final ShowROI data;
  final NumberFormat currency;
  final DateFormat dateFormat;
  const _ShowROICard({required this.data, required this.currency, required this.dateFormat});

  @override
  State<_ShowROICard> createState() => _ShowROICardState();
}

class _ShowROICardState extends State<_ShowROICard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final d           = widget.data;
    final currency    = widget.currency;
    final dateFormat  = widget.dateFormat;
    final profitColor = d.isProfitable ? AppColors.success : AppColors.danger;

    final expenses    = MockDataService.expensesForShow(d.show.id);
    final coaTypes    = ['table_fee', 'travel', 'hotel', 'food'];
    final coaExpenses = expenses.where((e) => coaTypes.contains(e.type)).toList();
    final otherExp    = expenses.where((e) => !coaTypes.contains(e.type)).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              if (d.show.isActive)   _Badge('ACTIVE', AppColors.accent),
                              if (!d.isProfitable)   _Badge('LOSS',   AppColors.danger),
                              Flexible(child: Text(d.show.name,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                            ]),
                            const SizedBox(height: 2),
                            Text('${dateFormat.format(d.show.date)}  ·  ${d.show.location ?? ''}',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(currency.format(d.netProfit),
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: profitColor)),
                          const Text('net profit',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Row(children: [
                    _Metric('${d.roi.toStringAsFixed(0)}%', 'ROI',          _roiColor(d.roi)),
                    const SizedBox(width: 16),
                    _Metric('${d.transactionCount}',        'Sales',        AppColors.textSecondary),
                    const SizedBox(width: 16),
                    _Metric(currency.format(d.grossRevenue),'Revenue',      AppColors.accent),
                    const SizedBox(width: 16),
                    _Metric(currency.format(d.costOfAttendance), 'Att. Cost', AppColors.warning),
                  ]),

                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color:        profitColor.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      Icon(_verdictIcon(d), size: 14, color: profitColor),
                      const SizedBox(width: 6),
                      Expanded(child: Text(_verdictText(d),
                          style: TextStyle(color: profitColor, fontSize: 12, fontWeight: FontWeight.w600))),
                      Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                          size: 18, color: AppColors.textSecondary),
                    ]),
                  ),
                ],
              ),
            ),
          ),

          if (_expanded)
            Container(
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.darkDivider))),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SubLabel('REVENUE'),
                  const SizedBox(height: 6),
                  _DetailRow('Gross Revenue', currency.format(d.grossRevenue), AppColors.textPrimary),
                  if (d.bulkSaleCount > 0) ...[
                    _DetailRow('Singles Revenue', currency.format(d.singleRevenue), AppColors.accent),
                    _DetailRow('Bulk Revenue (${d.bulkSaleCount} txns)',
                        currency.format(d.bulkRevenue), const Color(0xFF7B61FF)),
                  ],

                  const SizedBox(height: 12),
                  const _SubLabel('COST OF ATTENDANCE'),
                  const SizedBox(height: 6),
                  ...coaExpenses.map((e) => _DetailRow(
                    _expLabel(e.type), '− ${currency.format(e.amount)}', AppColors.warning)),
                  if (coaExpenses.isEmpty)
                    const Text('No attendance expenses recorded.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),

                  if (otherExp.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const _SubLabel('OTHER EXPENSES'),
                    const SizedBox(height: 6),
                    ...otherExp.map((e) => _DetailRow(
                        e.description, '− ${currency.format(e.amount)}', AppColors.textSecondary)),
                  ],

                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  _DetailRow('Net Profit', currency.format(d.netProfit), profitColor, bold: true),

                  if (d.bulkSaleCount > 0) ...[
                    const SizedBox(height: 14),
                    const _SubLabel('BULK AT THIS SHOW'),
                    const SizedBox(height: 6),
                    _DetailRow('Bulk transactions', '${d.bulkSaleCount}', const Color(0xFF7B61FF)),
                    _DetailRow('Avg bulk sale',
                        currency.format(d.bulkRevenue / d.bulkSaleCount), const Color(0xFF7B61FF)),
                    _DetailRow('Bulk % of revenue',
                        '${d.bulkPct.toStringAsFixed(1)}%', const Color(0xFF7B61FF)),
                  ],

                  if (d.show.tableNumber != null || d.show.venue != null) ...[
                    const SizedBox(height: 14),
                    const _SubLabel('VENUE'),
                    const SizedBox(height: 6),
                    if (d.show.venue != null)
                      _DetailRow('Venue', d.show.venue!, AppColors.textSecondary),
                    if (d.show.tableNumber != null)
                      _DetailRow('Table', d.show.tableNumber!, AppColors.textSecondary),
                    if (d.show.tableCost != null)
                      _DetailRow('Table cost', currency.format(d.show.tableCost!), AppColors.textSecondary),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _expLabel(String t) => switch (t) {
    'table_fee' => 'Table / Booth Fee',
    'travel'    => 'Travel',
    'hotel'     => 'Lodging',
    'food'      => 'Meals',
    _           => t,
  };

  Color _roiColor(double roi) {
    if (roi >= 200) return AppColors.success;
    if (roi >= 100) return AppColors.accent;
    if (roi >= 0)   return AppColors.warning;
    return AppColors.danger;
  }

  IconData _verdictIcon(ShowROI d) {
    if (d.roi >= 200)   return Icons.star_outlined;
    if (d.isProfitable) return Icons.thumb_up_outlined;
    return Icons.thumb_down_outlined;
  }

  String _verdictText(ShowROI d) {
    if (d.roi >= 400) return 'Exceptional — your single best investment. Prioritise this show every year.';
    if (d.roi >= 200) return 'Excellent — worth prioritising and potentially booking a larger table.';
    if (d.roi >= 100) return 'Profitable — solid return on attendance cost. Worth returning.';
    if (d.roi >= 50)  return 'Marginal — covered costs but barely. Review pricing and mix before returning.';
    if (d.roi >= 0)   return 'Thin — almost broke even. Reconsider whether this show fits your inventory.';
    return 'Loss — attendance cost exceeded revenue. Do not return without a strategy change.';
  }
}

// ── Empty chart placeholder ───────────────────────────────────────────────────

class _EmptyChart extends StatelessWidget {
  final String message;
  const _EmptyChart({required this.message});

  @override
  Widget build(BuildContext context) => Container(
    height: 100,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color:        AppColors.darkSurface,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
  );
}

// ── Legend dot + label ────────────────────────────────────────────────────────

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

// ── Callout card ──────────────────────────────────────────────────────────────

class _CalloutCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, title, sub;
  const _CalloutCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.title,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color:        color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border:       Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(sub, style: TextStyle(color: color, fontSize: 11)),
      ])),
    ]),
  );
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    margin:  const EdgeInsets.only(right: 6),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color:        color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800)),
  );
}

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

class _SubLabel extends StatelessWidget {
  final String text;
  const _SubLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
          color: AppColors.accent, letterSpacing: 1.0));
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool bold;
  const _DetailRow(this.label, this.value, this.color, {this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(
          color:      AppColors.textSecondary,
          fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
          fontSize:   13))),
      Text(value, style: TextStyle(
          color:      color,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          fontSize:   13)),
    ]),
  );
}

class _Metric extends StatelessWidget {
  final String value, label;
  final Color color;
  const _Metric(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14)),
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
    ],
  );
}
