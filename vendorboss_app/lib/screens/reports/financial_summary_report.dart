import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:math' as math;
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

double _d(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

class FinancialSummaryReport extends StatefulWidget {
  final int startTab;
  const FinancialSummaryReport({super.key, this.startTab = 0});

  @override
  State<FinancialSummaryReport> createState() => _FinancialSummaryReportState();
}

class _FinancialSummaryReportState extends State<FinancialSummaryReport>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this, initialIndex: widget.startTab);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.instance.getFinancialSummary();
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
        title: const Text('Financial Summary'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.darkTextSecondary,
          tabs: const [
            Tab(text: 'YTD Overview'),
            Tab(text: 'Schedule C'),
            Tab(text: 'Expenses'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _data == null
              ? _ErrorBody(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _YTDTab(data: _data!),
                      _ScheduleCTab(data: _data!),
                      _ExpensesTab(data: _data!),
                    ],
                  ),
                ),
    );
  }
}

// ── YTD Overview ──────────────────────────────────────────────────────────────

class _YTDTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _YTDTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$');
    final year     = data['year'] as int? ?? DateTime.now().year;

    final totalRevenue  = _d(data['total_revenue']);
    final totalCogs     = _d(data['total_cogs']);
    final totalExpenses = _d(data['total_expenses']);
    final grossProfit   = _d(data['gross_profit']);
    final netProfit     = _d(data['net_profit']);
    final txCount       = data['total_transactions'] as int? ?? 0;

    // Monthly net profit for chart
    final monthly = (data['monthly'] as List<dynamic>? ?? []);
    final last6   = monthly.length >= 6 ? monthly.sublist(monthly.length - 6) : monthly;
    final monthlyNet = last6.map<double>((m) => _d(m['net_profit'])).toList();
    final monthLabels = last6.map<String>((m) => m['month'] as String? ?? '').toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // Hero
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: (netProfit >= 0 ? AppColors.success : AppColors.danger).withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: (netProfit >= 0 ? AppColors.success : AppColors.danger).withOpacity(0.3)),
          ),
          child: Column(children: [
            Text('$year Net Profit', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            Text(currency.format(netProfit), style: TextStyle(
              fontSize: 36, fontWeight: FontWeight.w900,
              color: netProfit >= 0 ? AppColors.success : AppColors.danger)),
            const SizedBox(height: 4),
            Text('$txCount transactions',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ]),
        ),

        const SizedBox(height: 20),

        // Monthly trend
        const _Label('NET PROFIT — LAST 6 MONTHS'),
        const SizedBox(height: 4),
        const Text('Revenue minus COGS and expenses each month',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 12),
        _NetProfitChart(monthly: monthlyNet, labels: monthLabels),

        const SizedBox(height: 24),

        // Income statement
        const _Label('INCOME STATEMENT'),
        const SizedBox(height: 10),
        _FinLine('Gross Revenue',             currency.format(totalRevenue),  AppColors.textPrimary),
        _FinLine('Cost of Goods Sold (COGS)', '− ${currency.format(totalCogs)}', AppColors.danger),
        const Divider(height: 20),
        _FinLine('Gross Profit', currency.format(grossProfit), AppColors.accent, bold: true),
        const SizedBox(height: 8),
        _FinLine('Total Expenses', '− ${currency.format(totalExpenses)}', AppColors.warning),
        const Divider(height: 20),
        _FinLine('Net Profit', currency.format(netProfit),
            netProfit >= 0 ? AppColors.success : AppColors.danger, bold: true),

        const SizedBox(height: 24),
        const _Label('MARGINS'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _MetricCard('Gross Margin',
              totalRevenue > 0 ? '${((grossProfit / totalRevenue) * 100).toStringAsFixed(1)}%' : '—',
              AppColors.accent)),
          const SizedBox(width: 10),
          Expanded(child: _MetricCard('Net Margin',
              totalRevenue > 0 ? '${((netProfit / totalRevenue) * 100).toStringAsFixed(1)}%' : '—',
              netProfit >= 0 ? AppColors.success : AppColors.danger)),
          const SizedBox(width: 10),
          Expanded(child: _MetricCard('Expense Ratio',
              totalRevenue > 0 ? '${((totalExpenses / totalRevenue) * 100).toStringAsFixed(1)}%' : '—',
              AppColors.warning)),
        ]),

        const SizedBox(height: 24),
        if (totalRevenue >= 500)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withOpacity(0.35)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.warning_amber_outlined, color: AppColors.warning, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('IRS Threshold Reminder',
                    style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  totalRevenue >= 600
                      ? 'Your $year gross revenue of ${currency.format(totalRevenue)} exceeds '
                        'the \$600 reporting threshold. Platforms will file a 1099-K with the IRS.'
                      : 'Your $year gross revenue of ${currency.format(totalRevenue)} is approaching '
                        'the \$600 reporting threshold.',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5),
                ),
              ])),
            ]),
          ),
      ],
    );
  }
}

// ── Monthly net profit chart ──────────────────────────────────────────────────

class _NetProfitChart extends StatelessWidget {
  final List<double> monthly;
  final List<String> labels;
  const _NetProfitChart({required this.monthly, required this.labels});

  @override
  Widget build(BuildContext context) {
    if (monthly.isEmpty) {
      return Container(
        height: 120, alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(12)),
        child: const Text('No data yet', style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
      decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        SizedBox(height: 110, child: CustomPaint(
          painter: _NetProfitPainter(monthly: monthly),
          child: const SizedBox.expand())),
        const SizedBox(height: 6),
        Row(children: labels.map((m) => Expanded(
          child: Text(m, textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
        )).toList()),
      ]),
    );
  }
}

class _NetProfitPainter extends CustomPainter {
  final List<double> monthly;
  const _NetProfitPainter({required this.monthly});

  @override
  void paint(Canvas canvas, Size size) {
    if (monthly.length < 2) return;
    final maxVal   = monthly.reduce(math.max);
    final minVal   = monthly.reduce(math.min);
    final rangeMax = math.max(maxVal, 0.0);
    final rangeMin = math.min(minVal, 0.0);
    final range    = (rangeMax - rangeMin).clamp(1.0, double.infinity);

    double toY(double val) =>
        size.height - ((val - rangeMin) / range) * size.height * 0.85 - 4;

    final step  = size.width / (monthly.length - 1);
    final zeroY = toY(0);

    canvas.drawLine(Offset(0, zeroY), Offset(size.width, zeroY),
        Paint()..color = AppColors.darkDivider..strokeWidth = 1.0..style = PaintingStyle.stroke);

    final pts = List.generate(monthly.length, (i) => Offset(i * step, toY(monthly[i])));

    // Fill positive/negative
    for (final isPositive in [true, false]) {
      final color = isPositive ? AppColors.success : AppColors.danger;
      final fill  = Path()..moveTo(pts.first.dx, zeroY);
      for (int i = 0; i < pts.length; i++) {
        if (i == 0) {
          fill.lineTo(pts[i].dx, pts[i].dy);
        } else {
          final cp1 = Offset((pts[i-1].dx + pts[i].dx) / 2, pts[i-1].dy);
          final cp2 = Offset((pts[i-1].dx + pts[i].dx) / 2, pts[i].dy);
          fill.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i].dx, pts[i].dy);
        }
      }
      fill.lineTo(pts.last.dx, zeroY);
      fill.close();

      canvas.save();
      if (isPositive) {
        canvas.clipRect(Rect.fromLTRB(0, 0, size.width, zeroY));
      } else {
        canvas.clipRect(Rect.fromLTRB(0, zeroY, size.width, size.height));
      }
      canvas.drawPath(fill, Paint()..color = color.withOpacity(0.18)..style = PaintingStyle.fill);
      canvas.restore();
    }

    // Colored line segments
    for (int i = 1; i < pts.length; i++) {
      final midY  = (pts[i-1].dy + pts[i].dy) / 2;
      final color = midY < zeroY ? AppColors.success : AppColors.danger;
      final seg   = Path()..moveTo(pts[i-1].dx, pts[i-1].dy);
      final cp1   = Offset((pts[i-1].dx + pts[i].dx) / 2, pts[i-1].dy);
      final cp2   = Offset((pts[i-1].dx + pts[i].dx) / 2, pts[i].dy);
      seg.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i].dx, pts[i].dy);
      canvas.drawPath(seg, Paint()..color = color..strokeWidth = 2.5
          ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    }

    // Dots
    for (int i = 0; i < pts.length; i++) {
      final color = monthly[i] >= 0 ? AppColors.success : AppColors.danger;
      canvas.drawCircle(pts[i], 3.5, Paint()..color = color);
      canvas.drawCircle(pts[i], 3.5, Paint()..color = AppColors.darkSurface
          ..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(covariant _NetProfitPainter old) => old.monthly != monthly;
}

// ── Schedule C Tab ────────────────────────────────────────────────────────────

class _ScheduleCTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ScheduleCTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$');
    final year     = data['year'] as int? ?? DateTime.now().year;

    final totalRevenue  = _d(data['total_revenue']);
    final totalCogs     = _d(data['total_cogs']);
    final grossProfit   = _d(data['gross_profit']);
    final totalExpenses = _d(data['total_expenses']);
    final netProfit     = _d(data['net_profit']);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.07), borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.accent.withOpacity(0.25)),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline, color: AppColors.accent, size: 16),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Guided summary only — not professional tax advice. '
              'Consult a CPA for filing. Aligned with IRS Schedule C (Form 1040).',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5))),
          ]),
        ),

        const SizedBox(height: 20),

        _SchedSection('PART I — INCOME'),
        _SchedLine('Line 1', 'Gross receipts / sales',             currency.format(totalRevenue)),
        _SchedLine('Line 4', 'Cost of goods sold (from Part III)', currency.format(totalCogs)),
        _SchedLine('Line 5', 'Gross profit',                       currency.format(grossProfit), bold: true),

        const SizedBox(height: 20),

        _SchedSection('PART II — EXPENSES'),
        _SchedLine('Line 28', 'Total expenses',       currency.format(totalExpenses), bold: true),
        _SchedLine('Line 31', 'Net profit or (loss)', currency.format(netProfit),
            bold: true, color: netProfit >= 0 ? AppColors.success : AppColors.danger),

        const SizedBox(height: 20),

        _SchedSection('PART III — COST OF GOODS SOLD'),
        _SchedLine('Line 33', 'Inventory method',              'Specific Identification'),
        _SchedLine('Line 41', 'Cost of goods sold',            currency.format(totalCogs), bold: true),

        const SizedBox(height: 28),

        Row(children: [
          Expanded(child: OutlinedButton.icon(
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('Print'),
            onPressed: () => _printPdf(context, year, currency,
                totalRevenue, totalCogs, grossProfit, totalExpenses, netProfit),
          )),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent, foregroundColor: Colors.black),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: Text('Export $year Schedule C'),
            onPressed: () => _exportPdf(context, year, currency,
                totalRevenue, totalCogs, grossProfit, totalExpenses, netProfit),
          )),
        ]),
      ],
    );
  }

  static pw.Document _buildPdf(int year, NumberFormat currency,
      double totalRevenue, double totalCogs, double grossProfit,
      double totalExpenses, double netProfit) {
    final doc      = pw.Document();
    final profColor = netProfit >= 0 ? PdfColors.green700 : PdfColors.red700;

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin:     const pw.EdgeInsets.all(40),
      header:     (_) => _pdfHeader(year),
      footer:     (ctx) => _pdfFooter(ctx),
      build:      (_) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('$year Tax Year', style: pw.TextStyle(color: PdfColors.grey600, fontSize: 10)),
              pw.Text('Schedule C Summary',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('Net Profit / (Loss)',
                  style: pw.TextStyle(color: PdfColors.grey600, fontSize: 10)),
              pw.Text(currency.format(netProfit),
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: profColor)),
            ]),
          ]),
        ),
        pw.SizedBox(height: 20),
        _pdfSectionHeader('PART I — INCOME'),
        _pdfLine('Line 1', 'Gross receipts / sales',             currency.format(totalRevenue)),
        _pdfLine('Line 4', 'Cost of goods sold (from Part III)', currency.format(totalCogs), negative: true),
        _pdfDivider(),
        _pdfLine('Line 5', 'Gross profit',                       currency.format(grossProfit), bold: true),
        pw.SizedBox(height: 16),
        _pdfSectionHeader('PART II — EXPENSES'),
        _pdfLine('Line 28', 'Total expenses',       currency.format(totalExpenses), bold: true),
        _pdfLine('Line 31', 'Net profit or (loss)', currency.format(netProfit),
            bold: true, valueColor: profColor),
        pw.SizedBox(height: 16),
        _pdfSectionHeader('PART III — COST OF GOODS SOLD'),
        _pdfLine('Line 33', 'Inventory method',  'Specific Identification'),
        _pdfDivider(),
        _pdfLine('Line 41', 'Cost of goods sold', currency.format(totalCogs), bold: true),
        pw.SizedBox(height: 20),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Text(
            'This document is a guided summary generated by VendorBoss and does not '
            'constitute professional tax advice. Consult a licensed CPA before filing.',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ),
      ],
    ));
    return doc;
  }

  static pw.Widget _pdfHeader(int year) => pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 8),
    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
    child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text('VendorBoss', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.teal, fontSize: 14)),
      pw.Text('Schedule C Summary — $year', style: pw.TextStyle(color: PdfColors.grey600, fontSize: 10)),
    ]),
  );

  static pw.Widget _pdfFooter(pw.Context ctx) => pw.Container(
    padding: const pw.EdgeInsets.only(top: 6),
    decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300))),
    child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text('Generated by VendorBoss', style: pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
      pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
          style: pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
    ]),
  );

  static pw.Widget _pdfSectionHeader(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6, top: 2),
    child: pw.Text(text, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold,
        color: PdfColors.teal700, letterSpacing: 1.0)),
  );

  static pw.Widget _pdfLine(String line, String label, String value,
      {bool bold = false, bool negative = false, PdfColor? valueColor}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(children: [
        pw.SizedBox(width: 52, child: pw.Text(line,
            style: pw.TextStyle(color: PdfColors.grey500, fontSize: 10))),
        pw.Expanded(child: pw.Text(label, style: pw.TextStyle(fontSize: 11,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
        pw.Text(negative ? '($value)' : value, style: pw.TextStyle(fontSize: 11,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: valueColor ?? (negative ? PdfColors.red700 : PdfColors.black))),
      ]),
    );

  static pw.Widget _pdfDivider() => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Divider(color: PdfColors.grey300, thickness: 0.5));

  static Future<void> _exportPdf(BuildContext context, int year, NumberFormat currency,
      double totalRevenue, double totalCogs, double grossProfit,
      double totalExpenses, double netProfit) async {
    final doc = _buildPdf(year, currency, totalRevenue, totalCogs, grossProfit, totalExpenses, netProfit);
    await Printing.sharePdf(bytes: await doc.save(), filename: 'VendorBoss_ScheduleC_$year.pdf');
  }

  static Future<void> _printPdf(BuildContext context, int year, NumberFormat currency,
      double totalRevenue, double totalCogs, double grossProfit,
      double totalExpenses, double netProfit) async {
    final doc = _buildPdf(year, currency, totalRevenue, totalCogs, grossProfit, totalExpenses, netProfit);
    await Printing.layoutPdf(onLayout: (_) async => doc.save(), name: 'VendorBoss Schedule C $year');
  }
}

// ── Expenses Tab ──────────────────────────────────────────────────────────────

class _ExpensesTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ExpensesTab({required this.data});

  static const _categoryMeta = {
    'table_fee':        _CatMeta('Show / Table Fees',   Icons.storefront_outlined,      AppColors.accent),
    'travel':           _CatMeta('Travel',              Icons.directions_car_outlined,  Color(0xFF7B61FF)),
    'hotel':            _CatMeta('Lodging',             Icons.hotel_outlined,           AppColors.info),
    'food':             _CatMeta('Meals',               Icons.restaurant_outlined,      AppColors.warning),
    'supplies':         _CatMeta('Supplies',            Icons.inventory_2_outlined,     AppColors.success),
    'grading':          _CatMeta('Grading Fees',        Icons.grade_outlined,           Color(0xFFFFD700)),
    'shipping':         _CatMeta('Shipping',            Icons.local_shipping_outlined,  Color(0xFF1DA0F2)),
    'marketplace_fees': _CatMeta('Marketplace Fees',    Icons.percent_outlined,         AppColors.danger),
    'card_purchase':    _CatMeta('Card Purchases',      Icons.style_outlined,           AppColors.textSecondary),
    'other':            _CatMeta('Other',               Icons.more_horiz_outlined,      AppColors.textSecondary),
  };

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$');
    final total    = _d(data['total_expenses']);

    // Note: the financial-summary endpoint doesn't break expenses by category.
    // We show the total and invite the user to check the Expenses section for detail.
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Total YTD Expenses',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 4),
            Text(currency.format(total), style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.warning)),
          ]),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.accent.withOpacity(0.25)),
          ),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, color: AppColors.accent, size: 16),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Detailed expense breakdown by category is available in the Expenses section '
              'of each show. This tab shows your total YTD expenses from all sources.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5))),
          ]),
        ),

        const SizedBox(height: 20),
        const _Label('EXPENSE CATEGORIES'),
        const SizedBox(height: 12),

        // Show a visual breakdown using the meta labels
        ..._categoryMeta.entries.map((entry) {
          final meta = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: meta.color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(meta.icon, color: meta.color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(meta.label,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
              Text('Track in Expenses',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ]),
          );
        }),
      ],
    );
  }
}

class _CatMeta {
  final String label; final IconData icon; final Color color;
  const _CatMeta(this.label, this.icon, this.color);
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _SchedSection extends StatelessWidget {
  final String text; const _SchedSection(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
        color: AppColors.accent, letterSpacing: 1.2)),
  );
}

class _SchedLine extends StatelessWidget {
  final String line, label, value; final bool bold; final Color color;
  const _SchedLine(this.line, this.label, this.value,
      {this.bold = false, this.color = AppColors.textPrimary});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      SizedBox(width: 56, child: Text(line,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11))),
      Expanded(child: Text(label,
          style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.normal, fontSize: 13))),
      Text(value, style: TextStyle(color: color,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: 13)),
    ]),
  );
}

class _FinLine extends StatelessWidget {
  final String label, value; final Color color; final bool bold;
  const _FinLine(this.label, this.value, this.color, {this.bold = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(
          color: AppColors.textSecondary,
          fontWeight: bold ? FontWeight.w700 : FontWeight.normal, fontSize: 13))),
      Text(value, style: TextStyle(color: color,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: 13)),
    ]),
  );
}

class _MetricCard extends StatelessWidget {
  final String label, value; final Color color;
  const _MetricCard(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
    ]),
  );
}

class _Label extends StatelessWidget {
  final String text; const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(
      fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 1.2));
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
