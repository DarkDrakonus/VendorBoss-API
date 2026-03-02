import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/mock_data_service.dart';
import '../models/show.dart';
import 'show_detail_screen.dart';
import 'settings_screen.dart';
import 'sale_screen.dart';
import '../widgets/connectivity_banner.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = MockDataService.currentUser;
    final shows = MockDataService.shows;
    final activeShow = shows.where((s) => s.isActive).firstOrNull;
    final activeSales = activeShow != null ? MockDataService.salesForActiveShow : <Sale>[];
    final activeExpenses = activeShow != null ? MockDataService.expensesForActiveShow : <Expense>[];
    final todaySales = activeSales.fold(0.0, (s, sale) => s + sale.totalAmount);
    final todayExpenses = activeExpenses.fold(0.0, (s, e) => s + e.amount);
    final netToday = todaySales - todayExpenses;
    final currency = NumberFormat.currency(symbol: '\$');

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.point_of_sale),
        label: const Text('Quick Sale', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () {
          final active = MockDataService.shows.where((s) => s.isActive).firstOrNull;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SaleScreen(show: active)),
          );
        },
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 110,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'VendorBoss',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'Hey, ${user.firstName ?? user.displayName}',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              const ConnectivityIconBadge(),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Active show banner
                  if (activeShow != null) ...[
                    _ActiveShowBanner(
                      show: activeShow,
                      totalSales: todaySales,
                      onOpen: () => _openShow(context, activeShow),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Today's show performance
                  if (activeShow != null) ...[
                    const _SectionHeader("Today's Performance"),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Sales',
                            value: currency.format(todaySales),
                            icon: Icons.trending_up,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Expenses',
                            value: currency.format(todayExpenses),
                            icon: Icons.receipt_long_outlined,
                            color: AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Net',
                            value: currency.format(netToday),
                            icon: Icons.account_balance_wallet_outlined,
                            color: netToday >= 0 ? AppColors.accent : AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // General sales
                  const _SectionHeader('General Sales'),
                  const SizedBox(height: 8),
                  const _GeneralSalesCard(),
                  const SizedBox(height: 20),

                  // Inventory summary
                  const _SectionHeader('Inventory'),
                  const SizedBox(height: 8),
                  _InventorySummaryCard(
                    totalCards: user.cardCount,
                    isAtLimit: user.isAtFreeLimit,
                  ),
                  const SizedBox(height: 20),

                  // Recent shows
                  const _SectionHeader('Recent Shows'),
                  const SizedBox(height: 8),
                  ...shows.take(3).map(
                        (show) => _RecentShowTile(
                          show: show,
                          onTap: () => _openShow(context, show),
                        ),
                      ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openShow(BuildContext context, Show show) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ShowDetailScreen(show: show)),
    );
  }
}

// ── Active Show Banner ────────────────────────────────────────────────────────

class _ActiveShowBanner extends StatelessWidget {
  final Show show;
  final double totalSales;
  final VoidCallback onOpen;

  const _ActiveShowBanner({
    required this.show,
    required this.totalSales,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.accent, AppColors.accentDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.store, color: Colors.black54, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ACTIVE SHOW',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  show.name,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (show.venue != null)
                  Text(
                    show.venue!,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              foregroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            onPressed: onOpen,
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              label,
              style: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ── General Sales Card ────────────────────────────────────────────────────────

class _GeneralSalesCard extends StatelessWidget {
  const _GeneralSalesCard();

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$');
    final sales = MockDataService.generalSales;
    final total = MockDataService.generalSalesTotal;

    // Group totals by channel
    final channels = <String, double>{};
    for (final sale in sales) {
      channels[sale.saleChannel] = (channels[sale.saleChannel] ?? 0) + sale.totalAmount;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  currency.format(total),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
                Text(
                  '${sales.length} sale${sales.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
            if (channels.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: channels.entries.map((e) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_channelIcon(e.key), size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${_channelLabel(e.key)}: ${currency.format(e.value)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _channelIcon(String channel) {
    switch (channel) {
      case 'tcgplayer':
        return Icons.storefront_outlined;
      case 'ebay':
        return Icons.shopping_bag_outlined;
      case 'whatnot':
        return Icons.live_tv_outlined;
      default:
        return Icons.handshake_outlined;
    }
  }

  String _channelLabel(String channel) {
    switch (channel) {
      case 'tcgplayer':
        return 'TCGPlayer';
      case 'ebay':
        return 'eBay';
      case 'whatnot':
        return 'Whatnot';
      default:
        return 'In-Person';
    }
  }
}

// ── Inventory Summary Card ────────────────────────────────────────────────────

class _InventorySummaryCard extends StatelessWidget {
  final int totalCards;
  final bool isAtLimit;

  const _InventorySummaryCard({required this.totalCards, required this.isAtLimit});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Cards', style: TextStyle(fontWeight: FontWeight.w500)),
                Text('$totalCards / 200', style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: totalCards / 200,
                backgroundColor: AppColors.darkSurfaceElevated,
                valueColor: AlwaysStoppedAnimation(
                  isAtLimit ? AppColors.danger : AppColors.accent,
                ),
                minHeight: 8,
              ),
            ),
            if (isAtLimit) ...[
              const SizedBox(height: 8),
              const Text(
                'Free limit reached. Upgrade to add more cards.',
                style: TextStyle(color: AppColors.danger, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Recent Show Tile ──────────────────────────────────────────────────────────

class _RecentShowTile extends StatelessWidget {
  final Show show;
  final VoidCallback onTap;

  const _RecentShowTile({required this.show, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: show.isActive
              ? AppColors.accent.withOpacity(0.15)
              : AppColors.darkSurfaceElevated,
          child: Icon(
            Icons.store,
            color: show.isActive ? AppColors.accent : AppColors.darkTextSecondary,
            size: 20,
          ),
        ),
        title: Text(show.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${dateFormat.format(show.date)}${show.location != null ? ' · ${show.location}' : ''}',
          style: const TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
        ),
        trailing: show.isActive
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              )
            : const Icon(Icons.chevron_right, color: AppColors.darkTextLight),
        onTap: onTap,
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
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
  }
}
