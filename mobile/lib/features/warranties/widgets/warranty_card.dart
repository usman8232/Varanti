import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/warranty_model.dart';
import '../warranty_detail_screen.dart';

/// Capsule status pill matching Varanti's minimalist semantic tokens.
class WarrantyStatusPill extends StatelessWidget {
  final String status;

  const WarrantyStatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final fg = AppTheme.getStatusColor(status);
    final bg = AppTheme.getStatusSoftBg(status, brightness);
    final label = AppTheme.getStatusLabel(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: ShapeDecoration(
        color: bg,
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Minimalist flat warranty list card with 1px hairline border and pill status badge.
class WarrantyListCard extends StatelessWidget {
  final WarrantyModel item;
  final VoidCallback? onTap;

  const WarrantyListCard({
    super.key,
    required this.item,
    this.onTap,
  });

  static IconData categoryIcon(String category) {
    switch (category) {
      case 'Home Appliances':
        return Icons.kitchen_rounded;
      case 'Computing':
        return Icons.laptop_mac_rounded;
      case 'Audio':
        return Icons.headphones_rounded;
      case 'Power Tools':
        return Icons.build_rounded;
      case 'Consumer Tech':
        return Icons.devices_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = AppTheme.getStatusColor(item.status);
    final hairline = AppTheme.hairlineOf(context);
    final subtle = AppTheme.subtleSurfaceOf(context);
    final muted = AppTheme.mutedTextOf(context);

    final countdownText = item.daysRemaining > 0
        ? '${item.daysRemaining}d left'
        : item.daysRemaining == 0
            ? 'Expired today'
            : '${item.daysRemaining.abs()}d ago';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: hairline),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap ??
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => WarrantyDetailScreen(warranty: item),
                  ),
                );
              },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: subtle,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    categoryIcon(item.category),
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.itemName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          WarrantyStatusPill(status: item.status),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (item.merchantName != null &&
                              item.merchantName!.isNotEmpty)
                            item.merchantName!,
                          item.category,
                        ].join(' | '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.event_outlined,
                            size: 13,
                            color: muted,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Ends ${item.formattedExpirationDate}',
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                          const Spacer(),
                          if (item.pricePaid != null) ...[
                            Text(
                              item.formattedPrice,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: muted,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Text(
                            countdownText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
