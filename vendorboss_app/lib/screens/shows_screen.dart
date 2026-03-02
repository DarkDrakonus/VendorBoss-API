import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/mock_data_service.dart';
import '../models/show.dart';
import 'show_detail_screen.dart';

class ShowsScreen extends StatelessWidget {
  const ShowsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shows = MockDataService.shows;
    final activeShows = shows.where((s) => s.isActive).toList();
    final pastShows = shows.where((s) => !s.isActive).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shows'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Show',
            onPressed: () => _showCreateShowSheet(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (activeShows.isNotEmpty) ...[
            const _SectionHeader('Active Show'),
            const SizedBox(height: 8),
            ...activeShows.map((s) => _ShowCard(show: s, isActive: true)),
            const SizedBox(height: 20),
          ],
          const _SectionHeader('Past Shows'),
          const SizedBox(height: 8),
          if (pastShows.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No past shows yet.\nCreate your first show!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...pastShows.map((s) => _ShowCard(show: s, isActive: false)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  void _showCreateShowSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _CreateShowSheet(),
    );
  }
}

class _ShowCard extends StatelessWidget {
  final Show show;
  final bool isActive;

  const _ShowCard({required this.show, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, MMM d, yyyy');
    final currency = NumberFormat.currency(symbol: '\$');

    // Build mock summary
    final sales = isActive ? MockDataService.salesForActiveShow : <Sale>[];
    final expenses = isActive ? MockDataService.expensesForActiveShow : <Expense>[];
    final summary = MockDataService.summaryForShow(show, sales, expenses);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ShowDetailScreen(show: show)));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      show.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'ACTIVE',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                dateFormat.format(show.date),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              if (show.venue != null)
                Text(
                  '${show.venue}${show.tableNumber != null ? ' · Table ${show.tableNumber}' : ''}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              const Divider(height: 20),
              Row(
                children: [
                  _ShowStat(
                    label: 'Sales',
                    value: currency.format(summary.totalSales),
                    color: AppColors.success,
                  ),
                  _ShowStat(
                    label: 'Expenses',
                    value: currency.format(summary.totalExpenses),
                    color: AppColors.warning,
                  ),
                  _ShowStat(
                    label: 'Net',
                    value: currency.format(summary.netProfit),
                    color: summary.netProfit >= 0 ? AppColors.accent : AppColors.danger,
                  ),
                  _ShowStat(
                    label: 'Transactions',
                    value: '${summary.totalTransactions}',
                    color: AppColors.info,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShowStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ShowStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _CreateShowSheet extends StatefulWidget {
  const _CreateShowSheet();

  @override
  State<_CreateShowSheet> createState() => _CreateShowSheetState();
}

class _CreateShowSheetState extends State<_CreateShowSheet> {
  final _nameController = TextEditingController();
  final _venueController = TextEditingController();
  final _locationController = TextEditingController();
  final _tableController = TextEditingController();
  final _tableCostController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create New Show',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Show Name *'),
          ),
          const SizedBox(height: 12),
          // Date picker
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date'),
            subtitle: Text(DateFormat('MMM d, yyyy').format(_selectedDate)),
            trailing: const Icon(Icons.calendar_today, color: AppColors.accent),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _venueController,
            decoration: const InputDecoration(labelText: 'Venue'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _locationController,
            decoration: const InputDecoration(labelText: 'City / Location'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tableController,
                  decoration: const InputDecoration(labelText: 'Table #'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _tableCostController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Table Cost',
                    prefixText: '\$',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _createShow,
              child: const Text('Create Show'),
            ),
          ),
        ],
      ),
    );
  }

  void _createShow() {
    if (_nameController.text.isEmpty) return;
    // TODO: Save to API
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Show created! (mock)')),
    );
  }
}
