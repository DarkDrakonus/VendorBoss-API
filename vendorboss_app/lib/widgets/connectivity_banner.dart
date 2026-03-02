import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';

/// A red wifi-off icon that appears in the AppBar when offline.
/// Tapping it shows a bottom sheet explaining the situation.
class ConnectivityIconBadge extends StatelessWidget {
  const ConnectivityIconBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService.instance.isOnline,
      builder: (context, online, _) {
        if (online) return const SizedBox.shrink();
        return IconButton(
          icon: const Icon(
            Icons.wifi_off_rounded,
            color: Colors.redAccent,
          ),
          tooltip: 'No internet connection',
          onPressed: () => _showOfflineSheet(context),
        );
      },
    );
  }

  void _showOfflineSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _OfflineInfoSheet(),
    );
  }
}

class _OfflineInfoSheet extends StatelessWidget {
  const _OfflineInfoSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              color: Colors.redAccent,
              size: 32,
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'No Internet Connection',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'VendorBoss is running in offline mode. All your sales, expenses, and inventory changes are being saved to this device.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
              height: 1.5,
            ),
          ),

          const SizedBox(height: 16),

          // Reassurance points
          _BulletPoint(
            icon: Icons.check_circle_outline,
            color: Colors.greenAccent,
            text: 'Sales are recorded and safe',
          ),
          _BulletPoint(
            icon: Icons.check_circle_outline,
            color: Colors.greenAccent,
            text: 'Expenses are being logged locally',
          ),
          _BulletPoint(
            icon: Icons.sync_outlined,
            color: Colors.blueAccent,
            text: 'Everything syncs automatically when reconnected',
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Got It',
                style:
                    TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _BulletPoint({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey[300], fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
