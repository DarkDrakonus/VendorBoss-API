import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/show.dart';
import 'show_detail_screen.dart';

class ShowsScreen extends StatefulWidget {
  const ShowsScreen({super.key});

  @override
  State<ShowsScreen> createState() => _ShowsScreenState();
}

class _ShowsScreenState extends State<ShowsScreen> {
  List<Show> _shows       = [];
  ShowSummary? _activeSummary;
  bool _loading           = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final shows = await ApiService.instance.getShows();
      final active = shows.where((s) => s.isActive).firstOrNull;

      ShowSummary? activeSummary;
      if (active != null) {
        try {
          activeSummary = await ApiService.instance.getShowSummary(active.id);
        } catch (_) {
          // Summary failure shouldn't block the whole screen
        }
      }

      if (!mounted) return;
      setState(() {
        _shows         = shows;
        _activeSummary = activeSummary;
        _loading       = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeShows = _shows.where((s) => s.isActive).toList();
    final pastShows   = _shows.where((s) => !s.isActive).toList();
    // Sort past shows newest first
    pastShows.sort((a, b) => b.date.compareTo(a.date));

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
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorView(error: _error!, onRetry: _load)
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (activeShows.isNotEmpty) ...[
                        const _SectionHeader('Active Show'),
                        const SizedBox(height: 8),
                        ...activeShows.map((s) => _ShowCard(
                              show: s,
                              isActive: true,
                              summary: _activeSummary,
                              onTap: () => _openShow(context, s),
                            )),
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
                              style:
                                  TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      else
                        ...pastShows.map((s) => _ShowCard(
                              show: s,
                              isActive: false,
                              summary: null,
                              onTap: () => _openShow(context, s),
                            )),
                      const SizedBox(height: 80),
                    ],
                  ),
      ),
    );
  }

  void _openShow(BuildContext context, Show show) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ShowDetailScreen(show: show)),
    ).then((_) => _load());
  }

  void _showCreateShowSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CreateShowSheet(onCreated: _load),
    );
  }
}

// ── Show Card ─────────────────────────────────────────────────────────────────

class _ShowCard extends StatelessWidget {
  final Show show;
  final bool isActive;
  final ShowSummary? summary;
  final VoidCallback onTap;

  const _ShowCard({
    required this.show,
    required this.isActive,
    required this.summary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, MMM d, yyyy');
    final currency   = NumberFormat.currency(symbol: '\$');
    final net        = summary != null ? summary!.netProfit : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name + Active badge
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
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
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
              if (show.venue != null || show.location != null)
                Text(
                  [
                    if (show.venue != null) show.venue!,
                    if (show.tableNumber != null) 'Table ${show.tableNumber}',
                    if (show.location != null) show.location!,
                  ].join(' · '),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),

              // Stats — only show if we have summary data
              if (summary != null) ...[
                const Divider(height: 20),
                Row(
                  children: [
                    _ShowStat(
                      label: 'Sales',
                      value: currency.format(summary!.totalSales),
                      color: AppColors.success,
                    ),
                    _ShowStat(
                      label: 'Expenses',
                      value: currency.format(summary!.totalExpenses),
                      color: AppColors.warning,
                    ),
                    _ShowStat(
                      label: 'Net',
                      value: currency.format(summary!.netProfit),
                      color: net != null && net >= 0
                          ? AppColors.accent
                          : AppColors.danger,
                    ),
                    _ShowStat(
                      label: 'Sales',
                      value: '${summary!.totalTransactions}',
                      color: AppColors.info,
                    ),
                  ],
                ),
              ] else if (!isActive) ...[
                // Past shows without cached summary — show tap hint
                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Tap for details',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right,
                        size: 16, color: AppColors.textSecondary),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Show Stat ─────────────────────────────────────────────────────────────────

class _ShowStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ShowStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14, color: color),
          ),
          Text(
            label,
            style: const TextStyle(
                fontSize: 10, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────

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

// ── Error View ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: AppColors.danger, size: 48),
            const SizedBox(height: 16),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

// ── Create Show Sheet ─────────────────────────────────────────────────────────

class _CreateShowSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateShowSheet({required this.onCreated});

  @override
  State<_CreateShowSheet> createState() => _CreateShowSheetState();
}

class _CreateShowSheetState extends State<_CreateShowSheet> {
  final _nameController      = TextEditingController();
  final _venueController     = TextEditingController();
  final _locationController  = TextEditingController();
  final _tableController     = TextEditingController();
  final _tableCostController = TextEditingController();
  DateTime _selectedDate     = DateTime.now();
  bool _saving               = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _venueController.dispose();
    _locationController.dispose();
    _tableController.dispose();
    _tableCostController.dispose();
    super.dispose();
  }

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
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Show Name *',
              hintText: 'e.g. Sioux Falls Card Show',
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date'),
            subtitle: Text(DateFormat('MMM d, yyyy').format(_selectedDate)),
            trailing:
                const Icon(Icons.calendar_today, color: AppColors.accent),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _venueController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Venue',
              hintText: 'e.g. Convention Center',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _locationController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'City / Location',
              hintText: 'e.g. Sioux Falls, SD',
            ),
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
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Table Cost',
                    prefixText: '\$',
                  ),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _createShow,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Show'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createShow() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'Show name is required');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await ApiService.instance.createShow(
        name:        _nameController.text.trim(),
        date:        _selectedDate,
        venue:       _venueController.text.trim().isEmpty
                       ? null : _venueController.text.trim(),
        location:    _locationController.text.trim().isEmpty
                       ? null : _locationController.text.trim(),
        tableNumber: _tableController.text.trim().isEmpty
                       ? null : _tableController.text.trim(),
        tableCost:   double.tryParse(_tableCostController.text),
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onCreated();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Show created!')),
      );
    } catch (e) {
      setState(() { _error = e.toString(); _saving = false; });
    }
  }
}
