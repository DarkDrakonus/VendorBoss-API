import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/mock_data_service.dart';
import '../models/inventory_item.dart';
import 'card_detail_screen.dart';
import 'add_edit_card_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _searchQuery = '';
  String _selectedGame = 'All';
  final _searchController = TextEditingController();

  List<InventoryItem> get _filteredItems {
    var items = MockDataService.inventoryItems;
    if (_selectedGame != 'All') {
      items = items.where((i) => i.game == _selectedGame).toList();
    }
    if (_searchQuery.isNotEmpty) {
      items = items
          .where((i) => i.cardName.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    return items;
  }

  List<String> get _games {
    final games = MockDataService.inventoryItems.map((i) => i.game).toSet().toList();
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
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search cards...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
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
                    onSelected: (_) => setState(() => _selectedGame = game),
                    selectedColor: AppColors.accent.withOpacity(0.2),
                    checkmarkColor: AppColors.accent,
                    labelStyle: TextStyle(
                      color: selected ? AppColors.accent : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                ? const Center(
                    child: Text(
                      'No cards found',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _InventoryCard(
                        item: item,
                        currency: currency,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CardDetailScreen(item: item),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    // TODO: Show filter bottom sheet (condition, price range, etc.)
  }

  void _addCardManually() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddEditCardScreen(),
      ),
    ).then((result) {
      if (result != null && result is! String) {
        setState(() {}); // refresh list after add
      }
    });
  }
}

class _InventoryCard extends StatelessWidget {
  final InventoryItem item;
  final NumberFormat currency;
  final VoidCallback onTap;

  const _InventoryCard({required this.item, required this.currency, required this.onTap});

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
            // Card thumbnail
            CardImage(item: item, large: false),

            const SizedBox(width: 12),

            // Card details
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
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                      // Listed indicator — shows if card has active platform listings
                      if (MockDataService.hasActiveListings(item.id)) ...[  
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'Listed on marketplace',
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF86B817).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: const Color(0xFF86B817).withOpacity(0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.storefront_outlined,
                                    size: 10, color: Color(0xFF86B817)),
                                SizedBox(width: 3),
                                Text(
                                  'LISTED',
                                  style: TextStyle(
                                    color: Color(0xFF86B817),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.game} · ${item.setName} · ${item.cardNumber}',
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
                      if (item.isGraded && item.gradingCompany != null && item.grade != null)
                        _Tag('${item.gradingCompany} ${item.grade}', AppColors.warning)
                      else if (item.finish != 'normal')
                        _Tag(item.finishDisplay, AppColors.info),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Pricing column
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
                      color: markup >= 0 ? AppColors.success : AppColors.danger,
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
