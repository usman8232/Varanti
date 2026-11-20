import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import 'notification_service.dart';

class NotificationSettingsSheet extends ConsumerWidget {
  const NotificationSettingsSheet({super.key});

  String _formatTime(BuildContext context, int hour, int minute) {
    final tod = TimeOfDay(hour: hour, minute: minute);
    return tod.format(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active_outlined, color: AppTheme.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Expiry Alert Settings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 20),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Enable Expiry Reminders',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Get alerted before your warranties expire so you never miss a claim window.',
                style: TextStyle(fontSize: 12),
              ),
              value: settings.enabled,
              onChanged: (val) async {
                if (val) {
                  await NotificationService.instance.requestPermissions();
                }
                await notifier.updateSettings(settings.copyWith(enabled: val));
              },
            ),
            const SizedBox(height: 8),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('30 days before expiration'),
              subtitle: const Text('Early heads-up to check product condition'),
              value: settings.alert30Days,
              onChanged: settings.enabled
                  ? (val) => notifier.updateSettings(settings.copyWith(alert30Days: val))
                  : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('7 days before expiration'),
              subtitle: const Text('Final week to prepare any warranty claim'),
              value: settings.alert7Days,
              onChanged: settings.enabled
                  ? (val) => notifier.updateSettings(settings.copyWith(alert7Days: val))
                  : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('24 hours before expiration'),
              subtitle: const Text('Last-chance reminder before coverage ends'),
              value: settings.alert1Day,
              onChanged: settings.enabled
                  ? (val) => notifier.updateSettings(settings.copyWith(alert1Day: val))
                  : null,
            ),

            const Divider(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: settings.enabled,
              leading: const Icon(Icons.access_time_rounded),
              title: const Text('Daily Reminder Time'),
              trailing: Text(
                _formatTime(context, settings.reminderHour, settings.reminderMinute),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
              onTap: settings.enabled
                  ? () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: settings.reminderHour,
                          minute: settings.reminderMinute,
                        ),
                      );
                      if (picked != null) {
                        await notifier.updateSettings(
                          settings.copyWith(
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
    );
  }
}
