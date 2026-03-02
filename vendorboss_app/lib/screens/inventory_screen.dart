import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/inventory_item.dart';
import 'card_detail_screen.dart';
import 'add_edit_card_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<InventoryItem> _allItems  = [];
  bool _loading                  = true;
  String? _error;
  String _searchQuery            = '';
  String _selectedGame           = 'All';
  final _searchController        = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await ApiService.instance.getInventory(pageSize: 200);
      if (!mounted) return;
      setState(() { _allItems = items; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<InventoryItem> get _filteredItems {
    var items = _allItems;
    if (_selectedGame != 'All') {
      items = items.where((i) => i.game == _selectedGame).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items.where((i) =>
        i.cardName.toLowerCase().contains(q) ||
        i.game.toLowerCase().contains(q) ||
        i.setName.toLowerCase().contains(q)
      ).toList();
    }
    return items;
  }

  List<String> get _games {
    final games = _allItems.map((i) => i.game).where((g) => g.isNotEmpty).toSet().toList();
    games.sort();
    return ['All', ...games];
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$');
    final items = _filteredItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addCardManually,
            tooltip: 'Add Card',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorView(error: _error!, onRetry: _load)
                : Column(
                    children: [
                      // Search bar
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _searchQuery = v),
                          decoration: InputDecoration(
                            hintText: 'Search cards...',
                            prefixIcon: const Icon(Icons.search,
                                color: AppColors.textSecondary),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                      FocusScope.of(context).unfocus();
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),

                      // Game filter chips
                      if (_games.length > 1)
                        SizedBox(
                          height: 40,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            scrollDirection: Axis.horizontal,
                            itemCount: _games.length,
                            itemBuilder: (context, index) {
                              final game = _games[index];
                              final selected = _selectedGame == game;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text(game),
                                  selected: selected,
                                  onSelected: (_) =>
                                      setState(() => _selectedGame = game),
                                  selectedColor:
                                      AppColors.accent.withOpacity(0.2),
                                  checkmarkColor: AppColors.accent,
                                  labelStyle: TextStyle(
                                    color: selected
                                        ? AppColors.accent
                                        : AppColors.textSecondary,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                      const SizedBox(height: 8),

                      // Count
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: Row(
                          children: [
                            Text(
                              '${items.length} card${items.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // List
                      Expanded(
                        child: items.isEmpty
                            ? Center(
                                child: Text(
                                  _allItems.isEmpty
                                      ? 'No cards in inventory yet'
                                      : 'No cards match your search',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary),
                                ),
                              )
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                itemCount: items.length,
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  return _InventoryCard(
                                    item: item,
                                    currency: currency,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            CardDetailScreen(item: item),
                                      ),
                                    ).then((_) => _load()),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }

  void _showFilterSheet() {
    // TODO: filter bottom sheet
  }

  void _addCardManually() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddEditCardScreen()),
    ).then((_) => _load());
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

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

// ── Inventory card tile ───────────────────────────────────────────────────────

class _InventoryCard extends StatelessWidget {
  final InventoryItem item;
  final NumberFormat currency;
  final VoidCallback onTap;

  const _InventoryCard(
      {required this.item, required this.currency, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final markup = item.marketMarkup;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CardImage(item: item, large: false),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.quantity > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.info.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'x${item.quantity}',
                              style: const TextStyle(
                                color: AppColors.info,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [item.game, item.setName, item.cardNumber]
                          .where((s) => s.isNotEmpty)
                          .join(' · '),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _Tag(item.condition, AppColors.textSecondary),
                        const SizedBox(width: 6),
                        if (item.isGraded &&
                            item.gradingCompany != null &&
                            item.grade != null)
                          _Tag('${item.gradingCompany} ${item.grade}',
                              AppColors.warning)
                        else if (item.finish != 'normal')
                          _Tag(item.finishDisplay, AppColors.info),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Pricing
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item.askingPrice != null
                        ? currency.format(item.askingPrice)
                        : '—',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (item.marketPrice != null)
                    Text(
                      'Mkt: ${currency.format(item.marketPrice)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  if (markup != null)
                    Text(
                      '${markup >= 0 ? '+' : ''}${markup.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color:
                            markup >= 0 ? AppColors.success : AppColors.danger,
                      ),
                    ),
                  const SizedBox(height: 4),
                  const Icon(Icons.chevron_right,
                      size: 16, color: AppColors.textLight),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
