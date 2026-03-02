import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/inventory_item.dart';
import '../models/listing.dart';
import '../services/mock_data_service.dart';
import 'add_edit_card_screen.dart';

class CardDetailScreen extends StatefulWidget {
  final InventoryItem item;
  const CardDetailScreen({super.key, required this.item});

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> {
  final currency = NumberFormat.currency(symbol: '\$');
  final dateFormat = DateFormat('MMM d, yyyy');

  // In real app these come from API; here we pull from mock
  late List<Listing> _listings;

  @override
  void initState() {
    super.initState();
    _listings = MockDataService.listingsForItem(widget.item.id);
  }

  // Simulates pulling a listing (cancelling it on the platform)
  void _pullListing(Listing listing) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pull from ${listing.platformDisplay}?'),
        content: Text(
          'This will cancel your ${listing.listingTypeDisplay} listing '
          'on ${listing.platformDisplay} for ${currency.format(listing.listedPrice)}. '
          'You can then sell the card here at the show.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _listings = _listings
                    .where((l) => l.id != listing.id)
                    .toList();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Listing pulled from ${listing.platformDisplay}. '
                    'Ready to sell at the table.',
                  ),
                  backgroundColor: AppColors.success,
                  action: SnackBarAction(
                    label: 'Add to Sale',
                    textColor: Colors.black,
                    onPressed: () {
                      // TODO: push to SaleScreen with card pre-loaded
                    },
                  ),
                ),
              );
            },
            child: const Text('Pull Listing'),
          ),
        ],
      ),
    );
  }

  void _shareListingInfo(Listing listing) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShareListingSheet(
        listing: listing,
        item: widget.item,
        currency: currency,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Hero header ─────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 340,
            pinned: true,
            backgroundColor: Colors.black,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: Colors.black),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 60, 0, 16),
                      child: _CardImage(item: widget.item, large: true),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Theme.of(context).scaffoldBackgroundColor,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AddEditCardScreen(existingItem: widget.item),
                  ),
                ).then((result) {
                  if (result == 'deleted') Navigator.pop(context);
                }),
              ),
            ],
          ),

          // ── Content ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + graded badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.item.cardName,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (widget.item.isGraded &&
                          widget.item.gradingCompany != null)
                        Container(
                          margin: const EdgeInsets.only(top: 4, left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.warning.withOpacity(0.4)),
                          ),
                          child: Text(
                            '${widget.item.gradingCompany} ${widget.item.grade}',
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 4),
                  Text(
                    '${widget.item.game} · ${widget.item.setName} · #${widget.item.cardNumber}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 14),
                  ),

                  const SizedBox(height: 16),

                  Wrap(
                    spacing: 8,
                    children: [
                      _Tag(widget.item.condition, AppColors.textSecondary),
                      if (widget.item.finish != 'normal')
                        _Tag(widget.item.finishDisplay, AppColors.info),
                      if (widget.item.language != 'English')
                        _Tag(widget.item.language, AppColors.accent),
                    ],
                  ),

                  // ── Active listings ─────────────────────────────────────
                  if (_listings.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    const _SectionDivider('Listed On'),
                    const SizedBox(height: 12),
                    ..._listings.map((listing) => _ListingCard(
                          listing: listing,
                          currency: currency,
                          onPull: () => _pullListing(listing),
                          onShare: () => _shareListingInfo(listing),
                        )),
                  ],

                  // ── Pricing ─────────────────────────────────────────────
                  const SizedBox(height: 24),
                  const _SectionDivider('Pricing'),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _PriceCell(
                          label: 'Asking Price',
                          value: widget.item.askingPrice != null
                              ? currency.format(widget.item.askingPrice)
                              : '—',
                          color: AppColors.accent,
                          large: true,
                        ),
                      ),
                      Expanded(
                        child: _PriceCell(
                          label: 'Market Price',
                          value: widget.item.marketPrice != null
                              ? currency.format(widget.item.marketPrice)
                              : '—',
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _PriceCell(
                          label: 'Purchase Price',
                          value: widget.item.purchasePrice != null
                              ? currency.format(widget.item.purchasePrice)
                              : '—',
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Expanded(
                        child: _PriceCell(
                          label: 'Profit Margin',
                          value: widget.item.profitMargin != null
                              ? currency.format(widget.item.profitMargin)
                              : '—',
                          color: (widget.item.profitMargin ?? 0) >= 0
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                      ),
                    ],
                  ),

                  if (widget.item.marketMarkup != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _markupColor(widget.item.marketMarkup!)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _markupColor(widget.item.marketMarkup!)
                              .withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            widget.item.marketMarkup! >= 0
                                ? Icons.trending_up
                                : Icons.trending_down,
                            color: _markupColor(widget.item.marketMarkup!),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.item.marketMarkup! >= 0
                                ? 'Priced ${widget.item.marketMarkup!.abs().toStringAsFixed(1)}% above market'
                                : 'Priced ${widget.item.marketMarkup!.abs().toStringAsFixed(1)}% below market',
                            style: TextStyle(
                              color: _markupColor(widget.item.marketMarkup!),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Card details ────────────────────────────────────────
                  const SizedBox(height: 24),
                  const _SectionDivider('Card Details'),
                  const SizedBox(height: 12),

                  _DetailRow('Game', widget.item.game),
                  _DetailRow('Set', widget.item.setName),
                  _DetailRow('Card Number', widget.item.cardNumber),
                  _DetailRow('Condition', widget.item.condition),
                  _DetailRow('Finish', widget.item.finishDisplay),
                  _DetailRow('Language', widget.item.language),
                  if (widget.item.isGraded) ...[
                    _DetailRow('Grading Company',
                        widget.item.gradingCompany ?? '—'),
                    _DetailRow('Grade', widget.item.grade ?? '—'),
                  ],
                  _DetailRow('Quantity', '${widget.item.quantity}'),
                  _DetailRow(
                      'Acquired', dateFormat.format(widget.item.acquiredDate)),

                  if (widget.item.notes != null &&
                      widget.item.notes!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const _SectionDivider('Notes'),
                    const SizedBox(height: 12),
                    Text(
                      widget.item.notes!,
                      style: const TextStyle(
                          color: AppColors.textSecondary, height: 1.5),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // ── Action buttons ──────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.point_of_sale),
                          label: const Text('Add to Sale'),
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () =>
                              ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Add to sale coming soon!')),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit Card'),
                          style: ElevatedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddEditCardScreen(
                                  existingItem: widget.item),
                            ),
                          ).then((result) {
                            if (result == 'deleted')
                              Navigator.pop(context);
                          }),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _markupColor(double markup) {
    if (markup > 10) return AppColors.success;
    if (markup >= 0) return AppColors.accent;
    return AppColors.warning;
  }
}

// ── Listing Card ──────────────────────────────────────────────────────────────

class _ListingCard extends StatelessWidget {
  final Listing listing;
  final NumberFormat currency;
  final VoidCallback onPull;
  final VoidCallback onShare;

  const _ListingCard({
    required this.listing,
    required this.currency,
    required this.onPull,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final color = _platformColor(listing.platform);
    final timeFormat = DateFormat('MMM d, yyyy');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        children: [
          // Header row — platform + type + price
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                // Platform icon badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_platformIcon(listing.platform),
                          size: 14, color: color),
                      const SizedBox(width: 6),
                      Text(
                        listing.platformDisplay,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Listing type chip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.darkSurfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    listing.listingTypeDisplay,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const Spacer(),

                // Listed price
                Text(
                  currency.format(listing.listedPrice),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Meta row — listed date, auction end if applicable
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'Listed ${timeFormat.format(listing.listedAt)}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                if (listing.isAuction && listing.endsAt != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.timer_outlined,
                      size: 12, color: AppColors.warning),
                  const SizedBox(width: 4),
                  Text(
                    'Ends ${timeFormat.format(listing.endsAt!)}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.warning),
                  ),
                ],
                if (listing.notes != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      listing.notes!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),

          // Action buttons
          IntrinsicHeight(
            child: Row(
              children: [
                // Share listing info with customer
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.share_outlined, size: 16),
                    label: const Text('Share Info',
                        style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: onShare,
                  ),
                ),

                VerticalDivider(
                  width: 1,
                  color: AppColors.darkDivider,
                ),

                // Pull from platform and sell in person
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: const Text('Pull & Sell Here',
                        style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: onPull,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _platformColor(String platform) {
    switch (platform) {
      case 'ebay':      return const Color(0xFF86B817); // eBay green
      case 'tcgplayer': return const Color(0xFF1DA0F2); // TCG blue
      case 'comc':      return const Color(0xFFFF6B35); // COMC orange
      case 'whatnot':   return const Color(0xFF9B59B6); // Whatnot purple
      case 'mercari':   return const Color(0xFFE91E8C); // Mercari pink
      default:          return AppColors.accent;
    }
  }

  IconData _platformIcon(String platform) {
    switch (platform) {
      case 'ebay':      return Icons.storefront_outlined;
      case 'tcgplayer': return Icons.style_outlined;
      case 'comc':      return Icons.inventory_outlined;
      case 'whatnot':   return Icons.live_tv_outlined;
      default:          return Icons.sell_outlined;
    }
  }
}

// ── Share Listing Sheet ───────────────────────────────────────────────────────

class _ShareListingSheet extends StatelessWidget {
  final Listing listing;
  final InventoryItem item;
  final NumberFormat currency;

  const _ShareListingSheet({
    required this.listing,
    required this.item,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Listing Info',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Share this with your customer so they can find the listing',
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Card summary
          Text(item.cardName,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 16)),
          Text(
            '${item.setName} · ${item.condition}',
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),

          const SizedBox(height: 16),

          _InfoLine('Platform', listing.platformDisplay),
          _InfoLine('Price', currency.format(listing.listedPrice)),
          _InfoLine('Type', listing.listingTypeDisplay),
          if (listing.platformUrl != null)
            _InfoLine('URL', listing.platformUrl!, isUrl: true),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy Listing URL'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '${listing.platformDisplay} URL copied to clipboard'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  final bool isUrl;
  const _InfoLine(this.label, this.value, {this.isUrl = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isUrl ? AppColors.info : AppColors.textPrimary,
                decoration: isUrl ? TextDecoration.underline : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card Image (reused in list + detail) ─────────────────────────────────────

class CardImage extends StatelessWidget {
  final InventoryItem item;
  final bool large;
  const CardImage({super.key, required this.item, this.large = false});

  @override
  Widget build(BuildContext context) => _CardImage(item: item, large: large);
}

class _CardImage extends StatelessWidget {
  final InventoryItem item;
  final bool large;
  const _CardImage({required this.item, this.large = false});

  @override
  Widget build(BuildContext context) {
    final width = large ? 180.0 : 48.0;
    final height = large ? 252.0 : 67.0;
    final radius = large ? 10.0 : 4.0;

    if (item.imageUrl == null) {
      return _Placeholder(
          width: width, height: height, radius: radius, item: item);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        item.imageUrl!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _Placeholder(
              width: width,
              height: height,
              radius: radius,
              item: item,
              loading: true);
        },
        errorBuilder: (context, error, stack) =>
            _Placeholder(width: width, height: height, radius: radius, item: item),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final double width, height, radius;
  final InventoryItem item;
  final bool loading;
  const _Placeholder({
    required this.width,
    required this.height,
    required this.radius,
    required this.item,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = _gameColor(item.game);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: loading
          ? Center(
              child: SizedBox(
                width: width * 0.4,
                height: width * 0.4,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: color.withOpacity(0.6)),
              ),
            )
          : Center(
              child: Icon(Icons.style_outlined,
                  color: color.withOpacity(0.5), size: width < 60 ? 20 : 48),
            ),
    );
  }

  Color _gameColor(String game) {
    switch (game.toLowerCase()) {
      case 'pokemon':               return const Color(0xFFFFCC00);
      case 'magic: the gathering':  return const Color(0xFFBF360C);
      case 'one piece':             return const Color(0xFFFF5722);
      case 'final fantasy':         return const Color(0xFF1565C0);
      default:                      return AppColors.accent;
    }
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _SectionDivider extends StatelessWidget {
  final String title;
  const _SectionDivider(this.title);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.accent,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _PriceCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool large;
  const _PriceCell(
      {required this.label,
      required this.value,
      required this.color,
      this.large = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                color: color,
                fontSize: large ? 22 : 16,
                fontWeight: FontWeight.w800,
              )),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style:
                    const TextStyle(color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
