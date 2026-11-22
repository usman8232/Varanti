import 'dart:io';
import 'package:flutter/foundation.dart';
import '../local/app_database.dart';
import '../models/warranty_model.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/error_messages.dart';

class WarrantyRepository {
  final bool isGuest;
  final ApiClient? apiClient;

  WarrantyRepository({
    required this.isGuest,
    this.apiClient,
  });

  static bool _isRemoteUrl(String? value) {
    if (value == null || value.isEmpty) return false;
    return value.startsWith('http://') || value.startsWith('https://');
  }

  static Future<void> _deleteManagedLocalFile(String? path) async {
    if (path == null || path.isEmpty || _isRemoteUrl(path)) return;
    // Only delete copies stored inside Varanti's managed local receipts folder
    // so we never remove original photos in the user's shared gallery.
    if (!path.contains('varanti_receipts')) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Failed to delete local receipt file $path: $e');
    }
  }

  Future<List<WarrantyModel>> getWarranties({String? query, String? category}) async {
    if (isGuest) {
      return await AppDatabase.instance.getWarranties(query: query, category: category);
    } else {
      if (apiClient == null) throw const ApiException('Please sign in to view your warranties.');
      return await apiClient!.getWarranties(query: query, category: category);
    }
  }

  Future<WarrantyModel?> getWarrantyById(String id) async {
    if (isGuest) {
      return await AppDatabase.instance.getWarrantyById(id);
    } else {
      final all = await getWarranties();
      try {
        return all.firstWhere((w) => w.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  Future<WarrantyModel> saveWarranty(WarrantyModel warranty) async {
    if (isGuest) {
      final localWarranty = warranty.copyWith(isLocalOnly: true);
      await AppDatabase.instance.insertWarranty(localWarranty);
      return localWarranty;
    } else {
      if (apiClient == null) throw const ApiException('Please sign in to save warranties to the cloud.');
      var toCreate = warranty;
      if (!_isRemoteUrl(warranty.receiptImageUrl) &&
          warranty.receiptImageUrl.isNotEmpty &&
          await File(warranty.receiptImageUrl).exists()) {
        final localSerial = !_isRemoteUrl(warranty.serialImageUrl) &&
                warranty.serialImageUrl != null &&
                await File(warranty.serialImageUrl!).exists()
            ? warranty.serialImageUrl
            : null;
        final uploaded = await apiClient!.uploadImages(
          receiptPath: warranty.receiptImageUrl,
          serialPath: localSerial,
        );
        toCreate = warranty.copyWith(
          receiptImageUrl: (uploaded['receipt_url'] ?? uploaded['receipt_image_url'])?.toString() ??
              warranty.receiptImageUrl,
          receiptImagePath: uploaded['receipt_path']?.toString(),
          serialImageUrl: (uploaded['serial_url'] ?? uploaded['serial_image_url'])?.toString() ??
              warranty.serialImageUrl,
          serialImagePath: uploaded['serial_path']?.toString(),
        );
      }
      return await apiClient!.createWarranty(toCreate);
    }
  }

  Future<WarrantyModel> updateWarranty(WarrantyModel warranty) async {
    if (isGuest) {
      final updated = warranty.copyWith(updatedAt: DateTime.now());
      await AppDatabase.instance.updateWarranty(updated);
      return updated;
    } else {
      if (apiClient == null) throw const ApiException('Please sign in to update warranties.');
      return await apiClient!.updateWarranty(warranty.id, warranty.toUpdateJson());
    }
  }

  Future<void> deleteWarranty(String id) async {
    if (isGuest) {
      final existing = await AppDatabase.instance.getWarrantyById(id);
      await AppDatabase.instance.deleteWarranty(id);
      if (existing != null) {
        await _deleteManagedLocalFile(existing.receiptImageUrl);
        await _deleteManagedLocalFile(existing.serialImageUrl);
      }
    } else {
      if (apiClient == null) throw const ApiException('Please sign in to delete warranties.');
      await apiClient!.deleteWarranty(id);
    }
  }

  /// Migrates all guest on-device SQLite warranties to cloud upon registration/login
  Future<int> migrateGuestWarrantiesToCloud() async {
    if (apiClient == null) return 0;
    final localItems = await AppDatabase.instance.getWarranties();
    int migratedCount = 0;

    for (final item in localItems) {
      try {
        var cloudItem = item;
        if (!_isRemoteUrl(item.receiptImageUrl) &&
            item.receiptImageUrl.isNotEmpty &&
            await File(item.receiptImageUrl).exists()) {
          final localSerial = !_isRemoteUrl(item.serialImageUrl) &&
                  item.serialImageUrl != null &&
                  await File(item.serialImageUrl!).exists()
              ? item.serialImageUrl
              : null;
          final uploaded = await apiClient!.uploadImages(
            receiptPath: item.receiptImageUrl,
            serialPath: localSerial,
          );
          cloudItem = item.copyWith(
            receiptImageUrl: (uploaded['receipt_url'] ?? uploaded['receipt_image_url'])?.toString() ??
                item.receiptImageUrl,
            receiptImagePath: uploaded['receipt_path']?.toString(),
            serialImageUrl: (uploaded['serial_url'] ?? uploaded['serial_image_url'])?.toString() ??
                item.serialImageUrl,
            serialImagePath: uploaded['serial_path']?.toString(),
          );
        }
        await apiClient!.createWarranty(cloudItem);
        await AppDatabase.instance.deleteWarranty(item.id);
        await _deleteManagedLocalFile(item.receiptImageUrl);
        await _deleteManagedLocalFile(item.serialImageUrl);
        migratedCount++;
      } catch (e) {
        debugPrint('Failed to migrate guest warranty ${item.id}: $e');
      }
    }
    return migratedCount;
  }
}
