import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_messages.dart';
import '../../core/widgets/varanti_brand.dart';
import '../../data/models/warranty_model.dart';
import '../dashboard/scan_flow.dart';
import '../profile/profile_avatar_button.dart';
import '../warranties/warranty_detail_screen.dart';
import '../warranties/widgets/warranty_card.dart';

/// Dedicated Timeline & Expiry Alerts tab grouping warranties chronologically
/// into actionable coverage windows.
class TimelineScreen extends ConsumerWidget {
  final VoidCallback onOpenSettings;

  const TimelineScreen({
    super.key,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warrantiesAsync = ref.watch(warrantiesStreamProvider);
    final notifSettings = ref.watch(notificationSettingsProvider);
    final hairline = AppTheme.hairlineOf(context);
    final muted = AppTheme.mutedTextOf(context);
    final crimson = AppTheme.crimsonOf(context);

    final reminderTime = TimeOfDay(
      hour: notifSettings.reminderHour,
      minute: notifSettings.reminderMinute,
    ).format(context);

    final activeDaysLabel = notifSettings.activeLeadDays.isEmpty
        ? 'No alert windows selected'
        : notifSettings.activeLeadDays
            .map((d) => d == 1 ? '24h' : '${d}d')
            .join(', ');

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Timeline'),
        actions: const [ProfileAvatarButton()],
      ),
      body: RefreshIndicator(
        color: crimson,
        onRefresh: () async {
          ref.invalidate(warrantiesStreamProvider);
          await ref.read(warrantiesStreamProvider.future);
        },
        child: warrantiesAsync.when(
          loading: () => Center(
            child: CircularProgressIndicator(color: crimson, strokeWidth: 2.5),
          ),
          error: (err, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 80),
              Icon(Icons.cloud_off_rounded, size: 42, color: crimson),
              const SizedBox(height: 12),
              Text(
                ErrorMessages.friendly(
                  err,
                  fallback: "Couldn't load your expiry timeline right now.",
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  onPressed: () => ref.invalidate(warrantiesStreamProvider),
                  label: const Text('Try Again'),
                ),
              ),
            ],
          ),
          data: (warranties) {
            final urgent = warranties
                .where((w) => w.daysRemaining >= 1 && w.daysRemaining <= 7)
                .toList()
              ..sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));

            final thisMonth = warranties
                .where((w) => w.daysRemaining >= 8 && w.daysRemaining <= 30)
                .toList()
              ..sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));

            final upcoming = warranties
                .where((w) => w.daysRemaining > 30)
                .toList()
              ..sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));

            final expired = warranties
                .where((w) => w.daysRemaining <= 0)
                .toList()
              ..sort((a, b) => b.daysRemaining.compareTo(a.daysRemaining));

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                // Alert Schedule Status Pill Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: hairline),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: notifSettings.enabled
                              ? crimson.withValues(alpha: 0.12)
                              : AppTheme.subtleSurfaceOf(context),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          notifSettings.enabled
                              ? Icons.notifications_active_outlined
                              : Icons.notifications_off_outlined,
                          size: 20,
                          color: notifSettings.enabled ? crimson : muted,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notifSettings.enabled
                                  ? 'Expiry Alerts Active'
                                  : 'Expiry Alerts Paused',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              notifSettings.enabled
                                  ? '$activeDaysLabel before expiry at $reminderTime'
                                  : 'Turn on reminders in Settings to stay ahead',
                              style: TextStyle(fontSize: 11, color: muted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onPressed: onOpenSettings,
                        child: const Text('Configure', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                if (warranties.isEmpty)
                  _TimelineEmptyState(
                    onScan: () => ScanFlowHelper.showSourcePicker(context, ref),
                  )
                else ...[
                  if (urgent.isNotEmpty) ...[
                    _TimelineSection(
                      title: 'NEXT 7 DAYS',
                      accentColor: crimson,
                      items: urgent,
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (thisMonth.isNotEmpty) ...[
                    _TimelineSection(
                      title: 'THIS MONTH (8 - 30 DAYS)',
                      accentColor: AppTheme.statusExpiringSoon,
                      items: thisMonth,
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (upcoming.isNotEmpty) ...[
                    _TimelineSection(
                      title: 'UPCOMING COVERAGE',
                      accentColor: AppTheme.statusActive,
                      items: upcoming,
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (expired.isNotEmpty)
                    _TimelineSection(
                      title: 'EXPIRED',
                      accentColor: muted,
                      items: expired,
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TimelineSection extends StatelessWidget {
  final String title;
  final Color accentColor;
  final List<WarrantyModel> items;

  const _TimelineSection({
    required this.title,
    required this.accentColor,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final hairline = AppTheme.hairlineOf(context);
    final muted = AppTheme.mutedTextOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
                color: muted,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: ShapeDecoration(
                color: AppTheme.subtleSurfaceOf(context),
                shape: const StadiumBorder(),
              ),
              child: Text(
                '${items.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: muted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...items.map((item) {
          final countdown = item.daysRemaining > 0
              ? 'In ${item.daysRemaining}d'
              : item.daysRemaining == 0
                  ? 'Today'
                  : '${item.daysRemaining.abs()}d ago';

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 3,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: hairline),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => WarrantyDetailScreen(warranty: item),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.itemName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${item.formattedExpirationDate}${item.merchantName != null && item.merchantName!.isNotEmpty ? ' | ${item.merchantName}' : ''}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12, color: muted),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  WarrantyStatusPill(status: item.status),
                                  const SizedBox(height: 4),
                                  Text(
                                    countdown,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: accentColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _TimelineEmptyState extends StatelessWidget {
  final VoidCallback onScan;

  const _TimelineEmptyState({required this.onScan});

  @override
  Widget build(BuildContext context) {
    final hairline = AppTheme.hairlineOf(context);
    final muted = AppTheme.mutedTextOf(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hairline),
      ),
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.subtleSurfaceOf(context),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const VarantiMark(size: 38),
          ),
          const SizedBox(height: 16),
          const Text(
            'No upcoming expirations yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Scan a receipt to automatically populate your expiry timeline and alert milestones.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: muted, height: 1.4),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            icon: const Icon(Icons.photo_camera_outlined, size: 18),
            label: const Text('Scan First Receipt'),
            onPressed: onScan,
          ),
        ],
      ),
    );
  }
}
