import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_messages.dart';
import '../../core/widgets/varanti_brand.dart';
import '../notifications/notification_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isExporting = false;

  String _formatTime(BuildContext context, int hour, int minute) {
    return TimeOfDay(hour: hour, minute: minute).format(context);
  }

  Future<void> _exportAllJson() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final repo = ref.read(warrantyRepositoryProvider);
      final warranties = await repo.getWarranties();
      if (warranties.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No warranties saved to export yet.')),
          );
        }
        return;
      }

      final payload = {
        'app': 'Varanti',
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'count': warranties.length,
        'warranties': warranties
            .map(
              (w) => {
                'id': w.id,
                'item_name': w.itemName,
                'merchant_name': w.merchantName,
                'category': w.category,
                'purchase_date': DateFormat('yyyy-MM-dd').format(w.purchaseDate),
                'warranty_duration_months': w.warrantyDurationMonths,
                'warranty_expiration_date':
                    DateFormat('yyyy-MM-dd').format(w.warrantyExpirationDate),
                'status': w.status,
                'days_remaining': w.daysRemaining,
                'serial_number': w.serialNumber,
                'price_paid': w.pricePaid,
                'currency': w.currency,
                'notes': w.notes,
              },
            )
            .toList(),
      };

      final tempDir = await getTemporaryDirectory();
      final dateStamp = DateFormat('yyyyMMdd').format(DateTime.now());
      final file = File(p.join(tempDir.path, 'varanti-backup-$dateStamp.json'));
      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(payload));

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: 'Varanti Warranty Backup ($dateStamp)',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ErrorMessages.friendly(
                e,
                fallback: "Couldn't export your data right now. Please try again.",
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _confirmSignOut(bool isGuest) async {
    if (isGuest) {
      await ref.read(authProvider.notifier).signOut();
      return;
    }

    final crimson = AppTheme.crimsonOf(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text(
          'Your warranties remain safely backed up in your account. You can sign back in anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: crimson),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(authProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeModeProvider);
    final notifSettings = ref.watch(notificationSettingsProvider);
    final notifNotifier = ref.read(notificationSettingsProvider.notifier);

    final hairline = AppTheme.hairlineOf(context);
    final subtle = AppTheme.subtleSurfaceOf(context);
    final muted = AppTheme.mutedTextOf(context);
    final crimson = AppTheme.crimsonOf(context);
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // Account & Backup Status Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: hairline),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: subtle,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const VarantiMark(size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authState.isGuest
                            ? 'Guest Mode'
                            : (authState.user?.email ?? 'Signed In'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: ShapeDecoration(
                          color: AppTheme.getStatusSoftBg(
                            authState.isGuest ? 'expiring_soon' : 'active',
                            brightness,
                          ),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          authState.isGuest ? 'Saved on device' : 'Cloud Synced',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: authState.isGuest
                                ? AppTheme.statusExpiringSoon
                                : AppTheme.statusActive,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (authState.isGuest)
                  FilledButton(
                    onPressed: () => _confirmSignOut(true),
                    child: const Text('Sign In', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Appearance Section (SRS 4.1 UI-02)
          Text(
            'APPEARANCE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: muted,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Theme',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: subtle,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ThemeOptionPill(
                          label: 'System',
                          icon: Icons.brightness_auto_outlined,
                          selected: themeMode == ThemeMode.system,
                          onTap: () => ref
                              .read(themeModeProvider.notifier)
                              .setThemeMode(ThemeMode.system),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _ThemeOptionPill(
                          label: 'Light',
                          icon: Icons.light_mode_outlined,
                          selected: themeMode == ThemeMode.light,
                          onTap: () => ref
                              .read(themeModeProvider.notifier)
                              .setThemeMode(ThemeMode.light),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _ThemeOptionPill(
                          label: 'Dark',
                          icon: Icons.dark_mode_outlined,
                          selected: themeMode == ThemeMode.dark,
                          onTap: () => ref
                              .read(themeModeProvider.notifier)
                              .setThemeMode(ThemeMode.dark),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Expiry Alerts Section (SRS FR-NOTIF-01..02)
          Text(
            'EXPIRY ALERTS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: muted,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: hairline),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: crimson,
                  title: const Text(
                    'Enable Expiry Reminders',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Get notified before your warranties expire',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                  value: notifSettings.enabled,
                  onChanged: (val) async {
                    if (val) {
                      await NotificationService.instance.requestPermissions();
                    }
                    await notifNotifier.updateSettings(
                      notifSettings.copyWith(enabled: val),
                    );
                  },
                ),
                Divider(height: 1, color: hairline),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: crimson,
                  title: const Text(
                    '30 days before expiry',
                    style: TextStyle(fontSize: 14),
                  ),
                  value: notifSettings.alert30Days,
                  onChanged: notifSettings.enabled
                      ? (val) => notifNotifier.updateSettings(
                            notifSettings.copyWith(alert30Days: val),
                          )
                      : null,
                ),
                Divider(height: 1, color: hairline),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: crimson,
                  title: const Text(
                    '7 days before expiry',
                    style: TextStyle(fontSize: 14),
                  ),
                  value: notifSettings.alert7Days,
                  onChanged: notifSettings.enabled
                      ? (val) => notifNotifier.updateSettings(
                            notifSettings.copyWith(alert7Days: val),
                          )
                      : null,
                ),
                Divider(height: 1, color: hairline),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: crimson,
                  title: const Text(
                    '24 hours before expiry',
                    style: TextStyle(fontSize: 14),
                  ),
                  value: notifSettings.alert1Day,
                  onChanged: notifSettings.enabled
                      ? (val) => notifNotifier.updateSettings(
                            notifSettings.copyWith(alert1Day: val),
                          )
                      : null,
                ),
                Divider(height: 1, color: hairline),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  enabled: notifSettings.enabled,
                  leading: Icon(Icons.schedule_rounded, size: 20, color: muted),
                  title: const Text(
                    'Daily Reminder Time',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: ShapeDecoration(
                      color: subtle,
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      _formatTime(
                        context,
                        notifSettings.reminderHour,
                        notifSettings.reminderMinute,
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: notifSettings.enabled ? crimson : muted,
                      ),
                    ),
                  ),
                  onTap: notifSettings.enabled
                      ? () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: notifSettings.reminderHour,
                              minute: notifSettings.reminderMinute,
                            ),
                          );
                          if (picked != null) {
                            await notifNotifier.updateSettings(
                              notifSettings.copyWith(
                                reminderHour: picked.hour,
                                reminderMinute: picked.minute,
                              ),
                            );
                          }
                        }
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Data Ownership & Export (SRS FR-DATA-02)
          Text(
            'DATA OWNERSHIP',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: muted,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Export Your Warranties',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Download all your saved warranty records as a clean JSON file anytime with zero restrictions.',
                  style: TextStyle(fontSize: 12, color: muted, height: 1.4),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  icon: _isExporting
                      ? SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.download_rounded, size: 18),
                  label: Text(
                    _isExporting ? 'Preparing Backup...' : 'Export Backup (JSON)',
                  ),
                  onPressed: _isExporting ? null : _exportAllJson,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Sign Out / Switch Account
          OutlinedButton.icon(
            icon: Icon(
              authState.isGuest ? Icons.login_rounded : Icons.logout_rounded,
              size: 18,
              color: authState.isGuest ? null : crimson,
            ),
            label: Text(
              authState.isGuest ? 'Sign In or Create Account' : 'Sign Out',
              style: TextStyle(
                color: authState.isGuest ? null : crimson,
              ),
            ),
            onPressed: () => _confirmSignOut(authState.isGuest),
          ),
          const SizedBox(height: 18),
          Center(
            child: Column(
              children: [
                const VarantiWordmark(height: 16),
                const SizedBox(height: 6),
                Text(
                  '100% Free | Unlimited | No Paywalls',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOptionPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOptionPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = AppTheme.mutedTextOf(context);
    final hairline = AppTheme.hairlineOf(context);

    return Material(
      color: selected ? surface : Colors.transparent,
      shape: StadiumBorder(
        side: selected ? BorderSide(color: hairline) : BorderSide.none,
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: selected ? onSurface : muted),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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
