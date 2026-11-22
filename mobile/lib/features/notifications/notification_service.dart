import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../../data/models/warranty_model.dart';

class NotificationSettings {
  final bool enabled;
  final bool alert30Days;
  final bool alert7Days;
  final bool alert1Day;
  final int reminderHour;
  final int reminderMinute;

  const NotificationSettings({
    this.enabled = true,
    this.alert30Days = true,
    this.alert7Days = true,
    this.alert1Day = true,
    this.reminderHour = 9,
    this.reminderMinute = 0,
  });

  List<int> get activeLeadDays {
    if (!enabled) return const [];
    return [
      if (alert30Days) 30,
      if (alert7Days) 7,
      if (alert1Day) 1,
    ];
  }

  NotificationSettings copyWith({
    bool? enabled,
    bool? alert30Days,
    bool? alert7Days,
    bool? alert1Day,
    int? reminderHour,
    int? reminderMinute,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      alert30Days: alert30Days ?? this.alert30Days,
      alert7Days: alert7Days ?? this.alert7Days,
      alert1Day: alert1Day ?? this.alert1Day,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
    );
  }

  static const String _kEnabled = 'varanti_notif_enabled';
  static const String _k30Days = 'varanti_notif_30d';
  static const String _k7Days = 'varanti_notif_7d';
  static const String _k1Day = 'varanti_notif_1d';
  static const String _kHour = 'varanti_notif_hour';
  static const String _kMinute = 'varanti_notif_minute';

  static Future<NotificationSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return NotificationSettings(
        enabled: prefs.getBool(_kEnabled) ?? true,
        alert30Days: prefs.getBool(_k30Days) ?? true,
        alert7Days: prefs.getBool(_k7Days) ?? true,
        alert1Day: prefs.getBool(_k1Day) ?? true,
        reminderHour: (prefs.getInt(_kHour) ?? 9).clamp(0, 23),
        reminderMinute: (prefs.getInt(_kMinute) ?? 0).clamp(0, 59),
      );
    } catch (_) {
      return const NotificationSettings();
    }
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabled, enabled);
      await prefs.setBool(_k30Days, alert30Days);
      await prefs.setBool(_k7Days, alert7Days);
      await prefs.setBool(_k1Day, alert1Day);
      await prefs.setInt(_kHour, reminderHour);
      await prefs.setInt(_kMinute, reminderMinute);
    } catch (_) {}
  }
}

class ScheduledWarrantyReminder {
  final int notificationId;
  final int leadDays;
  final DateTime scheduledAt;
  final String title;
  final String body;
  final String warrantyId;

  const ScheduledWarrantyReminder({
    required this.notificationId,
    required this.leadDays,
    required this.scheduledAt,
    required this.title,
    required this.body,
    required this.warrantyId,
  });
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const List<int> allLeadDays = [30, 7, 1];
  static const String _channelId = 'varanti_warranty_expiry';
  static const String _channelName = 'Warranty Expiry Alerts';
  static const String _channelDesc =
      'Reminders 30 days, 7 days, and 24 hours before a product warranty expires.';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Deterministic positive 31-bit notification ID per (warrantyId, leadDays).
  static int notificationIdFor(String warrantyId, int leadDays) {
    final slot = allLeadDays.indexOf(leadDays);
    final slotIndex = slot >= 0 ? slot : 0;
    // FNV-1a 32-bit hash for cross-run stability (Dart String.hashCode is randomized per isolate).
    int hash = 0x811c9dc5;
    for (final unit in warrantyId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    final base = (hash % 700000000) * 3;
    return base + slotIndex + 1;
  }

  /// Pure computation of future reminders for a warranty (easy to unit test).
  static List<ScheduledWarrantyReminder> computeReminderSchedule(
    WarrantyModel warranty,
    NotificationSettings settings, {
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final reminders = <ScheduledWarrantyReminder>[];
    final expDate = DateTime(
      warranty.warrantyExpirationDate.year,
      warranty.warrantyExpirationDate.month,
      warranty.warrantyExpirationDate.day,
    );
    final expLabel = DateFormat.yMMMd().format(expDate);

    for (final leadDays in settings.activeLeadDays) {
      final targetDate = expDate.subtract(Duration(days: leadDays));
      final scheduledAt = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        settings.reminderHour,
        settings.reminderMinute,
      );
      if (!scheduledAt.isAfter(reference)) continue;

      final timeframe = leadDays == 1 ? '24 hours' : '$leadDays days';
      final title = leadDays == 1
          ? 'Warranty expires tomorrow: ${warranty.itemName}'
          : 'Warranty expiring in $timeframe: ${warranty.itemName}';
      final merchantPart = (warranty.merchantName != null && warranty.merchantName!.isNotEmpty)
          ? ' (${warranty.merchantName})'
          : '';
      final body =
          'Your warranty for ${warranty.itemName}$merchantPart expires on $expLabel. Open Varanti to review or export your claim PDF.';

      reminders.add(
        ScheduledWarrantyReminder(
          notificationId: notificationIdFor(warranty.id, leadDays),
          leadDays: leadDays,
          scheduledAt: scheduledAt,
          title: title,
          body: body,
          warrantyId: warranty.id,
        ),
      );
    }

    return reminders;
  }

  bool get _supportsScheduledNotifications {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Future<void> init() async {
    if (_initialized || !_supportsScheduledNotifications) return;

    try {
      tzdata.initializeTimeZones();
      _configureLocalTimezone();

      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );

      await _plugin.initialize(settings: settings);
      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService init skipped: $e');
    }
  }

  /// Resolves a timezone [tz.Location] matching [offset].
  /// Exposed for unit testing so local timezone resolution stays verified.
  static tz.Location resolveLocationForOffset(Duration offset) {
    final locations = tz.timeZoneDatabase.locations.values;
    for (final loc in locations) {
      if (loc.currentTimeZone.offset == offset) {
        return loc;
      }
    }
    return tz.UTC;
  }

  void _configureLocalTimezone() {
    try {
      final offset = DateTime.now().timeZoneOffset;
      tz.setLocalLocation(resolveLocationForOffset(offset));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  Future<bool> requestPermissions() async {
    if (!_supportsScheduledNotifications) return false;
    await init();
    if (!_initialized) return false;

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        return (await android?.requestNotificationsPermission()) ?? true;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = _plugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        return (await ios?.requestPermissions(alert: true, badge: true, sound: true)) ?? false;
      }
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        final mac = _plugin
            .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
        return (await mac?.requestPermissions(alert: true, badge: true, sound: true)) ?? false;
      }
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
    return false;
  }

  NotificationDetails get _notificationDetails => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

  Future<void> cancelAll() async {
    if (!_initialized || !_supportsScheduledNotifications) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Failed to cancel all notifications: $e');
    }
  }

  Future<void> cancelForWarranty(String warrantyId) async {
    if (!_initialized || !_supportsScheduledNotifications) return;
    for (final leadDays in allLeadDays) {
      try {
        await _plugin.cancel(id: notificationIdFor(warrantyId, leadDays));
      } catch (e) {
        debugPrint('Failed to cancel notification for $warrantyId ($leadDays d): $e');
      }
    }
  }

  Future<void> scheduleForWarranty(
    WarrantyModel warranty,
    NotificationSettings settings,
  ) async {
    if (!_supportsScheduledNotifications) return;
    await init();
    if (!_initialized) return;

    await cancelForWarranty(warranty.id);
    if (!settings.enabled) return;

    final reminders = computeReminderSchedule(warranty, settings);
    for (final reminder in reminders) {
      try {
        final tzDate = tz.TZDateTime.from(reminder.scheduledAt, tz.local);
        await _plugin.zonedSchedule(
          id: reminder.notificationId,
          title: reminder.title,
          body: reminder.body,
          scheduledDate: tzDate,
          notificationDetails: _notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: reminder.warrantyId,
        );
      } catch (e) {
        debugPrint('Failed to schedule notification ${reminder.notificationId}: $e');
      }
    }
  }

  Future<void> syncAllWarranties(
    List<WarrantyModel> warranties,
    NotificationSettings settings,
  ) async {
    if (!_supportsScheduledNotifications) return;
    await init();
    if (!_initialized) return;

    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Failed to clear pending notifications: $e');
    }

    if (!settings.enabled) return;

    for (final warranty in warranties) {
      final reminders = computeReminderSchedule(warranty, settings);
      for (final reminder in reminders) {
        try {
          final tzDate = tz.TZDateTime.from(reminder.scheduledAt, tz.local);
          await _plugin.zonedSchedule(
            id: reminder.notificationId,
            title: reminder.title,
            body: reminder.body,
            scheduledDate: tzDate,
            notificationDetails: _notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: reminder.warrantyId,
          );
        } catch (e) {
          debugPrint('Failed to schedule notification ${reminder.notificationId}: $e');
        }
      }
    }
  }
}
