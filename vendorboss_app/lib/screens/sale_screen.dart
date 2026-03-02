import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/inventory_item.dart';
import '../models/show.dart';
import '../services/mock_data_service.dart';

class _OrderItem {
  final InventoryItem inventoryItem;
  int quantity;
  double salePrice;

  _OrderItem({
    required this.inventoryItem,
    this.quantity = 1,
    required this.salePrice,
  });

  double get lineTotal => salePrice * quantity;
  double get marketPrice => inventoryItem.marketPrice ?? salePrice;
}

class SaleScreen extends StatefulWidget {
  final Show? show; // null = General Sales
  const SaleScreen({super.key, this.show});

  @override
  State<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends State<SaleScreen> {
  final List<_OrderItem> _order = [];
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _paymentMethod = 'cash';
  bool _showSearch = false;
  bool _isBulkMode = false;
  final _bulkAmountController = TextEditingController();
  final _bulkDescController = TextEditingController();
  final currency = NumberFormat.currency(symbol: '\$');

  double get _orderTotal => _order.fold(0.0, (s, i) => s + i.lineTotal);

  List<InventoryItem> get _filteredInventory {
    if (_searchQuery.isEmpty) return [];
    return MockDataService.inventoryItems
        .where((i) => i.cardName.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  void _addToOrder(InventoryItem item) {
    setState(() {
      final existing = _order.where((o) => o.inventoryItem.id == item.id).firstOrNull;
      if (existing != null) {
        existing.quantity++;
      } else {
        _order.add(_OrderItem(
          inventoryItem: item,
          salePrice: item.askingPrice ?? item.marketPrice ?? 0.0,
        ));
      }
      _searchQuery = '';
      _searchController.clear();
      _showSearch = false;
      FocusScope.of(context).unfocus();
    });
  }

  void _removeFromOrder(int index) {
    setState(() => _order.removeAt(index));
  }

  void _updatePrice(int index, double price) {
    setState(() => _order[index].salePrice = price);
  }

  void _updateQuantity(int index, int qty) {
    setState(() => _order[index].quantity = qty);
  }

  void _completeSale() {
    if (_isBulkMode) {
      final amount = double.tryParse(_bulkAmountController.text);
      if (amount == null || amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid bulk sale amount')),
        );
        return;
      }
    } else if (_order.isEmpty) {
      return;
    }

    final total = _isBulkMode
        ? (double.tryParse(_bulkAmountController.text) ?? 0)
        : _orderTotal;

    // TODO: Post sale to API
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sale Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 56),
            const SizedBox(height: 12),
            Text(
              currency.format(total),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: AppColors.success,
              ),
            ),
            Text(
              _paymentMethod.toUpperCase(),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasItems = _isBulkMode
        ? _bulkAmountController.text.isNotEmpty
        : _order.isNotEmpty;
    final total = _isBulkMode
        ? (double.tryParse(_bulkAmountController.text) ?? 0)
        : _orderTotal;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.show != null ? 'New Sale · ${widget.show!.name}' : 'New Sale · General'),
        actions: [
          TextButton.icon(
            icon: Icon(
              _isBulkMode ? Icons.style : Icons.inventory_2_outlined,
              color: _isBulkMode ? AppColors.warning : AppColors.accent,
            ),
            label: Text(
              _isBulkMode ? 'Card Sale' : 'Bulk Sale',
              style: TextStyle(
                color: _isBulkMode ? AppColors.warning : AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () => setState(() {
              _isBulkMode = !_isBulkMode;
              _order.clear();
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isBulkMode
                ? _BulkSalePanel(
                    amountController: _bulkAmountController,
                    descController: _bulkDescController,
                  )
                : _CardSalePanel(
                    order: _order,
                    showSearch: _showSearch,
                    searchQuery: _searchQuery,
                    searchController: _searchController,
                    filteredInventory: _filteredInventory,
                    currency: currency,
                    onShowSearch: () => setState(() => _showSearch = true),
                    onSearchChanged: (v) => setState(() => _searchQuery = v),
                    onAddToOrder: _addToOrder,
                    onRemove: _removeFromOrder,
                    onPriceChanged: _updatePrice,
                    onQuantityChanged: _updateQuantity,
                    onCancelSearch: () => setState(() {
                      _showSearch = false;
                      _searchQuery = '';
                      _searchController.clear();
                      FocusScope.of(context).unfocus();
                    }),
                  ),
          ),
          _CheckoutBar(
            total: total,
            paymentMethod: _paymentMethod,
            hasItems: hasItems,
            currency: currency,
            onPaymentChanged: (m) => setState(() => _paymentMethod = m),
            onComplete: _completeSale,
          ),
        ],
      ),
    );
  }
}

// ── Card Sale Panel ───────────────────────────────────────────────────────────

class _CardSalePanel extends StatelessWidget {
  final List<_OrderItem> order;
  final bool showSearch;
  final String searchQuery;
  final TextEditingController searchController;
  final List<InventoryItem> filteredInventory;
  final NumberFormat currency;
  final VoidCallback onShowSearch;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<InventoryItem> onAddToOrder;
  final ValueChanged<int> onRemove;
  final void Function(int, double) onPriceChanged;
  final void Function(int, int) onQuantityChanged;
  final VoidCallback onCancelSearch;

  const _CardSalePanel({
    required this.order,
    required this.showSearch,
    required this.searchQuery,
    required this.searchController,
    required this.filteredInventory,
    required this.currency,
    required this.onShowSearch,
    required this.onSearchChanged,
    required this.onAddToOrder,
    required this.onRemove,
    required this.onPriceChanged,
    required this.onQuantityChanged,
    required this.onCancelSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: showSearch
              ? TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search inventory...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: onCancelSearch,
                    ),
                  ),
                )
              : Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.search),
                        label: const Text('Search Inventory'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: onShowSearch,
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Scan'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Camera scanning coming soon!')),
                        );
                      },
                    ),
                  ],
                ),
        ),

        // Search results
        if (showSearch && searchQuery.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.darkDivider),
            ),
            child: filteredInventory.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No cards found',
                        style: TextStyle(color: AppColors.textSecondary)),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: filteredInventory.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final item = filteredInventory[i];
                      return ListTile(
                        dense: true,
                        title: Text(item.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${item.game} · ${item.condition}',
                            style: const TextStyle(fontSize: 12)),
                        trailing: Text(
                          item.askingPrice != null ? currency.format(item.askingPrice) : '—',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, color: AppColors.accent),
                        ),
                        onTap: () => onAddToOrder(item),
                      );
                    },
                  ),
          ),

        // Order list
        Expanded(
          child: order.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shopping_cart_outlined,
                          size: 56, color: AppColors.textLight),
                      const SizedBox(height: 12),
                      const Text('No cards added yet',
                          style: TextStyle(color: AppColors.textSecondary)),
                      const Text('Search or scan to add cards to the sale',
                          style: TextStyle(color: AppColors.textLight, fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: order.length,
                  itemBuilder: (context, index) => _OrderItemCard(
                    item: order[index],
                    currency: currency,
                    onRemove: () => onRemove(index),
                    onPriceChanged: (p) => onPriceChanged(index, p),
                    onQuantityChanged: (q) => onQuantityChanged(index, q),
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Order Item Card ───────────────────────────────────────────────────────────

class _OrderItemCard extends StatelessWidget {
  final _OrderItem item;
  final NumberFormat currency;
  final VoidCallback onRemove;
  final ValueChanged<double> onPriceChanged;
  final ValueChanged<int> onQuantityChanged;

  const _OrderItemCard({
    required this.item,
    required this.currency,
    required this.onRemove,
    required this.onPriceChanged,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final marketPrice = item.marketPrice;
    final discount = marketPrice > 0
        ? ((marketPrice - item.salePrice) / marketPrice * 100)
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Quantity stepper — vertical stack
            Column(
              children: [
                _SmallButton(
                  icon: Icons.add,
                  onTap: () => onQuantityChanged(item.quantity + 1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    '${item.quantity}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                _SmallButton(
                  icon: Icons.remove,
                  onTap: item.quantity > 1 ? () => onQuantityChanged(item.quantity - 1) : null,
                ),
              ],
            ),

            const SizedBox(width: 12),

            // Card info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.inventoryItem.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.inventoryItem.game} · ${item.inventoryItem.condition}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  Text(
                    'Market: ${currency.format(marketPrice)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Price bubble — tap to edit
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => _showPriceDialog(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.accent.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currency.format(item.salePrice),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit, size: 12, color: AppColors.accent),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                if (discount.abs() > 0.5)
                  Text(
                    discount > 0
                        ? '-${discount.toStringAsFixed(0)}% off'
                        : '+${(-discount).toStringAsFixed(0)}% over',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: discount > 0 ? AppColors.warning : AppColors.success,
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 16),

            // Delete button — clearly separated with its own tap target
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
              color: AppColors.danger,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.danger.withOpacity(0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPriceDialog(BuildContext context) {
    final controller = TextEditingController(text: item.salePrice.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.inventoryItem.cardName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Market: ${currency.format(item.marketPrice)}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
              ],
              decoration: const InputDecoration(
                labelText: 'Sale Price',
                prefixText: '\$ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final price = double.tryParse(controller.text);
              if (price != null && price >= 0) onPriceChanged(price);
              Navigator.pop(ctx);
            },
            child: const Text('Set Price'),
          ),
        ],
      ),
    );
  }
}

// ── Bulk Sale Panel ───────────────────────────────────────────────────────────

class _BulkSalePanel extends StatelessWidget {
  final TextEditingController amountController;
  final TextEditingController descController;

  const _BulkSalePanel({
    required this.amountController,
    required this.descController,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: AppColors.warning),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bulk Sale Mode — for commons, bulk lots, or sealed product not tracked in inventory.',
                    style: TextStyle(color: AppColors.warning, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
            ],
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: '\$ ',
              hintText: '0.00',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: descController,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              hintText: 'e.g. Bulk commons bag, Booster pack lot...',
            ),
          ),
        ],
      ),
    );
  }
}

// ── Checkout Bar ─────────────────────────────────────────────────────────────

class _CheckoutBar extends StatelessWidget {
  final double total;
  final String paymentMethod;
  final bool hasItems;
  final NumberFormat currency;
  final ValueChanged<String> onPaymentChanged;
  final VoidCallback onComplete;

  const _CheckoutBar({
    required this.total,
    required this.paymentMethod,
    required this.hasItems,
    required this.currency,
    required this.onPaymentChanged,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        border: const Border(top: BorderSide(color: AppColors.darkDivider)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('Payment:',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(width: 12),
              _PaymentChip('cash', 'Cash', Icons.payments_outlined, paymentMethod, onPaymentChanged),
              const SizedBox(width: 8),
              _PaymentChip('card', 'Card', Icons.credit_card, paymentMethod, onPaymentChanged),
              const SizedBox(width: 8),
              _PaymentChip('trade', 'Trade', Icons.swap_horiz, paymentMethod, onPaymentChanged),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  Text(
                    currency.format(total),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: 160,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Complete Sale'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: hasItems ? AppColors.accent : AppColors.darkSurfaceElevated,
                    foregroundColor: hasItems ? Colors.black : AppColors.textLight,
                  ),
                  onPressed: hasItems ? onComplete : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Payment Chip ─────────────────────────────────────────────────────────────

class _PaymentChip extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final String selected;
  final ValueChanged<String> onChanged;

  const _PaymentChip(this.value, this.label, this.icon, this.selected, this.onChanged);

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withOpacity(0.2) : AppColors.darkSurfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.accent : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14,
                color: isSelected ? AppColors.accent : AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small Button ─────────────────────────────────────────────────────────────

class _SmallButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _SmallButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: onTap != null ? AppColors.darkSurfaceElevated : AppColors.darkSurface,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap != null ? AppColors.textPrimary : AppColors.textLight,
        ),
      ),
    );
  }
}
