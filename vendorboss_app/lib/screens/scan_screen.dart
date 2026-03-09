import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/mock_data_service.dart';
import '../models/card_model.dart';
import 'card_recognition_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _searchController = TextEditingController();
  List<CardModel> _results = [];
  bool _isSearching = false;
  CardModel? _selectedCard;
  bool _showBuyMode = false;
  double _buyPercentage = 0.50;

  void _search(String query) {
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _results = MockDataService.searchCards(query);
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan & Lookup'),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: 'Scan Card',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CardRecognitionScreen(),
                  fullscreenDialog: true,
                ),
              );
              // result is a ScanResult — handle it when card detail screen is wired
              if (result != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Card identified! Add to inventory from the result.')),
                );
              }
            },
          );
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Search by card name, set, or number...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _search('');
                          setState(() => _selectedCard = null);
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Camera hint when empty
          if (_results.isEmpty && _selectedCard == null && _searchController.text.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.document_scanner_outlined,
                      size: 64,
                      color: AppColors.textLight,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Scan a card or search by name',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Get market prices, recent sales,\nand add to inventory instantly',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Open Camera'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CardRecognitionScreen(),
                          fullscreenDialog: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Search results
          if (_results.isNotEmpty && _selectedCard == null)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final card = _results[index];
                  return _SearchResultTile(
                    card: card,
                    onTap: () => setState(() => _selectedCard = card),
                  );
                },
              ),
            ),

          // Selected card detail
          if (_selectedCard != null)
            Expanded(
              child: _CardDetailPanel(
                card: _selectedCard!,
                showBuyMode: _showBuyMode,
                buyPercentage: _buyPercentage,
                onBuyPercentageChanged: (v) => setState(() => _buyPercentage = v),
                onToggleBuyMode: () => setState(() => _showBuyMode = !_showBuyMode),
                onAddToInventory: () {
                  // TODO: Navigate to add inventory form
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Added to inventory! (mock)')),
                  );
                },
                onBack: () => setState(() {
                  _selectedCard = null;
                  _showBuyMode = false;
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final CardModel card;
  final VoidCallback onTap;

  const _SearchResultTile({required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.surfaceDark,
          child: const Icon(Icons.style, color: AppColors.textSecondary),
        ),
        title: Text(
          card.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${card.game} · ${card.setName} · ${card.finishDisplay}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          card.marketPrice != null ? currency.format(card.marketPrice) : '—',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _CardDetailPanel extends StatelessWidget {
  final CardModel card;
  final bool showBuyMode;
  final double buyPercentage;
  final ValueChanged<double> onBuyPercentageChanged;
  final VoidCallback onToggleBuyMode;
  final VoidCallback onAddToInventory;
  final VoidCallback onBack;

  const _CardDetailPanel({
    required this.card,
    required this.showBuyMode,
    required this.buyPercentage,
    required this.onBuyPercentageChanged,
    required this.onToggleBuyMode,
    required this.onAddToInventory,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$');
    final buyPrice = (card.marketPrice ?? 0) * buyPercentage;
    final pct = (buyPercentage * 100).toStringAsFixed(0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          TextButton.icon(
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Back to results'),
            onPressed: onBack,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 8),

          // Card header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 90,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.style, size: 32, color: AppColors.textLight),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          card.game,
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${card.setName} · #${card.cardNumber}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${card.rarity} · ${card.finishDisplay}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Pricing
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MARKET PRICING (TCGPlayer)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _PriceBox('Market', card.marketPrice, AppColors.accent, large: true),
                      _PriceBox('Low', card.lowPrice, AppColors.success),
                      _PriceBox('Mid', card.midPrice, AppColors.info),
                      _PriceBox('High', card.highPrice, AppColors.warning),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Buy mode
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'BUY PRICE CALCULATOR',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 1,
                        ),
                      ),
                      Switch(
                        value: showBuyMode,
                        onChanged: (_) => onToggleBuyMode(),
                        activeColor: AppColors.accent,
                      ),
                    ],
                  ),
                  if (showBuyMode) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Pay % of market:',
                            style: TextStyle(color: AppColors.textSecondary)),
                        Text(
                          '$pct%',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: buyPercentage,
                      min: 0.10,
                      max: 0.90,
                      divisions: 16,
                      activeColor: AppColors.accent,
                      onChanged: onBuyPercentageChanged,
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Offer Price:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            currency.format(buyPrice),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.shopping_cart_outlined),
                  label: const Text('Buy from Customer'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: const BorderSide(color: AppColors.accent),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: onToggleBuyMode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add to Inventory'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: onAddToInventory,
                ),
              ),
            ],
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _PriceBox extends StatelessWidget {
  final String label;
  final double? price;
  final Color color;
  final bool large;

  const _PriceBox(this.label, this.price, this.color, {this.large = false});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$');
    return Expanded(
      flex: large ? 2 : 1,
      child: Column(
        children: [
          Text(
            price != null ? currency.format(price) : '—',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: large ? 22 : 14,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
