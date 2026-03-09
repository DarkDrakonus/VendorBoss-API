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

class ShowROIReport extends StatefulWidget {
  const ShowROIReport({super.key});

  @override
  State<ShowROIReport> createState() => _ShowROIReportState();
}

class _ShowROIReportState extends State<ShowROIReport> {
  List<Map<String, dynamic>> _shows = [];
  bool _loading = true;
  String? _error;
  String _sortBy = 'date';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.instance.getShowROI();
      if (!mounted) return;
      final shows = (data['shows'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      setState(() { _shows = shows; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _sorted {
    final s = List<Map<String, dynamic>>.from(_shows);
    switch (_sortBy) {
      case 'roi':     s.sort((a, b) => _d(b['roi_percent']).compareTo(_d(a['roi_percent']))); break;
      case 'revenue': s.sort((a, b) => _d(b['total_sales']).compareTo(_d(a['total_sales']))); break;
      case 'net':     s.sort((a, b) => _d(b['net_profit']).compareTo(_d(a['net_profit']))); break;
      default:        s.sort((a, b) => (b['show_date'] as String).compareTo(a['show_date'] as String));
    }
    return s;
  }

  List<Map<String, dynamic>> get _chronological {
    final s = List<Map<String, dynamic>>.from(_shows);
    s.sort((a, b) => (a['show_date'] as String).compareTo(b['show_date'] as String));
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final currency   = NumberFormat.currency(symbol: '\$');
    final dateFormat = DateFormat('MMM d, yyyy');

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Show ROI Tracker')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Show ROI Tracker')),
        body: _ErrorBody(error: _error!, onRetry: _load),
      );
    }

    final sorted = _sorted;
    final chrono = _chronological;

    final totalRevenue = sorted.fold(0.0, (s, d) => s + _d(d['total_sales']));
    final totalCOA     = sorted.fold(0.0, (s, d) => s + _d(d['total_expenses']));
    final totalNet     = sorted.fold(0.0, (s, d) => s + _d(d['net_profit']));
    final profitable   = sorted.where((d) => _d(d['net_profit']) >= 0).length;

    if (sorted.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Show ROI Tracker')),
        body: const Center(
          child: Text('No shows yet. Add your first show to see ROI data.',
              style: TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
        ),
      );
    }

    final bestShow  = sorted.reduce((a, b) => _d(a['roi_percent']) > _d(b['roi_percent']) ? a : b);
    final worstShow = sorted.reduce((a, b) => _d(a['roi_percent']) < _d(b['roi_percent']) ? a : b);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Show ROI Tracker'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            initialValue: _sortBy,
            onSelected: (v) => setState(() => _sortBy = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'date',    child: Text('Sort by Date')),
              PopupMenuItem(value: 'roi',     child: Text('Sort by ROI %')),
              PopupMenuItem(value: 'revenue', child: Text('Sort by Revenue')),
              PopupMenuItem(value: 'net',     child: Text('Sort by Net Profit')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            // ── Summary strip
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
              Expanded(child: _StatCard('Shows', '${sorted.length}', AppColors.textSecondary)),
              const SizedBox(width: 8),
              Expanded(child: _StatCard('Profitable', '$profitable/${sorted.length}',
                  profitable == sorted.length ? AppColors.success : AppColors.warning)),
              const SizedBox(width: 8),
              Expanded(child: _StatCard('Overall ROI',
                  totalCOA > 0 ? '${((totalNet / totalCOA) * 100).toStringAsFixed(0)}%' : '—',
                  totalNet >= 0 ? AppColors.success : AppColors.danger)),
            ]),

            const SizedBox(height: 24),

            // ── Trend chart
            const _SectionLabel('ROI TREND — SHOW OVER SHOW'),
            const SizedBox(height: 4),
            const Text('Is your show performance improving over time?',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            _TrendChart(shows: chrono, currency: currency),

            const SizedBox(height: 24),

            // ── Best / worst
            if (sorted.length >= 2)
              Row(children: [
                Expanded(child: _CalloutCard(
                  icon: Icons.emoji_events_outlined, color: AppColors.success, label: 'Best ROI',
                  title: bestShow['show_name'] ?? '',
                  sub: '${_d(bestShow['roi_percent']).toStringAsFixed(0)}% ROI · ${currency.format(_d(bestShow['net_profit']))} net',
                )),
                const SizedBox(width: 10),
                Expanded(child: _CalloutCard(
                  icon: Icons.trending_down_outlined,
                  color: _d(worstShow['net_profit']) >= 0 ? AppColors.warning : AppColors.danger,
                  label: 'Needs Review',
                  title: worstShow['show_name'] ?? '',
                  sub: '${_d(worstShow['roi_percent']).toStringAsFixed(0)}% ROI · ${currency.format(_d(worstShow['net_profit']))} net',
                )),
              ]),

            const SizedBox(height: 24),
            const _SectionLabel('ALL SHOWS'),
            const SizedBox(height: 10),
            ...sorted.map((d) => _ShowROICard(data: d, currency: currency, dateFormat: dateFormat)),
          ],
        ),
      ),
    );
  }
}

// ── Trend chart ───────────────────────────────────────────────────────────────

class _TrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> shows;
  final NumberFormat currency;
  const _TrendChart({required this.shows, required this.currency});

  @override
  Widget build(BuildContext context) {
    if (shows.length < 2) {
      return Container(
        height: 100, alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(12)),
        child: const Text('Attend at least 2 shows to see trend data.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _Legend('Net Profit', AppColors.accent),
          const SizedBox(width: 16),
          _Legend('Break-even', AppColors.textSecondary),
        ]),
        const SizedBox(height: 12),
        SizedBox(height: 140,
          child: CustomPaint(painter: _TrendPainter(shows: shows), child: const SizedBox.expand())),
        const SizedBox(height: 8),
        Row(children: shows.map((d) {
          final name = (d['show_name'] as String? ?? '');
          final label = name.length > 10 ? '${name.substring(0, 9)}…' : name;
          return Expanded(child: Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 9),
              maxLines: 2, overflow: TextOverflow.ellipsis));
        }).toList()),
        const SizedBox(height: 10),
        Row(children: shows.map((d) {
          final net   = _d(d['net_profit']);
          final roi   = _d(d['roi_percent']);
          final color = net >= 0 ? AppColors.success : AppColors.danger;
          return Expanded(child: Column(children: [
            Text('${roi.toStringAsFixed(0)}%',
                textAlign: TextAlign.center,
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
            Text(currency.format(net),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 9),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ]));
        }).toList()),
      ]),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<Map<String, dynamic>> shows;
  const _TrendPainter({required this.shows});

  @override
  void paint(Canvas canvas, Size size) {
    if (shows.length < 2) return;
    final netProfits = shows.map((s) => _d(s['net_profit'])).toList();
    final minNet = netProfits.reduce(math.min);
    final maxNet = netProfits.reduce(math.max);
    final range  = (maxNet - minNet).clamp(1.0, double.infinity);
    final zeroY  = size.height - ((-minNet) / range) * size.height * 0.9 - 4;

    _drawDashed(canvas, Offset(0, zeroY), Offset(size.width, zeroY),
        AppColors.textSecondary.withOpacity(0.4), 4, 3);
    _drawLine(canvas, size, netProfits, minNet, maxNet, AppColors.accent, 2.0);
  }

  void _drawLine(Canvas canvas, Size size, List<double> values, double minVal, double maxVal,
      Color color, double sw) {
    final range = (maxVal - minVal).clamp(1.0, double.infinity);
    final step  = size.width / (values.length - 1);
    final pts   = List.generate(values.length, (i) => Offset(
        i * step, size.height - ((values[i] - minVal) / range) * size.height * 0.9 - 4));

    final fill = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final cp1 = Offset((pts[i-1].dx + pts[i].dx) / 2, pts[i-1].dy);
      final cp2 = Offset((pts[i-1].dx + pts[i].dx) / 2, pts[i].dy);
      fill.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i].dx, pts[i].dy);
    }
    fill..lineTo(pts.last.dx, size.height)..lineTo(pts.first.dx, size.height)..close();
    canvas.drawPath(fill, Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.15), color.withOpacity(0.0)])
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill);

    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final cp1 = Offset((pts[i-1].dx + pts[i].dx) / 2, pts[i-1].dy);
      final cp2 = Offset((pts[i-1].dx + pts[i].dx) / 2, pts[i].dy);
      line.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(line, Paint()..color = color..strokeWidth = sw..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);

    for (final pt in pts) {
      canvas.drawCircle(pt, 4, Paint()..color = color);
      canvas.drawCircle(pt, 4, Paint()..color = AppColors.darkSurface
          ..style = PaintingStyle.stroke..strokeWidth = 2.0);
    }
  }

  void _drawDashed(Canvas canvas, Offset start, Offset end, Color color, double dl, double gl) {
    final paint = Paint()..color = color..strokeWidth = 1..strokeCap = StrokeCap.round;
    final total = (end - start).distance;
    final dir   = (end - start) / total;
    var drawn = 0.0; var onDash = true;
    while (drawn < total) {
      final seg  = onDash ? dl : gl;
      final from = start + dir * drawn;
      final to   = start + dir * math.min(drawn + seg, total);
      if (onDash) canvas.drawLine(from, to, paint);
      drawn += seg; onDash = !onDash;
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => old.shows != shows;
}

// ── Show ROI card ─────────────────────────────────────────────────────────────

class _ShowROICard extends StatefulWidget {
  final Map<String, dynamic> data;
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
    final net         = _d(d['net_profit']);
    final roi         = _d(d['roi_percent']);
    final revenue     = _d(d['total_sales']);
    final expenses    = _d(d['total_expenses']);
    final tableCost   = _d(d['table_cost']);
    final txCount     = d['transaction_count'] as int? ?? 0;
    final isProfitable = net >= 0;
    final profitColor  = isProfitable ? AppColors.success : AppColors.danger;
    DateTime? showDate;
    try { showDate = DateTime.parse(d['show_date'] as String); } catch (_) {}

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    if (!isProfitable) _Badge('LOSS', AppColors.danger),
                    Flexible(child: Text(d['show_name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    showDate != null ? dateFormat.format(showDate) : (d['show_date'] ?? ''),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  if ((d['location'] as String?)?.isNotEmpty == true)
                    Text(d['location'] as String,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(currency.format(net),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: profitColor)),
                  const Text('net profit', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ]),
              ]),

              const SizedBox(height: 14),

              Row(children: [
                _Metric('${roi.toStringAsFixed(0)}%', 'ROI',     _roiColor(roi)),
                const SizedBox(width: 16),
                _Metric('$txCount',                   'Sales',   AppColors.textSecondary),
                const SizedBox(width: 16),
                _Metric(currency.format(revenue),     'Revenue', AppColors.accent),
                const SizedBox(width: 16),
                _Metric(currency.format(expenses),    'Cost',    AppColors.warning),
              ]),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: profitColor.withOpacity(0.07), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Icon(_verdictIcon(roi, isProfitable), size: 14, color: profitColor),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_verdictText(roi, isProfitable),
                      style: TextStyle(color: profitColor, fontSize: 12, fontWeight: FontWeight.w600))),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18, color: AppColors.textSecondary),
                ]),
              ),
            ]),
          ),
        ),

        if (_expanded)
          Container(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.darkDivider))),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _SubLabel('REVENUE'),
              const SizedBox(height: 6),
              _DetailRow('Gross Revenue', currency.format(revenue), AppColors.textPrimary),
              const SizedBox(height: 12),
              const _SubLabel('COST OF ATTENDANCE'),
              const SizedBox(height: 6),
              if (tableCost > 0)
                _DetailRow('Table / Booth Fee', '− ${currency.format(tableCost)}', AppColors.warning),
              _DetailRow('Total Expenses', '− ${currency.format(expenses)}', AppColors.warning),
              const Divider(height: 16),
              _DetailRow('Net Profit', currency.format(net), profitColor, bold: true),
            ]),
          ),
      ]),
    );
  }

  Color _roiColor(double roi) {
    if (roi >= 200) return AppColors.success;
    if (roi >= 100) return AppColors.accent;
    if (roi >= 0)   return AppColors.warning;
    return AppColors.danger;
  }

  IconData _verdictIcon(double roi, bool profitable) {
    if (roi >= 200)   return Icons.star_outlined;
    if (profitable)   return Icons.thumb_up_outlined;
    return Icons.thumb_down_outlined;
  }

  String _verdictText(double roi, bool profitable) {
    if (roi >= 400) return 'Exceptional — your single best investment. Prioritise this show every year.';
    if (roi >= 200) return 'Excellent — worth prioritising and potentially booking a larger table.';
    if (roi >= 100) return 'Profitable — solid return on attendance cost. Worth returning.';
    if (roi >= 50)  return 'Marginal — covered costs but barely. Review pricing and mix before returning.';
    if (roi >= 0)   return 'Thin — almost broke even. Reconsider whether this show fits your inventory.';
    return 'Loss — attendance cost exceeded revenue. Do not return without a strategy change.';
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String text; final Color color;
  const _Badge(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 6),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800)),
  );
}

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
      fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 1.2));
}

class _SubLabel extends StatelessWidget {
  final String text; const _SubLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(
      fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accent, letterSpacing: 1.0));
}

class _DetailRow extends StatelessWidget {
  final String label, value; final Color color; final bool bold;
  const _DetailRow(this.label, this.value, this.color, {this.bold = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(color: AppColors.textSecondary,
          fontWeight: bold ? FontWeight.w700 : FontWeight.normal, fontSize: 13))),
      Text(value, style: TextStyle(color: color,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: 13)),
    ]),
  );
}

class _Metric extends StatelessWidget {
  final String value, label; final Color color;
  const _Metric(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14)),
    Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
  ]);
}

class _CalloutCard extends StatelessWidget {
  final IconData icon; final Color color; final String label, title, sub;
  const _CalloutCard({required this.icon, required this.color,
      required this.label, required this.title, required this.sub});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3))),
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

class _Legend extends StatelessWidget {
  final String label; final Color color;
  const _Legend(this.label, this.color);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 5),
    Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
  ]);
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
