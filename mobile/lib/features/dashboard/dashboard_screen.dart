import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_messages.dart';
import '../../core/widgets/varanti_brand.dart';
import '../../data/models/warranty_model.dart';
import '../notifications/notification_service.dart';
import '../profile/profile_avatar_button.dart';
import '../settings/settings_screen.dart';
import '../timeline/timeline_screen.dart';
import '../vault/vault_screen.dart';
import '../warranties/warranty_detail_screen.dart';
import '../warranties/widgets/warranty_card.dart';
import 'scan_flow.dart';
import 'widgets/warranty_charts.dart';

/// Main Navigation Shell hosting Screen 2 (Home Dashboard + Visual Graphs),
/// Screen 3 (Vault), Center Quick-Scan Crimson CTA, and Screen 6 (Settings).
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedIndex = 0;
  String? _lastSyncedSignature;
  DateTime? _lastBackPress;

  void _syncNotifications(
    List<WarrantyModel> warranties,
    NotificationSettings notifSettings,
  ) {
    final sig =
        '${notifSettings.enabled}:${notifSettings.activeLeadDays.join(',')}:${notifSettings.reminderHour}:${notifSettings.reminderMinute}|'
        '${warranties.map((w) => '${w.id}@${w.warrantyExpirationDate.toIso8601String()}').join(';')}';
    if (sig == _lastSyncedSignature) return;
    _lastSyncedSignature = sig;

    NotificationService.instance.syncAllWarranties(warranties, notifSettings);
  }

  void _openVaultWithStatus(String? statusFilter) {
    final notifier = ref.read(warrantyFilterProvider.notifier);
    notifier.clearAll();
    if (statusFilter != null) {
      notifier.updateStatus(statusFilter);
    }
    setState(() => _selectedIndex = 1);
  }

  @override
  Widget build(BuildContext context) {
    final notifSettings = ref.watch(notificationSettingsProvider);
    final warrantiesAsync = ref.watch(warrantiesStreamProvider);
    final hairline = AppTheme.hairlineOf(context);
    final crimson = AppTheme.crimsonOf(context);

    ref.listen<AsyncValue<List<WarrantyModel>>>(warrantiesStreamProvider, (_, next) {
      next.whenData((list) => _syncNotifications(list, notifSettings));
    });

    warrantiesAsync.whenData((list) => _syncNotifications(list, notifSettings));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
          return;
        }
        final now = DateTime.now();
        if (_lastBackPress == null ||
            now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
          _lastBackPress = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit Varanti'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        Navigator.of(context).maybePop();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            _HomeDashboardTab(
              onSeeAllVault: () => _openVaultWithStatus(null),
              onFilterStatus: _openVaultWithStatus,
            ),
            const VaultScreen(),
            TimelineScreen(
              onOpenSettings: () => setState(() => _selectedIndex = 3),
            ),
            const SettingsScreen(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: hairline)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _NavTabButton(
                      icon: Icons.space_dashboard_outlined,
                      activeIcon: Icons.space_dashboard_rounded,
                      label: 'Home',
                      selected: _selectedIndex == 0,
                      onTap: () => setState(() => _selectedIndex = 0),
                    ),
                  ),
                  Expanded(
                    child: _NavTabButton(
                      icon: Icons.inventory_2_outlined,
                      activeIcon: Icons.inventory_2_rounded,
                      label: 'Vault',
                      selected: _selectedIndex == 1,
                      onTap: () => setState(() => _selectedIndex = 1),
                    ),
                  ),
                  // Symmetrical Center Crimson Scan Orb (SRS 4.1 UI-02)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Tooltip(
                      message: 'Scan Receipt',
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: crimson.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Material(
                          color: crimson,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () =>
                                ScanFlowHelper.showSourcePicker(context, ref),
                            child: const SizedBox(
                              width: 46,
                              height: 46,
                              child: Icon(
                                Icons.document_scanner_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _NavTabButton(
                      icon: Icons.calendar_month_outlined,
                      activeIcon: Icons.calendar_month_rounded,
                      label: 'Timeline',
                      selected: _selectedIndex == 2,
                      onTap: () => setState(() => _selectedIndex = 2),
                    ),
                  ),
                  Expanded(
                    child: _NavTabButton(
                      icon: Icons.tune_outlined,
                      activeIcon: Icons.tune_rounded,
                      label: 'Settings',
                      selected: _selectedIndex == 3,
                      onTap: () => setState(() => _selectedIndex = 3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeDashboardTab extends ConsumerWidget {
  final VoidCallback onSeeAllVault;
  final void Function(String? statusFilter) onFilterStatus;

  const _HomeDashboardTab({
    required this.onSeeAllVault,
    required this.onFilterStatus,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final warrantiesAsync = ref.watch(warrantiesStreamProvider);
    final hairline = AppTheme.hairlineOf(context);
    final muted = AppTheme.mutedTextOf(context);
    final crimson = AppTheme.crimsonOf(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const VarantiWordmark(height: 22),
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
              Icon(Icons.cloud_off_rounded, size: 44, color: crimson),
              const SizedBox(height: 12),
              Text(
                ErrorMessages.friendly(
                  err,
                  fallback: "Couldn't load your warranties right now.",
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 18),
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
            final expiringSoon = warranties
                .where((w) => w.status == 'expiring_soon')
                .toList()
              ..sort(
                (a, b) =>
                    a.warrantyExpirationDate.compareTo(b.warrantyExpirationDate),
              );

            final recentPreview = warranties.take(5).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                if (authState.isMigrating) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: hairline),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: crimson,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Backing up your saved receipts to the cloud...',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (authState.isGuest) ...[
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
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppTheme.getStatusSoftBg(
                              'expiring_soon',
                              Theme.of(context).brightness,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.cloud_upload_outlined,
                            size: 19,
                            color: AppTheme.statusExpiringSoon,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Saved on this device',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Sign in to enable auto receipt scan and cloud backup.',
                                style: TextStyle(fontSize: 11, color: muted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            ref.read(authProvider.notifier).signOut();
                          },
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                          ),
                          child: const Text('Sign In', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                if (warranties.isEmpty)
                  _MinimalEmptyState(
                    onScan: () => ScanFlowHelper.showSourcePicker(context, ref),
                  )
                else ...[
                  // Visual Graph 1: Coverage Donut Ring
                  WarrantyCoverageDonutCard(
                    warranties: warranties,
                    onStatusTap: onFilterStatus,
                  ),
                  const SizedBox(height: 14),

                  // Visual Graph 2: 6-Month Expirations / Categories
                  WarrantyTrendsChartCard(warranties: warranties),
                  const SizedBox(height: 22),

                  // Expiring Soon Spotlight Strip
                  if (expiringSoon.isNotEmpty) ...[
                    Row(
                      children: [
                        Text(
                          'EXPIRING SOON',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                            color: muted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: ShapeDecoration(
                            color: AppTheme.getStatusSoftBg(
                              'expiring_soon',
                              Theme.of(context).brightness,
                            ),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            '${expiringSoon.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.statusExpiringSoon,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 116,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: expiringSoon.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (ctx, i) {
                          final item = expiringSoon[i];
                          return _ExpiringSpotlightCard(item: item);
                        },
                      ),
                    ),
                    const SizedBox(height: 22),
                  ],

                  // Upcoming / Recent Warranties Header
                  Row(
                    children: [
                      Text(
                        'YOUR WARRANTIES',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: muted,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: onSeeAllVault,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                        iconAlignment: IconAlignment.end,
                        label: const Text('See All', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...recentPreview.map((item) => WarrantyListCard(item: item)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ExpiringSpotlightCard extends StatelessWidget {
  final WarrantyModel item;

  const _ExpiringSpotlightCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final hairline = AppTheme.hairlineOf(context);
    final muted = AppTheme.mutedTextOf(context);
    final brightness = Theme.of(context).brightness;

    return SizedBox(
      width: 210,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: ShapeDecoration(
                        color: AppTheme.getStatusSoftBg(
                          'expiring_soon',
                          brightness,
                        ),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        '${item.daysRemaining}d left',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.statusExpiringSoon,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded, size: 18, color: muted),
                  ],
                ),
                const Spacer(),
                Text(
                  item.itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ends ${item.formattedExpirationDate}',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MinimalEmptyState extends StatelessWidget {
  final VoidCallback onScan;

  const _MinimalEmptyState({required this.onScan});

  @override
  Widget build(BuildContext context) {
    final hairline = AppTheme.hairlineOf(context);
    final muted = AppTheme.mutedTextOf(context);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hairline),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.subtleSurfaceOf(context),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const VarantiMark(size: 40),
          ),
          const SizedBox(height: 20),
          const Text(
            'Your warranty vault is empty',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan your first receipt to track coverage dates, see visual expiry graphs, and export claim PDFs anytime.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: muted, height: 1.45),
          ),
          const SizedBox(height: 22),
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

class _NavTabButton extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavTabButton({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = AppTheme.mutedTextOf(context);
    final subtle = AppTheme.subtleSurfaceOf(context);

    return Material(
      color: selected ? subtle : Colors.transparent,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? activeIcon : icon,
                size: 20,
                color: selected ? onSurface : muted,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? onSurface : muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
