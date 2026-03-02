import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/show.dart';
import '../services/mock_data_service.dart';
import 'sale_screen.dart';
import 'add_expense_screen.dart';

class ShowDetailScreen extends StatefulWidget {
  final Show show;
  const ShowDetailScreen({super.key, required this.show});

  @override
  State<ShowDetailScreen> createState() => _ShowDetailScreenState();
}

class _ShowDetailScreenState extends State<ShowDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final currency   = NumberFormat.currency(symbol: '\$');
  final timeFormat = DateFormat('h:mm a');
  int  _currentTab = 0;

  // Optimistic local state — flips to false when vendor closes the show.
  // Backend call (PATCH /shows/{id} { is_active: false }) goes here when wired.
  bool _isActive = false;

  @override
  void initState() {
    super.initState();
    _isActive = widget.show.isActive;
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() => _currentTab = _tabController.index);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Sale>    get sales    => _isActive ? MockDataService.salesForActiveShow    : MockDataService.salesForShow(widget.show.id);
  List<Expense> get expenses => _isActive ? MockDataService.expensesForActiveShow : MockDataService.expensesForShow(widget.show.id);
  ShowSummary   get summary  => MockDataService.summaryForShow(widget.show, sales, expenses);

  void _openAddExpense() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddExpenseScreen(show: widget.show)),
    );
    if (result == true) setState(() {});
  }

  void _openNewSale() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SaleScreen(show: widget.show)),
    );
  }

  // ── Close show ─────────────────────────────────────────────────────────────

  void _promptCloseShow() {
    final s = summary;
    showModalBottomSheet(
      context:       context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CloseShowSheet(
        show:     widget.show,
        summary:  s,
        currency: currency,
        onConfirm: _closeShow,
      ),
    );
  }

  void _closeShow() {
    // TODO: PATCH /api/v1/shows/{id} — { is_active: false }
    setState(() => _isActive = false);
    Navigator.pop(context); // dismiss bottom sheet

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_outline, color: Colors.black, size: 18),
          const SizedBox(width: 8),
          Text('${widget.show.name} closed. Great show!'),
        ]),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final onExpensesTab = _currentTab == 2;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.show.name),
        actions: [
          // Active badge
          if (_isActive)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:        AppColors.accent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      color:       AppColors.accent,
                      fontSize:    11,
                      fontWeight:  FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),

          // Overflow menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'close_show') _promptCloseShow();
            },
            itemBuilder: (_) => [
              if (_isActive)
                const PopupMenuItem(
                  value: 'close_show',
                  child: Row(children: [
                    Icon(Icons.flag_outlined, size: 18, color: AppColors.warning),
                    SizedBox(width: 10),
                    Text('Close Show'),
                  ]),
                ),
              const PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                  SizedBox(width: 10),
                  Text('Edit Show Details'),
                ]),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller:           _tabController,
          indicatorColor:       AppColors.accent,
          labelColor:           AppColors.accent,
          unselectedLabelColor: AppColors.darkTextSecondary,
          tabs: const [
            Tab(text: 'Summary'),
            Tab(text: 'Sales'),
            Tab(text: 'Expenses'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SummaryTab(show: widget.show, summary: summary, currency: currency, isActive: _isActive),
          _SalesTab(sales: sales, currency: currency, timeFormat: timeFormat),
          _ExpensesTab(
            expenses:      expenses,
            currency:      currency,
            timeFormat:    timeFormat,
            onAddExpense:  _isActive ? _openAddExpense : null,
          ),
        ],
      ),
      floatingActionButton: _isActive
          ? FloatingActionButton.extended(
              backgroundColor: onExpensesTab ? AppColors.warning : AppColors.accent,
              foregroundColor: Colors.black,
              icon:  Icon(onExpensesTab ? Icons.receipt_long : Icons.point_of_sale),
              label: Text(
                onExpensesTab ? 'Add Expense' : 'New Sale',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              onPressed: onExpensesTab ? _openAddExpense : _openNewSale,
            )
          : null,
    );
  }
}

// ── Close Show Bottom Sheet ────────────────────────────────────────────────────

class _CloseShowSheet extends StatelessWidget {
  final Show show;
  final ShowSummary summary;
  final NumberFormat currency;
  final VoidCallback onConfirm;

  const _CloseShowSheet({
    required this.show,
    required this.summary,
    required this.currency,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final profitable   = summary.netProfit >= 0;
    final profitColor  = profitable ? AppColors.success : AppColors.danger;
    final dateFormat   = DateFormat('MMMM d, yyyy');
    final roiData      = MockDataService.showROIData
        .where((d) => d.show.id == show.id)
        .firstOrNull;
    final roi          = roiData?.roi;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color:        AppColors.darkDivider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Header
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:        AppColors.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.flag_outlined,
                    color: AppColors.warning, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Close Show',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    Text(dateFormat.format(show.date),
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ]),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),

            // Final P&L summary
            const Text('FINAL SUMMARY',
                style: TextStyle(
                  fontSize:      10,
                  fontWeight:    FontWeight.w800,
                  color:         AppColors.textSecondary,
                  letterSpacing: 1.2,
                )),
            const SizedBox(height: 12),

            // Revenue / expenses / net row
            Row(children: [
              Expanded(child: _SummaryTile(
                label: 'Revenue',
                value: currency.format(summary.totalSales),
                color: AppColors.accent,
              )),
              Expanded(child: _SummaryTile(
                label: 'Expenses',
                value: currency.format(summary.totalExpenses),
                color: AppColors.warning,
              )),
              Expanded(child: _SummaryTile(
                label: 'Net Profit',
                value: currency.format(summary.netProfit),
                color: profitColor,
              )),
            ]),

            const SizedBox(height: 12),

            // Transactions / cards sold / ROI row
            Row(children: [
              Expanded(child: _SummaryTile(
                label: 'Transactions',
                value: '${summary.totalTransactions}',
                color: AppColors.textSecondary,
              )),
              Expanded(child: _SummaryTile(
                label: 'Cards Sold',
                value: '${summary.cardsSold}',
                color: AppColors.textSecondary,
              )),
              Expanded(child: _SummaryTile(
                label: 'ROI',
                value: roi != null ? '${roi.toStringAsFixed(0)}%' : '—',
                color: roi != null
                    ? (roi >= 100 ? AppColors.success : roi >= 0 ? AppColors.warning : AppColors.danger)
                    : AppColors.textSecondary,
              )),
            ]),

            const SizedBox(height: 20),

            // Verdict banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color:        profitColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border:       Border.all(color: profitColor.withOpacity(0.3)),
              ),
              child: Row(children: [
                Icon(
                  profitable ? Icons.thumb_up_outlined : Icons.thumb_down_outlined,
                  color: profitColor,
                  size:  18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _verdictText(roi, summary.netProfit),
                    style: TextStyle(
                      color:      profitColor,
                      fontSize:   13,
                      fontWeight: FontWeight.w600,
                      height:     1.4,
                    ),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 24),

            // Warning note
            const Text(
              'Closing the show will lock the record. You can still view history '
              'but will not be able to add sales or expenses.',
              style: TextStyle(
                  color:    AppColors.textSecondary,
                  fontSize: 12,
                  height:   1.5),
            ),

            const SizedBox(height: 20),

            // Buttons
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.black,
                  ),
                  icon:     const Icon(Icons.flag_outlined, size: 18),
                  label:    const Text('Close Show',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: onConfirm,
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  String _verdictText(double? roi, double net) {
    if (net < 0) return 'This show ran at a loss. Review your pricing and attendance costs before returning.';
    if (roi == null) return 'Show closed successfully.';
    if (roi >= 300) return 'Exceptional show — one of your best. Put it at the top of next year\'s calendar.';
    if (roi >= 150) return 'Great show — solid return on your time and cost. Worth repeating.';
    if (roi >= 75)  return 'Profitable show. Consider what drove your best sales to repeat them.';
    return 'Slim margins. Think about your table cost and inventory mix before booking again.';
  }
}

class _SummaryTile extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SummaryTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
    ],
  );
}

// ── Summary Tab ───────────────────────────────────────────────────────────────

class _SummaryTab extends StatelessWidget {
  final Show show;
  final ShowSummary summary;
  final NumberFormat currency;
  final bool isActive;

  const _SummaryTab({
    required this.show,
    required this.summary,
    required this.currency,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Closed banner
        if (!isActive)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color:        AppColors.textSecondary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.textSecondary.withOpacity(0.2)),
            ),
            child: const Row(children: [
              Icon(Icons.lock_outline, size: 14, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Text('This show is closed. Record is read-only.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ]),
          ),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(Icons.calendar_today, dateFormat.format(show.date)),
                if (show.venue != null)
                  _InfoRow(Icons.location_on_outlined, show.venue!),
                if (show.location != null)
                  _InfoRow(Icons.map_outlined, show.location!),
                if (show.tableNumber != null)
                  _InfoRow(Icons.table_restaurant_outlined, 'Table ${show.tableNumber}'),
                if (show.tableCost != null)
                  _InfoRow(Icons.receipt_outlined, 'Table fee: ${currency.format(show.tableCost)}'),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),
        const _SectionLabel('Financials'),
        const SizedBox(height: 8),

        Row(children: [
          Expanded(child: _BigStatCard(
            label: 'Total Sales',
            value: currency.format(summary.totalSales),
            color: AppColors.success,
            icon:  Icons.trending_up,
          )),
          const SizedBox(width: 12),
          Expanded(child: _BigStatCard(
            label: 'Total Expenses',
            value: currency.format(summary.totalExpenses),
            color: AppColors.warning,
            icon:  Icons.trending_down,
          )),
        ]),

        const SizedBox(height: 12),

        _BigStatCard(
          label: 'Net Profit',
          value: currency.format(summary.netProfit),
          color: summary.netProfit >= 0 ? AppColors.accent : AppColors.danger,
          icon:  summary.netProfit >= 0 ? Icons.account_balance_wallet : Icons.money_off,
          large: true,
        ),

        const SizedBox(height: 16),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(child: _MiniStat(
                  '${summary.totalTransactions}', 'Transactions', AppColors.info)),
              Expanded(child: _MiniStat(
                  '${summary.cardsSold}', 'Cards Sold', AppColors.accent)),
              Expanded(child: _MiniStat(
                summary.totalTransactions > 0
                    ? currency.format(summary.totalSales / summary.totalTransactions)
                    : '\$0',
                'Avg Sale',
                AppColors.success,
              )),
            ]),
          ),
        ),

        const SizedBox(height: 80),
      ],
    );
  }
}

// ── Sales Tab ─────────────────────────────────────────────────────────────────

class _SalesTab extends StatelessWidget {
  final List<Sale> sales;
  final NumberFormat currency;
  final DateFormat timeFormat;

  const _SalesTab({required this.sales, required this.currency, required this.timeFormat});

  @override
  Widget build(BuildContext context) {
    if (sales.isEmpty) {
      return const Center(
        child: Text('No sales yet',
            style: TextStyle(color: AppColors.darkTextSecondary)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sales.length,
      itemBuilder: (context, index) {
        final sale = sales[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              CircleAvatar(
                backgroundColor: sale.isBulkSale
                    ? AppColors.warning.withOpacity(0.15)
                    : AppColors.accent.withOpacity(0.15),
                child: Icon(
                  sale.isBulkSale ? Icons.inventory_2_outlined : Icons.style,
                  color: sale.isBulkSale ? AppColors.warning : AppColors.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sale.isBulkSale
                          ? sale.bulkDescription ?? 'Bulk Sale'
                          : sale.items.map((i) => i.cardName).join(', '),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${timeFormat.format(sale.saleDate)} · ${sale.paymentMethod.toUpperCase()}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.darkTextSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                currency.format(sale.totalAmount),
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.success),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ── Expenses Tab ──────────────────────────────────────────────────────────────

class _ExpensesTab extends StatelessWidget {
  final List<Expense> expenses;
  final NumberFormat currency;
  final DateFormat timeFormat;
  final VoidCallback? onAddExpense;

  const _ExpensesTab({
    required this.expenses,
    required this.currency,
    required this.timeFormat,
    this.onAddExpense,
  });

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_outlined,
                size: 48, color: AppColors.darkTextLight),
            const SizedBox(height: 12),
            const Text('No expenses logged yet',
                style: TextStyle(color: AppColors.darkTextSecondary)),
            if (onAddExpense != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon:     const Icon(Icons.add),
                label:    const Text('Add First Expense'),
                onPressed: onAddExpense,
              ),
            ],
          ],
        ),
      );
    }

    final total = expenses.fold(0.0, (s, e) => s + e.amount);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppColors.darkSurfaceElevated,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${expenses.length} expense${expenses.length == 1 ? '' : 's'}',
                style: const TextStyle(color: AppColors.darkTextSecondary),
              ),
              Text(
                currency.format(total),
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize:   18,
                    color:      AppColors.warning),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: expenses.length,
            itemBuilder: (context, index) {
              final expense = expenses[index];
              return Card(
                margin:        const EdgeInsets.only(bottom: 10),
                clipBehavior:  Clip.hardEdge,
                child: InkWell(
                  onTap: onAddExpense != null
                      ? () => _openEdit(context, expense)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      CircleAvatar(
                        backgroundColor: AppColors.warning.withOpacity(0.15),
                        child: Icon(_typeIcon(expense.type),
                            color: AppColors.warning, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(expense.description,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                              '${expense.typeDisplay} · ${timeFormat.format(expense.expenseDate)}',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.darkTextSecondary),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            currency.format(expense.amount),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize:   16,
                                color:      AppColors.warning),
                          ),
                          Text(
                            expense.paymentMethod.toUpperCase(),
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.darkTextSecondary),
                          ),
                        ],
                      ),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openEdit(BuildContext context, Expense expense) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddExpenseScreen(existingExpense: expense)),
    );
  }

  IconData _typeIcon(String type) => switch (type) {
    'table_fee'    => Icons.table_restaurant_outlined,
    'travel'       => Icons.directions_car_outlined,
    'hotel'        => Icons.hotel_outlined,
    'food'         => Icons.restaurant_outlined,
    'card_purchase'=> Icons.style_outlined,
    'supplies'     => Icons.inventory_2_outlined,
    'grading'      => Icons.verified_outlined,
    'shipping'     => Icons.local_shipping_outlined,
    _              => Icons.receipt_outlined,
  };
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize:      11,
      fontWeight:    FontWeight.w700,
      color:         AppColors.darkTextSecondary,
      letterSpacing: 1.5,
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Icon(icon, size: 16, color: AppColors.darkTextSecondary),
      const SizedBox(width: 10),
      Expanded(child: Text(text,
          style: const TextStyle(color: AppColors.darkTextSecondary))),
    ]),
  );
}

class _BigStatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  final bool large;

  const _BigStatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(
                color: color, fontSize: large ? 24 : 18, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(
                color: AppColors.darkTextSecondary, fontSize: 12)),
          ],
        ),
      ]),
    ),
  );
}

class _MiniStat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _MiniStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: TextStyle(
          fontWeight: FontWeight.w800, fontSize: 18, color: color)),
      Text(label, style: const TextStyle(
          fontSize: 11, color: AppColors.darkTextSecondary)),
    ],
  );
}
