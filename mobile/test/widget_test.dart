import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:varanti_mobile/core/providers/app_providers.dart';
import 'package:varanti_mobile/core/utils/error_messages.dart';
import 'package:varanti_mobile/data/models/warranty_model.dart';
import 'package:varanti_mobile/features/dossier/pdf_dossier_service.dart';
import 'package:varanti_mobile/features/notifications/notification_service.dart';

void main() {
  group('WarrantyModel Tests', () {
    test('Calculates active status when > 30 days remaining', () {
      final futureDate = DateTime.now().add(const Duration(days: 45));
      final warranty = WarrantyModel(
        id: 'w1',
        itemName: 'Headphones',
        purchaseDate: DateTime.now().subtract(const Duration(days: 30)),
        warrantyExpirationDate: futureDate,
        receiptImageUrl: 'dummy.jpg',
      );

      expect(warranty.daysRemaining, greaterThan(30));
      expect(warranty.status, 'active');
    });

    test('Calculates expiring_soon status when 1-30 days remaining', () {
      final futureDate = DateTime.now().add(const Duration(days: 15));
      final warranty = WarrantyModel(
        id: 'w2',
        itemName: 'Coffee Maker',
        purchaseDate: DateTime.now().subtract(const Duration(days: 350)),
        warrantyExpirationDate: futureDate,
        receiptImageUrl: 'dummy.jpg',
      );

      expect(warranty.daysRemaining, inInclusiveRange(1, 30));
      expect(warranty.status, 'expiring_soon');
    });

    test('Calculates expired status when <= 0 days remaining', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 5));
      final warranty = WarrantyModel(
        id: 'w3',
        itemName: 'Toaster',
        purchaseDate: DateTime.now().subtract(const Duration(days: 400)),
        warrantyExpirationDate: pastDate,
        receiptImageUrl: 'dummy.jpg',
      );

      expect(warranty.daysRemaining, lessThanOrEqualTo(0));
      expect(warranty.status, 'expired');
    });

    test('Calculates boundary day 0 as expired and day 31 as active', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final day0 = WarrantyModel(
        id: 'w4',
        itemName: 'Router',
        purchaseDate: today.subtract(const Duration(days: 365)),
        warrantyExpirationDate: today,
        receiptImageUrl: 'dummy.jpg',
      );
      final day31 = WarrantyModel(
        id: 'w5',
        itemName: 'Monitor',
        purchaseDate: today.subtract(const Duration(days: 334)),
        warrantyExpirationDate: today.add(const Duration(days: 31)),
        receiptImageUrl: 'dummy.jpg',
      );

      expect(day0.daysRemaining, 0);
      expect(day0.status, 'expired');
      expect(day31.daysRemaining, 31);
      expect(day31.status, 'active');
    });
  });

  group('WarrantyFilterNotifier Tests', () {
    test('Can select a category and clear back to All Items (null)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(warrantyFilterProvider.notifier);
      expect(container.read(warrantyFilterProvider).selectedCategory, isNull);

      notifier.updateCategory('Audio');
      expect(container.read(warrantyFilterProvider).selectedCategory, 'Audio');

      notifier.updateCategory(null);
      expect(container.read(warrantyFilterProvider).selectedCategory, isNull);
    });

    test('Can set and clear search query', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(warrantyFilterProvider.notifier);
      notifier.updateQuery('Sony');
      expect(container.read(warrantyFilterProvider).query, 'Sony');

      notifier.updateQuery('');
      expect(container.read(warrantyFilterProvider).query, isNull);
    });

    test('Can filter by status, update sort order, and clear all filters', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(warrantyFilterProvider.notifier);
      notifier.updateStatus('expiring_soon');
      notifier.updateCategory('Computing');
      notifier.updateSortOrder(WarrantySortOrder.highestValue);

      final active = container.read(warrantyFilterProvider);
      expect(active.selectedStatus, 'expiring_soon');
      expect(active.selectedCategory, 'Computing');
      expect(active.sortOrder, WarrantySortOrder.highestValue);

      notifier.clearAll();
      final cleared = container.read(warrantyFilterProvider);
      expect(cleared.selectedStatus, isNull);
      expect(cleared.selectedCategory, isNull);
      expect(cleared.query, isNull);
      expect(cleared.sortOrder, WarrantySortOrder.expiringSoonest);
    });
  });

  group('PdfDossierService Tests', () {
    test('Sanitizes special characters in exported PDF filename', () {
      expect(
        PdfDossierService.sanitizeFilename('MacBook Pro 14" / M4: Max'),
        'warranty-dossier-macbook-pro-14-m4-max.pdf',
      );
      expect(
        PdfDossierService.sanitizeFilename('   '),
        'warranty-dossier-item.pdf',
      );
    });

    test('Builds valid unwatermarked PDF bytes for single dossier and full portfolio', () async {
      final sample = WarrantyModel(
        id: 'w-pdf-1',
        itemName: 'MacBook Air M4',
        merchantName: 'Apple Store',
        category: 'Computing',
        purchaseDate: DateTime(2026, 2, 1),
        warrantyDurationMonths: 12,
        warrantyExpirationDate: DateTime(2027, 2, 1),
        serialNumber: 'C02TEST123',
        pricePaid: 1299.00,
        currency: 'USD',
        receiptImageUrl: '',
      );

      final singleBytes = await PdfDossierService.buildDossierPdfBytes(
        warranty: sample,
        userName: 'Usman Waseem',
        userEmail: 'usman@example.com',
      );
      expect(singleBytes.length, greaterThan(500));
      expect(String.fromCharCodes(singleBytes.take(5)), '%PDF-');

      final portfolioBytes = await PdfDossierService.buildPortfolioPdfBytes(
        warranties: [sample],
        userName: 'Usman Waseem',
        userEmail: 'usman@example.com',
      );
      expect(portfolioBytes.length, greaterThan(500));
      expect(String.fromCharCodes(portfolioBytes.take(5)), '%PDF-');
    });
  });

  group('Warranty Update & Notification Tests', () {
    test('toUpdateJson excludes immutable receipt/serial storage fields', () {
      final warranty = WarrantyModel(
        id: 'w-edit-1',
        itemName: 'Sony WH-1000XM5',
        merchantName: 'Best Buy',
        category: 'Audio',
        purchaseDate: DateTime(2026, 1, 15),
        warrantyDurationMonths: 24,
        warrantyExpirationDate: DateTime(2028, 1, 15),
        serialNumber: 'SN-999',
        pricePaid: 349.99,
        currency: 'USD',
        receiptImageUrl: 'https://example.com/receipt.jpg',
        receiptImagePath: 'user/receipts/abc.jpg',
        notes: 'Extended coverage',
      );

      final patch = warranty.toUpdateJson();
      expect(patch['item_name'], 'Sony WH-1000XM5');
      expect(patch['warranty_duration_months'], 24);
      expect(patch['warranty_expiration_date'], '2028-01-15');
      expect(patch.containsKey('receipt_image_url'), isFalse);
      expect(patch.containsKey('receipt_image_path'), isFalse);
    });

    test('Schedules 30d, 7d, and 24h reminders only when in the future', () {
      final now = DateTime(2026, 6, 1, 10, 0);
      final warranty = WarrantyModel(
        id: 'w-notif-1',
        itemName: 'Espresso Machine',
        merchantName: 'Target',
        purchaseDate: DateTime(2025, 6, 20),
        warrantyExpirationDate: DateTime(2026, 6, 20),
        receiptImageUrl: 'dummy.jpg',
      );

      final reminders = NotificationService.computeReminderSchedule(
        warranty,
        const NotificationSettings(),
        now: now,
      );

      // 30d before June 20 is May 21 (past), so only 7d (June 13) and 1d (June 19) are scheduled.
      expect(reminders.map((r) => r.leadDays).toList(), [7, 1]);
      expect(reminders.first.scheduledAt, DateTime(2026, 6, 13, 9, 0));
      expect(reminders.last.scheduledAt, DateTime(2026, 6, 19, 9, 0));
      expect(reminders.last.title, contains('tomorrow'));
    });

    test('Respects disabled master toggle and per-lead-day settings', () {
      final now = DateTime(2026, 1, 1, 8, 0);
      final warranty = WarrantyModel(
        id: 'w-notif-2',
        itemName: 'Laptop',
        purchaseDate: DateTime(2025, 6, 1),
        warrantyExpirationDate: DateTime(2026, 6, 1),
        receiptImageUrl: 'dummy.jpg',
      );

      final disabled = NotificationService.computeReminderSchedule(
        warranty,
        const NotificationSettings(enabled: false),
        now: now,
      );
      expect(disabled, isEmpty);

      final only7d = NotificationService.computeReminderSchedule(
        warranty,
        const NotificationSettings(
          alert30Days: false,
          alert7Days: true,
          alert1Day: false,
          reminderHour: 18,
          reminderMinute: 30,
        ),
        now: now,
      );
      expect(only7d.length, 1);
      expect(only7d.first.leadDays, 7);
      expect(only7d.first.scheduledAt, DateTime(2026, 5, 25, 18, 30));
    });

    test('Generates deterministic distinct notification IDs per warranty & lead day', () {
      final id30 = NotificationService.notificationIdFor('uuid-1', 30);
      final id7 = NotificationService.notificationIdFor('uuid-1', 7);
      final id1 = NotificationService.notificationIdFor('uuid-1', 1);
      final other30 = NotificationService.notificationIdFor('uuid-2', 30);

      expect({id30, id7, id1, other30}.length, 4);
      expect(id30, NotificationService.notificationIdFor('uuid-1', 30));
      expect(id30, greaterThan(0));
    });

    test('Resolves local timezone matching device UTC offset', () {
      tzdata.initializeTimeZones();
      final locPlus5 = NotificationService.resolveLocationForOffset(const Duration(hours: 5));
      expect(locPlus5.currentTimeZone.offset, const Duration(hours: 5));
    });
  });

  group('ErrorMessages Tests', () {
    test('Maps API status codes to short plain English with no status numbers', () {
      for (final code in [400, 401, 403, 404, 413, 415, 422, 429, 500, 502, 503]) {
        final msg = ErrorMessages.friendly(ApiException.fromStatus(code));
        expect(msg, isNotEmpty);
        expect(RegExp(r'\d{3}').hasMatch(msg), isFalse, reason: 'Status $code leaked into "$msg"');
        expect(msg.toLowerCase(), isNot(contains('exception')));
      }
    });

    test('Maps network, timeout, and auth exceptions to friendly English', () {
      final offline = ErrorMessages.friendly(
        const SocketException('Connection refused (errno = 111)'),
      );
      expect(offline, contains("Can't reach the server"));
      expect(offline, isNot(contains('111')));

      final timedOut = ErrorMessages.friendly(TimeoutException('Future not completed'));
      expect(timedOut, contains('timed out'));

      final badLogin = ErrorMessages.friendly(
        const AuthException('Invalid login credentials', statusCode: '400'),
      );
      expect(badLogin, 'Incorrect email or password.');

      final unverified = ErrorMessages.friendly(
        const AuthException('Email not confirmed', statusCode: '400'),
      );
      expect(unverified, contains('verify your email'));

      final unknown = ErrorMessages.friendly(
        Exception('SQLITE_CONSTRAINT error code 19'),
        fallback: "Couldn't save this item.",
      );
      expect(unknown, isNot(contains('19')));
      expect(unknown, isNot(contains('SQLITE')));
    });
  });
}
