import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final app = VendorBossApp.of(context);
    final isDark = app?.isDarkMode ?? true;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Appearance ───────────────────────────────────────────────────
          _SectionHeader('Appearance'),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Dark Mode'),
            subtitle: const Text('Easier on the eyes at shows'),
            value: isDark,
            onChanged: (_) {
              app?.toggleTheme();
              setState(() {});
            },
          ),

          const Divider(),

          // ── Account ──────────────────────────────────────────────────────
          _SectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profile'),
            subtitle: const Text('travis@vendorboss.com'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Profile screen
            },
          ),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('Subscription'),
            subtitle: const Text('Free Plan · 47 / 200 cards'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'UPGRADE',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            onTap: () {
              // TODO: Subscription screen
            },
          ),

          const Divider(),

          // ── Vendor Defaults ──────────────────────────────────────────────
          _SectionHeader('Vendor Defaults'),
          ListTile(
            leading: const Icon(Icons.percent),
            title: const Text('Default Buy Percentage'),
            subtitle: const Text('What % of market you offer when buying cards'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showBuyPercentageDialog(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.price_change_outlined),
            title: const Text('Default Markup / Markdown'),
            subtitle: const Text('Your default asking price vs market'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Markup settings
            },
          ),

          const Divider(),

          // ── Connections ──────────────────────────────────────────────────
          _SectionHeader('Connections'),
          _ConnectionTile(
            name: 'TCGPlayer',
            icon: Icons.storefront_outlined,
            description: 'Import completed sales automatically',
            onTap: () => _showComingSoon(context, 'TCGPlayer'),
          ),
          _ConnectionTile(
            name: 'eBay',
            icon: Icons.shopping_bag_outlined,
            description: 'Sync eBay sold listings',
            onTap: () => _showComingSoon(context, 'eBay'),
          ),
          _ConnectionTile(
            name: 'Whatnot',
            icon: Icons.live_tv_outlined,
            description: 'Track your live auction sales',
            onTap: () => _showComingSoon(context, 'Whatnot'),
          ),
          _ConnectionTile(
            name: 'Mercari',
            icon: Icons.sell_outlined,
            description: 'Import Mercari sales history',
            onTap: () => _showComingSoon(context, 'Mercari'),
          ),

          const Divider(),

          // ── App ──────────────────────────────────────────────────────────
          _SectionHeader('App'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About VendorBoss'),
            subtitle: const Text('Version 1.0.0'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.danger),
            title: const Text('Sign Out',
                style: TextStyle(color: AppColors.danger)),
            onTap: () => _confirmSignOut(context),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showBuyPercentageDialog(BuildContext context) {
    double percentage = 0.50;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Default Buy Percentage'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(percentage * 100).toStringAsFixed(0)}% of market price',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                ),
              ),
              Slider(
                value: percentage,
                min: 0.10,
                max: 0.90,
                divisions: 16,
                onChanged: (v) => setDialogState(() => percentage = v),
              ),
              const Text(
                'This is your starting point when buying cards from customers. You can always adjust per transaction.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
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
                // TODO: Save to preferences
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String platform) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Connect $platform'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link, size: 48, color: AppColors.accent),
            const SizedBox(height: 12),
            Text(
              '$platform integration is coming in a future update. Once connected, your sales will sync automatically into VendorBoss.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: Clear auth token and navigate to login
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class _ConnectionTile extends StatelessWidget {
  final String name;
  final IconData icon;
  final String description;
  final bool connected;
  final VoidCallback onTap;

  const _ConnectionTile({
    required this.name,
    required this.icon,
    required this.description,
    this.connected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: connected ? AppColors.success : AppColors.textSecondary),
      title: Text(name),
      subtitle: Text(
        connected ? 'Connected · Last synced just now' : description,
        style: TextStyle(
          fontSize: 12,
          color: connected ? AppColors.success : AppColors.textSecondary,
        ),
      ),
      trailing: connected
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'CONNECTED',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.darkSurfaceElevated,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'CONNECT',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
      onTap: onTap,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.accent,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
