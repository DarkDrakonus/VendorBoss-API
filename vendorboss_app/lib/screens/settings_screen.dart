import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/app_user.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppUser? _user;
  bool _loadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final cached = await AuthService.instance.getCachedUser();
    if (mounted) setState(() { _user = cached; _loadingUser = false; });
    // Refresh from API in background
    try {
      final fresh = await AuthService.instance.getMe(null);
      await AuthService.instance.updateCachedUser(fresh);
      if (mounted) setState(() => _user = fresh);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final app    = VendorBossApp.of(context);
    final isDark = app?.isDarkMode ?? true;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [

          // ── Profile card ─────────────────────────────────────────────────
          _loadingUser
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _ProfileCard(
                  user: _user,
                  onEdit: () => _openEditProfile(),
                ),

          const Divider(),

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

          // ── Subscription ─────────────────────────────────────────────────
          _SectionHeader('Subscription'),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('Current Plan'),
            subtitle: Text(
              _user != null
                  ? '${_user!.subscriptionTier.toUpperCase()} Plan'
                  : 'Free Plan',
            ),
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
            onTap: () => _showComingSoon(context, 'Subscription Management'),
          ),

          const Divider(),

          // ── Vendor Defaults ──────────────────────────────────────────────
          _SectionHeader('Vendor Defaults'),
          ListTile(
            leading: const Icon(Icons.percent),
            title: const Text('Default Buy Percentage'),
            subtitle: const Text('What % of market you offer when buying cards'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showBuyPercentageDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.price_change_outlined),
            title: const Text('Default Markup / Markdown'),
            subtitle: const Text('Your default asking price vs market'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showComingSoon(context, 'Markup Settings'),
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

  void _openEditProfile() async {
    final updated = await Navigator.push<AppUser>(
      context,
      MaterialPageRoute(builder: (_) => EditProfileScreen(user: _user)),
    );
    if (updated != null && mounted) {
      setState(() => _user = updated);
    }
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
                'This is your starting point when buying cards from customers.',
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(feature),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.rocket_launch_outlined,
                size: 48, color: AppColors.accent),
            const SizedBox(height: 12),
            Text(
              '$feature is coming in a future update.',
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
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService.instance.logout();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

// ── Profile Card ──────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final AppUser? user;
  final VoidCallback onEdit;

  const _ProfileCard({required this.user, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final initials = _initials();
    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.accent.withOpacity(0.15),
              child: Text(
                initials,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.fullName ?? 'Your Name',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (user?.businessName != null && user!.businessName!.isNotEmpty)
                    Text(
                      user!.businessName!,
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  Text(
                    user?.email ?? '',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_outlined,
                color: AppColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }

  String _initials() {
    if (user == null) return '?';
    final first = user!.firstName?.isNotEmpty == true
        ? user!.firstName![0].toUpperCase() : '';
    final last  = user!.lastName?.isNotEmpty == true
        ? user!.lastName![0].toUpperCase() : '';
    if (first.isNotEmpty && last.isNotEmpty) return '$first$last';
    if (user!.businessName?.isNotEmpty == true) {
      return user!.businessName![0].toUpperCase();
    }
    return user!.email[0].toUpperCase();
  }
}

// ── Edit Profile Screen ───────────────────────────────────────────────────────

class EditProfileScreen extends StatefulWidget {
  final AppUser? user;
  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey     = GlobalKey<FormState>();
  late final _firstCtrl    = TextEditingController(text: widget.user?.firstName ?? '');
  late final _lastCtrl     = TextEditingController(text: widget.user?.lastName ?? '');
  late final _bizCtrl      = TextEditingController(text: widget.user?.businessName ?? '');
  late final _emailCtrl    = TextEditingController(text: widget.user?.email ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _bizCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final updated = await ApiService.instance.updateProfile(
        firstName:    _firstCtrl.text.trim(),
        lastName:     _lastCtrl.text.trim(),
        businessName: _bizCtrl.text.trim(),
        email:        _emailCtrl.text.trim().toLowerCase(),
      );
      if (!mounted) return;
      Navigator.pop(context, updated);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Profile updated'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to save: $e'),
        backgroundColor: AppColors.danger,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text(
              'Save',
              style: TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionHeader('Personal Info'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _firstCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'First Name'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _lastCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Last Name'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Required' : null,
                ),
              ),
            ]),
            const SizedBox(height: 16),
            _SectionHeader('Business'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bizCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Business Name',
                hintText: 'Optional — shown on your profile',
              ),
            ),
            const SizedBox(height: 16),
            _SectionHeader('Login'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black),
                    )
                  : const Text('Save Changes',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── Supporting Widgets ────────────────────────────────────────────────────────

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
      leading: Icon(icon,
          color: connected ? AppColors.success : AppColors.textSecondary),
      title: Text(name),
      subtitle: Text(
        connected ? 'Connected' : description,
        style: TextStyle(
          fontSize: 12,
          color: connected ? AppColors.success : AppColors.textSecondary,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: connected
              ? AppColors.success.withOpacity(0.15)
              : AppColors.darkSurfaceElevated,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          connected ? 'CONNECTED' : 'CONNECT',
          style: TextStyle(
            color: connected ? AppColors.success : AppColors.textSecondary,
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
