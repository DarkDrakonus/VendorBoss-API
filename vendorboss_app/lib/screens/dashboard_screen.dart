import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/app_user.dart';
import '../models/show.dart';
import 'show_detail_screen.dart';
import 'settings_screen.dart';
import 'sale_screen.dart';
import '../widgets/connectivity_banner.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  AppUser? _user;
  List<Show> _shows = [];
  List<Sale> _activeSales = [];
  List<Expense> _activeExpenses = [];
  List<Sale> _generalSales = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Load user from cache first for instant greeting, then refresh from API
      final cached = await AuthService.instance.getCachedUser();
      if (cached != null && mounted) setState(() => _user = cached);

      final results = await Future.wait([
        AuthService.instance.getMe(null),
        ApiService.instance.getShows(),
      ]);

      final user   = results[0] as AppUser;
      final shows  = results[1] as List<Show>;
      final active = shows.where((s) => s.isActive).firstOrNull;

      // Load sales/expenses for active show and general sales in parallel
      final List<dynamic> salesData = await Future.wait([
        active != null
            ? ApiService.instance.getSales(showId: active.id)
            : Future.value(<Sale>[]),
        active != null
            ? ApiService.instance.getExpenses(showId: active.id)
            : Future.value(<Expense>[]),
        ApiService.instance.getSales(), // all sales for general total
      ]);

      if (!mounted) return;
      setState(() {
        _user           = user;
        _shows          = shows;
        _activeSales    = salesData[0] as List<Sale>;
        _activeExpenses = salesData[1] as List<Expense>;
        // General sales = sales with no show association
        _generalSales   = (salesData[2] as List<Sale>)
            .where((s) => s.showId == null)
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error   = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeShow    = _shows.where((s) => s.isActive).firstOrNull;
    final todaySales    = _activeSales.fold(0.0, (s, sale) => s + sale.totalAmount);
    final todayExpenses = _activeExpenses.fold(0.0, (s, e) => s + e.amount);
    final netToday      = todaySales - todayExpenses;
    final generalTotal  = _generalSales.fold(0.0, (s, sale) => s + sale.totalAmount);
    final currency      = NumberFormat.currency(symbol: '\$');

    // Greeting — business name first, then first name, then fallback
    final greeting = _user?.displayName ?? '...';

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.point_of_sale),
        label: const Text('Quick Sale', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SaleScreen(show: activeShow)),
          ).then((_) => _load()); // Refresh after sale
        },
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
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
                      'Hey, $greeting',
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

            // ── Error state ─────────────────────────────────────────────────
            if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    color: AppColors.danger.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.wifi_off, color: AppColors.danger),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Could not load data. Pull down to retry.',
                              style: TextStyle(color: AppColors.danger),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ── Loading shimmer ──────────────────────────────────────────────
            if (_loading && _user == null)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else
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

                      // Today's performance
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
                      _GeneralSalesCard(
                        sales: _generalSales,
                        total: generalTotal,
                      ),
                      const SizedBox(height: 20),

                      // Inventory summary
                      const _SectionHeader('Inventory'),
                      const SizedBox(height: 8),
                      _InventorySummaryCard(
                        totalCards: _user?.cardCount ?? 0,
                        isAtLimit: _user?.isAtFreeLimit ?? false,
                      ),
                      const SizedBox(height: 20),

                      // Recent shows
                      if (_shows.isNotEmpty) ...[
                        const _SectionHeader('Recent Shows'),
                        const SizedBox(height: 8),
                        ..._shows.take(3).map(
                              (show) => _RecentShowTile(
                                show: show,
                                onTap: () => _openShow(context, show),
                              ),
                            ),
                      ],

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
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
  final List<Sale> sales;
  final double total;

  const _GeneralSalesCard({required this.sales, required this.total});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$');

    final channels = <String, double>{};
    for (final sale in sales) {
      final ch = sale.saleChannel.isEmpty ? 'in_person' : sale.saleChannel;
      channels[ch] = (channels[ch] ?? 0) + sale.totalAmount;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: sales.isEmpty
            ? const Text(
                'No general sales yet',
                style: TextStyle(color: AppColors.textSecondary),
              )
            : Column(
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
      case 'tcgplayer': return Icons.storefront_outlined;
      case 'ebay':      return Icons.shopping_bag_outlined;
      case 'whatnot':   return Icons.live_tv_outlined;
      default:          return Icons.handshake_outlined;
    }
  }

  String _channelLabel(String channel) {
    switch (channel) {
      case 'tcgplayer': return 'TCGPlayer';
      case 'ebay':      return 'eBay';
      case 'whatnot':   return 'Whatnot';
      default:          return 'In-Person';
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
                value: (totalCards / 200).clamp(0.0, 1.0),
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
