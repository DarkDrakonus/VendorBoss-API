import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:math' as math;
import '../../theme/app_theme.dart';
import '../../services/mock_data_service.dart';
import '../../models/show.dart';

class FinancialSummaryReport extends StatefulWidget {
  final int startTab;
  const FinancialSummaryReport({super.key, this.startTab = 0});

  @override
  State<FinancialSummaryReport> createState() => _FinancialSummaryReportState();
}

class _FinancialSummaryReportState extends State<FinancialSummaryReport>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this, initialIndex: widget.startTab);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Summary'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor:       AppColors.accent,
          labelColor:           AppColors.accent,
          unselectedLabelColor: AppColors.darkTextSecondary,
          tabs: const [
            Tab(text: 'YTD Overview'),
            Tab(text: 'Schedule C'),
            Tab(text: 'Expenses'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _YTDTab(),
          _ScheduleCTab(),
          _ExpensesTab(),
        ],
      ),
    );
  }
}

// ── YTD Overview ──────────────────────────────────────────────────────────────

class _YTDTab extends StatelessWidget {
  const _YTDTab();

  static const int _months = 6;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$');
    final s        = MockDataService.ytdFinancialSummary;
    final year     = DateTime.now().year;

    // Build monthly net profit for trend chart
    final allSales    = MockDataService.allSalesHistory;
    final allExpenses = MockDataService.allExpensesHistory;
    final monthly     = _buildMonthlyNetProfit(allSales, allExpenses, _months);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [

        // ── Hero net profit ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: (s.netProfit >= 0 ? AppColors.success : AppColors.danger)
                .withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: (s.netProfit >= 0 ? AppColors.success : AppColors.danger)
                  .withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              Text('$year Net Profit',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Text(
                currency.format(s.netProfit),
                style: TextStyle(
                  fontSize:   36,
                  fontWeight: FontWeight.w900,
                  color: s.netProfit >= 0 ? AppColors.success : AppColors.danger,
                ),
              ),
              const SizedBox(height: 4),
              Text('${s.transactionCount} transactions',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Monthly net profit trend ────────────────────────────────────
        const _Label('NET PROFIT — LAST 6 MONTHS'),
        const SizedBox(height: 4),
        const Text('Revenue minus COGS and expenses each month',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 12),
        _NetProfitChart(monthly: monthly, months: _months),

        const SizedBox(height: 24),

        // ── Income statement ────────────────────────────────────────────
        const _Label('INCOME STATEMENT'),
        const SizedBox(height: 10),

        _FinLine('Gross Revenue',             currency.format(s.grossRevenue),  AppColors.textPrimary),
        _FinLine('Cost of Goods Sold (COGS)', '− ${currency.format(s.cogs)}',   AppColors.danger),
        const Divider(height: 20),
        _FinLine('Gross Profit',    currency.format(s.grossProfit), AppColors.accent, bold: true),
        const SizedBox(height: 8),
        _FinLine('Total Expenses',  '− ${currency.format(s.totalExpenses)}',    AppColors.warning),
        const Divider(height: 20),
        _FinLine('Net Profit',      currency.format(s.netProfit),
            s.netProfit >= 0 ? AppColors.success : AppColors.danger, bold: true),

        const SizedBox(height: 24),
        const _Label('MARGINS'),
        const SizedBox(height: 10),

        Row(children: [
          Expanded(child: _MetricCard(
            label: 'Gross Margin',
            value: s.grossRevenue > 0
                ? '${((s.grossProfit / s.grossRevenue) * 100).toStringAsFixed(1)}%'
                : '—',
            color: AppColors.accent,
          )),
          const SizedBox(width: 10),
          Expanded(child: _MetricCard(
            label: 'Net Margin',
            value: s.grossRevenue > 0
                ? '${((s.netProfit / s.grossRevenue) * 100).toStringAsFixed(1)}%'
                : '—',
            color: s.netProfit >= 0 ? AppColors.success : AppColors.danger,
          )),
          const SizedBox(width: 10),
          Expanded(child: _MetricCard(
            label: 'Expense Ratio',
            value: s.grossRevenue > 0
                ? '${((s.totalExpenses / s.grossRevenue) * 100).toStringAsFixed(1)}%'
                : '—',
            color: AppColors.warning,
          )),
        ]),

        const SizedBox(height: 24),

        // ── IRS threshold warning ───────────────────────────────────────
        if (s.grossRevenue >= 500)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:        AppColors.warning.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border:       Border.all(color: AppColors.warning.withOpacity(0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_outlined,
                    color: AppColors.warning, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('IRS Threshold Reminder',
                          style: TextStyle(
                              color:      AppColors.warning,
                              fontWeight: FontWeight.w700,
                              fontSize:   13)),
                      const SizedBox(height: 4),
                      Text(
                        s.grossRevenue >= 600
                            ? 'Your $year gross revenue of ${currency.format(s.grossRevenue)} '
                              'exceeds the \$600 reporting threshold. Platforms like TCGPlayer, '
                              'eBay, and Whatnot will file a 1099-K with the IRS. Ensure your '
                              'Schedule C is accurate.'
                            : 'Your $year gross revenue of ${currency.format(s.grossRevenue)} '
                              'is approaching the \$600 reporting threshold for $year. Track carefully.',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Builds monthly net profit (revenue − COGS − expenses) for the last N months.
  static List<double> _buildMonthlyNetProfit(
      List<Sale> sales, List<Expense> expenses, int months) {
    final now     = DateTime.now();
    final revenue = List<double>.filled(months, 0);
    final cogs    = List<double>.filled(months, 0);
    final exp     = List<double>.filled(months, 0);

    for (final s in sales) {
      final diff = (now.year - s.saleDate.year) * 12 + now.month - s.saleDate.month;
      if (diff < 0 || diff >= months) continue;
      final idx = months - 1 - diff;
      revenue[idx] += s.totalAmount;
      for (final item in s.items) {
        final inv = MockDataService.inventoryItems
            .where((i) => i.id == item.inventoryItemId)
            .firstOrNull;
        if (inv?.purchasePrice != null) {
          cogs[idx] += inv!.purchasePrice! * item.quantity;
        }
      }
    }

    for (final e in expenses) {
      final diff = (now.year - e.expenseDate.year) * 12 + now.month - e.expenseDate.month;
      if (diff < 0 || diff >= months) continue;
      exp[months - 1 - diff] += e.amount;
    }

    return List.generate(months, (i) => revenue[i] - cogs[i] - exp[i]);
  }
}

// ── Monthly net profit chart ──────────────────────────────────────────────────

class _NetProfitChart extends StatelessWidget {
  final List<double> monthly;
  final int months;

  const _NetProfitChart({required this.monthly, required this.months});

  @override
  Widget build(BuildContext context) {
    final now         = DateTime.now();
    final monthLabels = List.generate(months, (i) {
      final dt = DateTime(now.year, now.month - (months - 1 - i));
      return DateFormat('MMM').format(dt);
    });

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
      decoration: BoxDecoration(
        color:        AppColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Chart area
          SizedBox(
            height: 110,
            child: CustomPaint(
              painter: _NetProfitPainter(monthly: monthly),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 6),
          // X-axis labels
          Row(
            children: monthLabels.map((m) => Expanded(
              child: Text(m,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 10)),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _NetProfitPainter extends CustomPainter {
  final List<double> monthly;
  const _NetProfitPainter({required this.monthly});

  @override
  void paint(Canvas canvas, Size size) {
    if (monthly.length < 2) return;

    final maxVal = monthly.reduce(math.max);
    final minVal = monthly.reduce(math.min);
    // Ensure zero is always visible in range
    final rangeMax = math.max(maxVal, 0.0);
    final rangeMin = math.min(minVal, 0.0);
    final range    = (rangeMax - rangeMin).clamp(1.0, double.infinity);

    double toY(double val) =>
        size.height - ((val - rangeMin) / range) * size.height * 0.85 - 4;

    final step  = size.width / (monthly.length - 1);
    final zeroY = toY(0);

    // Zero line
    canvas.drawLine(
      Offset(0, zeroY),
      Offset(size.width, zeroY),
      Paint()
        ..color       = AppColors.darkDivider
        ..strokeWidth = 1.0
        ..style       = PaintingStyle.stroke,
    );

    // Build points
    final pts = <Offset>[
      for (int i = 0; i < monthly.length; i++)
        Offset(i * step, toY(monthly[i]))
    ];

    // Fill above/below zero separately
    for (final isPositive in [true, false]) {
      final color = isPositive ? AppColors.success : AppColors.danger;
      final fill  = Path();
      fill.moveTo(pts.first.dx, zeroY);

      for (int i = 0; i < pts.length; i++) {
        final cp1 = i > 0
            ? Offset((pts[i-1].dx + pts[i].dx) / 2, pts[i-1].dy)
            : pts[i];
        final cp2 = i > 0
            ? Offset((pts[i-1].dx + pts[i].dx) / 2, pts[i].dy)
            : pts[i];
        if (i == 0) {
          fill.lineTo(pts[i].dx, pts[i].dy);
        } else {
          fill.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i].dx, pts[i].dy);
        }
      }
      fill.lineTo(pts.last.dx, zeroY);
      fill.close();

      canvas.save();
      // Clip to positive or negative half
      if (isPositive) {
        canvas.clipRect(Rect.fromLTRB(0, 0, size.width, zeroY));
      } else {
        canvas.clipRect(Rect.fromLTRB(0, zeroY, size.width, size.height));
      }
      canvas.drawPath(fill, Paint()
        ..color = color.withOpacity(0.18)
        ..style = PaintingStyle.fill);
      canvas.restore();
    }

    // Line
    final linePath = Path();
    for (int i = 0; i < pts.length; i++) {
      if (i == 0) {
        linePath.moveTo(pts[i].dx, pts[i].dy);
      } else {
        final cp1 = Offset((pts[i-1].dx + pts[i].dx) / 2, pts[i-1].dy);
        final cp2 = Offset((pts[i-1].dx + pts[i].dx) / 2, pts[i].dy);
        linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i].dx, pts[i].dy);
      }
    }

    // Draw line segments colored by profit/loss
    for (int i = 1; i < pts.length; i++) {
      final midY  = (pts[i-1].dy + pts[i].dy) / 2;
      final color = midY < zeroY ? AppColors.success : AppColors.danger;
      final seg   = Path()
        ..moveTo(pts[i-1].dx, pts[i-1].dy);
      final cp1 = Offset((pts[i-1].dx + pts[i].dx) / 2, pts[i-1].dy);
      final cp2 = Offset((pts[i-1].dx + pts[i].dx) / 2, pts[i].dy);
      seg.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i].dx, pts[i].dy);
      canvas.drawPath(seg, Paint()
        ..color       = color
        ..strokeWidth = 2.5
        ..style       = PaintingStyle.stroke
        ..strokeCap   = StrokeCap.round);
    }

    // Dots
    for (int i = 0; i < pts.length; i++) {
      final color = monthly[i] >= 0 ? AppColors.success : AppColors.danger;
      canvas.drawCircle(pts[i], 3.5, Paint()..color = color);
      canvas.drawCircle(pts[i], 3.5, Paint()
        ..color       = AppColors.darkSurface
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(covariant _NetProfitPainter old) => old.monthly != monthly;
}

// ── Schedule C Tab ────────────────────────────────────────────────────────────

class _ScheduleCTab extends StatelessWidget {
  const _ScheduleCTab();

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$');
    final s        = MockDataService.ytdFinancialSummary;
    final year     = DateTime.now().year;

    final advertising = s.expenseByCategory['advertising']       ?? 0;
    final carTravel   = s.expenseByCategory['travel']            ?? 0;
    final meals       = (s.expenseByCategory['food']             ?? 0) * 0.5;
    final supplies    = s.expenseByCategory['supplies']          ?? 0;
    final otherExp    = (s.expenseByCategory['shipping']         ?? 0)
                      + (s.expenseByCategory['grading']          ?? 0)
                      + (s.expenseByCategory['marketplace_fees'] ?? 0);
    final tableFees   = s.expenseByCategory['table_fee']         ?? 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [

        // ── Disclaimer ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:        AppColors.accent.withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
            border:       Border.all(color: AppColors.accent.withOpacity(0.25)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.accent, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Guided summary only — not professional tax advice. '
                  'Consult a CPA for filing. Aligned with IRS Schedule C '
                  '(Form 1040) for sole proprietors.',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Part I ────────────────────────────────────────────────────
        _SchedSection('PART I — INCOME'),
        _SchedLine('Line 1',  'Gross receipts / sales',             currency.format(s.grossRevenue)),
        _SchedLine('Line 4',  'Cost of goods sold (from Part III)', currency.format(s.cogs)),
        _SchedLine('Line 5',  'Gross profit',                       currency.format(s.grossProfit), bold: true),

        const SizedBox(height: 20),

        // ── Part II ───────────────────────────────────────────────────
        _SchedSection('PART II — EXPENSES'),
        _SchedLine('Line 8',   'Advertising',                          currency.format(advertising)),
        _SchedLine('Line 24a', 'Business meals (50% deductible)',       currency.format(meals)),
        _SchedLine('Line 24b', 'Travel',                               currency.format(carTravel)),
        _SchedLine('Line 22',  'Supplies',                             currency.format(supplies)),
        _SchedLine('Line 27',  'Other (show fees, grading, shipping)',  currency.format(tableFees + otherExp)),
        const Divider(height: 20),
        _SchedLine('Line 28',  'Total expenses',   currency.format(s.totalExpenses), bold: true),
        _SchedLine('Line 31',  'Net profit or (loss)', currency.format(s.netProfit),
            bold: true,
            color: s.netProfit >= 0 ? AppColors.success : AppColors.danger),

        const SizedBox(height: 20),

        // ── Part III ──────────────────────────────────────────────────
        _SchedSection('PART III — COST OF GOODS SOLD'),
        _SchedLine('Line 33', 'Inventory method',              'Specific Identification'),
        _SchedLine('Line 35', 'Inventory at beginning of year', '—'),
        _SchedLine('Line 36', 'Purchases',                     '—'),
        _SchedLine('Line 41', 'Cost of goods sold',            currency.format(s.cogs), bold: true),

        const SizedBox(height: 28),

        // ── Export / Print buttons ────────────────────────────────────
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              icon:  const Icon(Icons.print_outlined, size: 18),
              label: const Text('Print'),
              onPressed: () => _printScheduleC(context, s, year, currency,
                  advertising, meals, carTravel, supplies, tableFees, otherExp),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
              ),
              icon:  const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: Text('Export $year Schedule C'),
              onPressed: () => _exportScheduleC(context, s, year, currency,
                  advertising, meals, carTravel, supplies, tableFees, otherExp),
            ),
          ),
        ]),
      ],
    );
  }

  // ── PDF document builder ────────────────────────────────────────────────

  static pw.Document _buildPdf(
    FinancialSummary s,
    int year,
    NumberFormat currency,
    double advertising,
    double meals,
    double carTravel,
    double supplies,
    double tableFees,
    double otherExp,
  ) {
    final doc       = pw.Document();
    final profColor = s.netProfit >= 0 ? PdfColors.green700 : PdfColors.red700;

    doc.addPage(
      pw.MultiPage(
        pageFormat:  PdfPageFormat.letter,
        margin:      const pw.EdgeInsets.all(40),
        header:      (context) => _pdfHeader(year),
        footer:      (context) => _pdfFooter(context),
        build:       (context) => [

          // ── Hero ───────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('$year Tax Year',
                        style: pw.TextStyle(
                            color:      PdfColors.grey600,
                            fontSize:   10)),
                    pw.Text('Schedule C Summary',
                        style: pw.TextStyle(
                            fontSize:   18,
                            fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Net Profit / (Loss)',
                        style: pw.TextStyle(color: PdfColors.grey600, fontSize: 10)),
                    pw.Text(currency.format(s.netProfit),
                        style: pw.TextStyle(
                            fontSize:   20,
                            fontWeight: pw.FontWeight.bold,
                            color:      profColor)),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // ── Part I ─────────────────────────────────────────────────
          _pdfSectionHeader('PART I — INCOME'),
          _pdfLine('Line 1',  'Gross receipts / sales',              currency.format(s.grossRevenue)),
          _pdfLine('Line 4',  'Cost of goods sold (from Part III)',   currency.format(s.cogs), negative: true),
          _pdfDivider(),
          _pdfLine('Line 5',  'Gross profit',                        currency.format(s.grossProfit), bold: true),

          pw.SizedBox(height: 16),

          // ── Part II ────────────────────────────────────────────────
          _pdfSectionHeader('PART II — EXPENSES'),
          _pdfLine('Line 8',   'Advertising',                         currency.format(advertising)),
          _pdfLine('Line 24a', 'Business meals (50% deductible)',      currency.format(meals)),
          _pdfLine('Line 24b', 'Travel',                              currency.format(carTravel)),
          _pdfLine('Line 22',  'Supplies',                            currency.format(supplies)),
          _pdfLine('Line 27',  'Other expenses (show fees, grading, shipping)', currency.format(tableFees + otherExp)),
          _pdfDivider(),
          _pdfLine('Line 28',  'Total expenses',    currency.format(s.totalExpenses), bold: true),
          _pdfLine('Line 31',  'Net profit or (loss)', currency.format(s.netProfit),
              bold: true, valueColor: profColor),

          pw.SizedBox(height: 16),

          // ── Part III ───────────────────────────────────────────────
          _pdfSectionHeader('PART III — COST OF GOODS SOLD'),
          _pdfLine('Line 33', 'Inventory method',               'Specific Identification'),
          _pdfLine('Line 35', 'Inventory at beginning of year',  '—'),
          _pdfLine('Line 36', 'Purchases',                      '—'),
          _pdfDivider(),
          _pdfLine('Line 41', 'Cost of goods sold',             currency.format(s.cogs), bold: true),

          pw.SizedBox(height: 20),

          // ── Disclaimer ─────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color:        PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              'This document is a guided summary generated by VendorBoss and does not '
              'constitute professional tax advice. Consult a licensed CPA or tax professional '
              'before filing. Line numbers reference IRS Schedule C (Form 1040).',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ),
        ],
      ),
    );

    return doc;
  }

  // ── PDF helper widgets ──────────────────────────────────────────────────

  static pw.Widget _pdfHeader(int year) => pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 8),
    decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('VendorBoss',
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color:      PdfColors.teal,
                fontSize:   14)),
        pw.Text('Schedule C Summary — $year',
            style: pw.TextStyle(color: PdfColors.grey600, fontSize: 10)),
      ],
    ),
  );

  static pw.Widget _pdfFooter(pw.Context context) => pw.Container(
    padding: const pw.EdgeInsets.only(top: 6),
    decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300))),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('Generated by VendorBoss',
            style: pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
        pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
      ],
    ),
  );

  static pw.Widget _pdfSectionHeader(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6, top: 2),
    child: pw.Text(text,
        style: pw.TextStyle(
            fontSize:   9,
            fontWeight: pw.FontWeight.bold,
            color:      PdfColors.teal700,
            letterSpacing: 1.0)),
  );

  static pw.Widget _pdfLine(
    String line,
    String label,
    String value, {
    bool bold = false,
    bool negative = false,
    PdfColor? valueColor,
  }) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(children: [
        pw.SizedBox(
          width: 52,
          child: pw.Text(line,
              style: pw.TextStyle(color: PdfColors.grey500, fontSize: 10)),
        ),
        pw.Expanded(
          child: pw.Text(label,
              style: pw.TextStyle(
                  fontSize:   11,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ),
        pw.Text(
          negative ? '(${value})' : value,
          style: pw.TextStyle(
              fontSize:   11,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color:      valueColor ??
                  (negative ? PdfColors.red700 : PdfColors.black)),
        ),
      ]),
    );

  static pw.Widget _pdfDivider() => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Divider(color: PdfColors.grey300, thickness: 0.5),
  );

  // ── Actions ─────────────────────────────────────────────────────────────

  static Future<void> _exportScheduleC(
    BuildContext context,
    FinancialSummary s,
    int year,
    NumberFormat currency,
    double advertising,
    double meals,
    double carTravel,
    double supplies,
    double tableFees,
    double otherExp,
  ) async {
    final doc = _buildPdf(s, year, currency, advertising, meals,
        carTravel, supplies, tableFees, otherExp);

    await Printing.sharePdf(
      bytes:    await doc.save(),
      filename: 'VendorBoss_ScheduleC_$year.pdf',
    );
  }

  static Future<void> _printScheduleC(
    BuildContext context,
    FinancialSummary s,
    int year,
    NumberFormat currency,
    double advertising,
    double meals,
    double carTravel,
    double supplies,
    double tableFees,
    double otherExp,
  ) async {
    final doc = _buildPdf(s, year, currency, advertising, meals,
        carTravel, supplies, tableFees, otherExp);

    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name:     'VendorBoss Schedule C $year',
    );
  }
}

// ── Expenses Tab ──────────────────────────────────────────────────────────────

class _ExpensesTab extends StatelessWidget {
  const _ExpensesTab();

  static const _categoryMeta = {
    'table_fee':        _CatMeta('Show / Table Fees',   Icons.storefront_outlined,       AppColors.accent),
    'travel':           _CatMeta('Travel',              Icons.directions_car_outlined,   Color(0xFF7B61FF)),
    'hotel':            _CatMeta('Lodging',             Icons.hotel_outlined,            AppColors.info),
    'food':             _CatMeta('Meals',               Icons.restaurant_outlined,       AppColors.warning),
    'supplies':         _CatMeta('Supplies',            Icons.inventory_2_outlined,      AppColors.success),
    'grading':          _CatMeta('Grading Fees',        Icons.grade_outlined,            Color(0xFFFFD700)),
    'shipping':         _CatMeta('Shipping',            Icons.local_shipping_outlined,   Color(0xFF1DA0F2)),
    'marketplace_fees': _CatMeta('Marketplace Fees',    Icons.percent_outlined,          AppColors.danger),
    'card_purchase':    _CatMeta('Card Purchases',      Icons.style_outlined,            AppColors.textSecondary),
    'other':            _CatMeta('Other',               Icons.more_horiz_outlined,       AppColors.textSecondary),
  };

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$');
    final s        = MockDataService.ytdFinancialSummary;
    final total    = s.totalExpenses;

    final sorted = s.expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:        AppColors.darkSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total YTD Expenses',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 4),
                Text(currency.format(total),
                    style: const TextStyle(
                        fontSize:   24,
                        fontWeight: FontWeight.w900,
                        color:      AppColors.warning)),
              ],
            )),
            Text('${sorted.length} categories',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ]),
        ),

        const SizedBox(height: 20),
        const _Label('BY CATEGORY'),
        const SizedBox(height: 12),

        ...sorted.map((entry) {
          final meta = _categoryMeta[entry.key] ??
              const _CatMeta('Other', Icons.more_horiz_outlined,
                  AppColors.textSecondary);
          final pct  = total > 0 ? entry.value / total : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color:        meta.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(meta.icon, color: meta.color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text(meta.label,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13))),
                        Text(currency.format(entry.value),
                            style: TextStyle(
                                color:      meta.color,
                                fontWeight: FontWeight.w700,
                                fontSize:   13)),
                      ]),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value:           pct,
                          minHeight:       5,
                          backgroundColor: AppColors.darkSurfaceElevated,
                          valueColor:      AlwaysStoppedAnimation(meta.color),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _CatMeta {
  final String label;
  final IconData icon;
  final Color color;
  const _CatMeta(this.label, this.icon, this.color);
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _SchedSection extends StatelessWidget {
  final String text;
  const _SchedSection(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: const TextStyle(
        fontSize:      10,
        fontWeight:    FontWeight.w800,
        color:         AppColors.accent,
        letterSpacing: 1.2)),
  );
}

class _SchedLine extends StatelessWidget {
  final String line, label, value;
  final bool bold;
  final Color color;
  const _SchedLine(this.line, this.label, this.value,
      {this.bold = false, this.color = AppColors.textPrimary});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      SizedBox(width: 56,
          child: Text(line,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11))),
      Expanded(child: Text(label, style: TextStyle(
          fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
          fontSize:   13))),
      Text(value, style: TextStyle(
          color:      color,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          fontSize:   13)),
    ]),
  );
}

class _FinLine extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool bold;
  const _FinLine(this.label, this.value, this.color, {this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
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

class _MetricCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MetricCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
        color: AppColors.darkSurface, borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(
          color: AppColors.textSecondary, fontSize: 10)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(
          color: color, fontWeight: FontWeight.w800, fontSize: 16)),
    ]),
  );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize:      10,
          fontWeight:    FontWeight.w800,
          color:         AppColors.textSecondary,
          letterSpacing: 1.2));
}
