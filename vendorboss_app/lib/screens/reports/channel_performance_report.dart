import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../../theme/app_theme.dart';
import '../../services/mock_data_service.dart';
import '../../models/show.dart';

class ChannelPerformanceReport extends StatelessWidget {
  const ChannelPerformanceReport({super.key});

  static const int _months = 6;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$');

    // Only channels the vendor has connected
    final connectedKeys = MockDataService.connectedPlatformKeys;

    // All channels with actual sales
    final allChannels = MockDataService.channelPerformance;

    // Split: connected with sales vs untracked (sales exist but not connected)
    final connected   = allChannels.where((c) => connectedKeys.contains(c.channel)).toList();
    final untracked   = allChannels.where((c) => !connectedKeys.contains(c.channel)).toList();

    // Platforms connected but with no sales yet
    final connectedNoSales = MockDataService.connectedChannels
        .where((cc) => cc.isConnected &&
            !allChannels.any((c) => c.channel == cc.platform))
        .toList();

    final totalRevenue = connected.fold(0.0, (s, c) => s + c.revenue);
    final totalNet     = connected.fold(0.0, (s, c) => s + c.netProfit);
    final totalFees    = connected.fold(0.0, (s, c) => s + c.fees);

    // Monthly data for trend chart (connected channels only)
    final monthly = MockDataService.channelMonthlyRevenue(months: _months);
    final monthlyConnected = Map.fromEntries(
      monthly.entries.where((e) => connectedKeys.contains(e.key)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Channel Performance'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.add_link, size: 16),
            label: const Text('Connect'),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Marketplace connections — coming soon')),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [

          // ── Summary strip ─────────────────────────────────────────────
          Row(children: [
            Expanded(child: _StatCard('Gross Revenue', currency.format(totalRevenue), AppColors.accent)),
            const SizedBox(width: 8),
            Expanded(child: _StatCard('Platform Fees',  currency.format(totalFees),    AppColors.danger)),
            const SizedBox(width: 8),
            Expanded(child: _StatCard('Net Profit',     currency.format(totalNet),
                totalNet >= 0 ? AppColors.success : AppColors.danger)),
          ]),

          const SizedBox(height: 24),

          // ── Revenue trend line chart ──────────────────────────────────
          const _Label('REVENUE TREND — LAST 6 MONTHS'),
          const SizedBox(height: 4),
          const Text(
            'Which channels are growing?',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          _TrendChart(monthly: monthlyConnected, months: _months),

          const SizedBox(height: 24),

          // ── Revenue share (composition — bar is correct here) ─────────
          const _Label('REVENUE SHARE BY CHANNEL'),
          const SizedBox(height: 12),
          ...connected.map((c) => _ChannelBar(
                channel:      c,
                totalRevenue: totalRevenue,
                currency:     currency,
              )),

          const SizedBox(height: 24),

          // ── Detailed per-channel cards ────────────────────────────────
          const _Label('DETAILED BREAKDOWN'),
          const SizedBox(height: 12),
          ...connected.map((c) => _ChannelCard(
                channel:   c,
                currency:  currency,
                connected: MockDataService.connectedChannels
                    .where((cc) => cc.platform == c.channel)
                    .firstOrNull,
              )),

          // ── Connected but no sales yet ────────────────────────────────
          if (connectedNoSales.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...connectedNoSales.map((cc) => _ConnectedEmptyCard(channel: cc)),
          ],

          // ── Untracked channels (sales exist, not connected) ───────────
          if (untracked.isNotEmpty) ...[
            const SizedBox(height: 20),
            const _Label('UNTRACKED CHANNELS'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:        AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border:       Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_outlined,
                    size: 16, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sales detected on ${untracked.map((c) => c.channelDisplay).join(', ')}. '
                    'Connect these accounts for exact fee data and full attribution.',
                    style: const TextStyle(
                        color: AppColors.warning, fontSize: 12, height: 1.4),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            ...untracked.map((c) => _UntrackedCard(channel: c, currency: currency)),
          ],

          const SizedBox(height: 20),

          // ── Fee disclaimer ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:        AppColors.darkSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Platform fees are estimated: TCGPlayer 12.75%, eBay 13.35%, '
                    'Whatnot 8%, COMC 10%, In-person 2% (card processing only). '
                    'Connect marketplace accounts for exact figures pulled directly '
                    'from your seller dashboards.',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Revenue trend line chart ──────────────────────────────────────────────────

class _TrendChart extends StatelessWidget {
  final Map<String, List<double>> monthly;
  final int months;

  const _TrendChart({required this.monthly, required this.months});

  @override
  Widget build(BuildContext context) {
    if (monthly.isEmpty) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.darkSurface, borderRadius: BorderRadius.circular(12)),
        child: const Text('No data yet.',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    final now        = DateTime.now();
    final monthLabels = List.generate(months, (i) {
      final dt = DateTime(now.year, now.month - (months - 1 - i));
      return DateFormat('MMM').format(dt);
    });

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.darkSurface, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: monthly.keys.map((ch) => _Legend(
              _channelLabel(ch), _channelColor(ch))).toList(),
          ),
          const SizedBox(height: 12),

          // Chart
          SizedBox(
            height: 130,
            child: CustomPaint(
              painter: _MultiLinePainter(monthly: monthly),
              child: const SizedBox.expand(),
            ),
          ),

          const SizedBox(height: 8),

          // X-axis month labels
          Row(
            children: monthLabels.map((m) => Expanded(
              child: Text(m,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 9)),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _MultiLinePainter extends CustomPainter {
  final Map<String, List<double>> monthly;
  const _MultiLinePainter({required this.monthly});

  @override
  void paint(Canvas canvas, Size size) {
    if (monthly.isEmpty) return;

    final allValues = monthly.values.expand((v) => v);
    final maxVal    = allValues.reduce(math.max).clamp(1.0, double.infinity);
    const minVal    = 0.0;

    for (final entry in monthly.entries) {
      final color  = _channelColor(entry.key);
      final values = entry.value;
      if (values.length < 2) continue;

      final step = size.width / (values.length - 1);
      final pts  = <Offset>[];

      for (int i = 0; i < values.length; i++) {
        pts.add(Offset(
          i * step,
          size.height - ((values[i] - minVal) / (maxVal - minVal)) * size.height * 0.9 - 4,
        ));
      }

      // Fill
      final fill = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length; i++) {
        final cp1 = Offset((pts[i-1].dx + pts[i].dx) / 2, pts[i-1].dy);
        final cp2 = Offset((pts[i-1].dx + pts[i].dx) / 2, pts[i].dy);
        fill.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i].dx, pts[i].dy);
      }
      fill
        ..lineTo(pts.last.dx, size.height)
        ..lineTo(pts.first.dx, size.height)
        ..close();

      canvas.drawPath(fill, Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end:   Alignment.bottomCenter,
          colors: [color.withOpacity(0.15), color.withOpacity(0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill);

      // Line
      final line = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length; i++) {
        final cp1 = Offset((pts[i-1].dx + pts[i].dx) / 2, pts[i-1].dy);
        final cp2 = Offset((pts[i-1].dx + pts[i].dx) / 2, pts[i].dy);
        line.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i].dx, pts[i].dy);
      }
      canvas.drawPath(line, Paint()
        ..color       = color
        ..strokeWidth = 2.0
        ..style       = PaintingStyle.stroke
        ..strokeCap   = StrokeCap.round
        ..strokeJoin  = StrokeJoin.round);

      // Dots
      for (final pt in pts) {
        canvas.drawCircle(pt, 3.5, Paint()..color = color);
        canvas.drawCircle(pt, 3.5, Paint()
          ..color       = AppColors.darkSurface
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 1.5);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MultiLinePainter old) => old.monthly != monthly;
}

// ── Channel bar (share) ───────────────────────────────────────────────────────

class _ChannelBar extends StatelessWidget {
  final ChannelPerf channel;
  final double totalRevenue;
  final NumberFormat currency;
  const _ChannelBar({required this.channel, required this.totalRevenue, required this.currency});

  @override
  Widget build(BuildContext context) {
    final pct   = totalRevenue > 0 ? channel.revenue / totalRevenue : 0.0;
    final color = _channelColor(channel.channel);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(channel.channelDisplay,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
            Text('${(pct * 100).toStringAsFixed(0)}%  ·  ${currency.format(channel.revenue)}',
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
          ]),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:           pct,
              minHeight:       8,
              backgroundColor: AppColors.darkSurfaceElevated,
              valueColor:      AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Detailed channel card ─────────────────────────────────────────────────────

class _ChannelCard extends StatelessWidget {
  final ChannelPerf channel;
  final NumberFormat currency;
  final ConnectedChannel? connected;
  const _ChannelCard({required this.channel, required this.currency, this.connected});

  @override
  Widget build(BuildContext context) {
    final color     = _channelColor(channel.channel);
    final marginPct = channel.revenue > 0
        ? (channel.netProfit / channel.revenue) * 100
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color:        color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border:       Border.all(color: color.withOpacity(0.35)),
                ),
                child: Text(channel.channelDisplay,
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              const SizedBox(width: 8),
              // Connected badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color:        AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.link, size: 10, color: AppColors.success),
                  const SizedBox(width: 3),
                  Text(
                    connected?.accountLabel ?? 'Connected',
                    style: const TextStyle(
                        color: AppColors.success, fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                ]),
              ),
              const Spacer(),
              Text('${channel.txCount} sales',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ]),

            const SizedBox(height: 12),
            _Line('Gross Revenue', currency.format(channel.revenue),    AppColors.textPrimary),
            _Line('Platform Fees', '− ${currency.format(channel.fees)}', AppColors.danger),
            _Line('Est. COGS',     '− ${currency.format(channel.cogs)}', AppColors.textSecondary),
            const Divider(height: 16),
            _Line('Net Profit', currency.format(channel.netProfit),
                channel.netProfit >= 0 ? AppColors.success : AppColors.danger, bold: true),

            const SizedBox(height: 8),
            Text('${marginPct.toStringAsFixed(1)}% net margin',
                style: TextStyle(
                  color:      marginPct >= 20 ? AppColors.success : AppColors.warning,
                  fontSize:   12,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }
}

// ── Connected but zero sales card ────────────────────────────────────────────

class _ConnectedEmptyCard extends StatelessWidget {
  final ConnectedChannel channel;
  const _ConnectedEmptyCard({required this.channel});

  @override
  Widget build(BuildContext context) {
    final color = _channelColor(channel.platform);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:        color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border:       Border.all(color: color.withOpacity(0.35)),
            ),
            child: Text(channel.displayName,
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color:        AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.link, size: 10, color: AppColors.success),
              SizedBox(width: 3),
              Text('Connected', style: TextStyle(
                  color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w600)),
            ]),
          ),
          const Spacer(),
          const Text('No sales yet',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ]),
      ),
    );
  }
}

// ── Untracked channel card ────────────────────────────────────────────────────

class _UntrackedCard extends StatelessWidget {
  final ChannelPerf channel;
  final NumberFormat currency;
  const _UntrackedCard({required this.channel, required this.currency});

  @override
  Widget build(BuildContext context) {
    final color = _channelColor(channel.channel);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color:        color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border:       Border.all(color: color.withOpacity(0.25)),
                ),
                child: Text(channel.channelDisplay,
                    style: TextStyle(color: color.withOpacity(0.7),
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color:        AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.link_off, size: 10, color: AppColors.warning),
                  SizedBox(width: 3),
                  Text('Not connected', style: TextStyle(
                      color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.w600)),
                ]),
              ),
              const Spacer(),
              Text('${channel.txCount} sales',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Text(
                  'Revenue: ${currency.format(channel.revenue)}  ·  '
                  'Fees estimated (may be inaccurate)',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Marketplace connections — coming soon')),
                ),
                child: const Text('Connect →', style: TextStyle(fontSize: 12)),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Color _channelColor(String channel) {
  switch (channel) {
    case 'in_person':  return AppColors.accent;
    case 'tcgplayer':  return const Color(0xFF1DA0F2);
    case 'ebay':       return const Color(0xFF86B817);
    case 'whatnot':    return const Color(0xFF9B59B6);
    case 'comc':       return const Color(0xFFFF6B35);
    default:           return AppColors.textSecondary;
  }
}

String _channelLabel(String channel) {
  switch (channel) {
    case 'in_person':  return 'In-Person';
    case 'tcgplayer':  return 'TCGPlayer';
    case 'ebay':       return 'eBay';
    case 'whatnot':    return 'Whatnot';
    case 'comc':       return 'COMC';
    default:           return channel;
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
        color: AppColors.darkSurface, borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14),
          maxLines: 1, overflow: TextOverflow.ellipsis),
    ]),
  );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
          color: AppColors.textSecondary, letterSpacing: 1.2));
}

class _Legend extends StatelessWidget {
  final String label;
  final Color color;
  const _Legend(this.label, this.color);

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 5),
    Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
  ]);
}

class _Line extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool bold;
  const _Line(this.label, this.value, this.color, {this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(
          color: AppColors.textSecondary,
          fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
          fontSize: 13))),
      Text(value, style: TextStyle(
          color: color,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          fontSize: 13)),
    ]),
  );
}
