import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/config/app_config.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_messages.dart';
import '../../data/models/warranty_model.dart';
import '../notifications/notification_service.dart';
import '../notifications/notification_settings_sheet.dart';
import '../ocr/ocr_review_dialog.dart';
import '../warranties/warranty_detail_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _searchController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  String? _lastSyncedSignature;

  void _showNotificationSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const NotificationSettingsSheet(),
    );
  }

  void _syncNotificationsIfUnfiltered(
    List<WarrantyModel> warranties,
    WarrantyFilterState filter,
    NotificationSettings notifSettings,
  ) {
    final isUnfiltered =
        (filter.query == null || filter.query!.isEmpty) && filter.selectedCategory == null;
    if (!isUnfiltered) return;

    final sig =
        '${notifSettings.enabled}:${notifSettings.activeLeadDays.join(',')}:${notifSettings.reminderHour}:${notifSettings.reminderMinute}|'
        '${warranties.map((w) => '${w.id}@${w.warrantyExpirationDate.toIso8601String()}').join(';')}';
    if (sig == _lastSyncedSignature) return;
    _lastSyncedSignature = sig;

    NotificationService.instance.syncAllWarranties(warranties, notifSettings);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleCapture(ImageSource source) async {
    try {
      final XFile? receiptImage = await _picker.pickImage(
        source: source,
        imageQuality: AppConfig.imageQuality,
        maxWidth: AppConfig.maxImageDimension,
        maxHeight: AppConfig.maxImageDimension,
      );

      if (receiptImage == null) return;

      // Ask if user wants to attach a serial number photo
      String? serialPath;
      if (mounted) {
        final addSerial = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Add Serial Label Photo?'),
            content: const Text(
              'Do you want to snap or import an additional photo of the product barcode or serial number label?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Skip')),
              ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Add Photo')),
            ],
          ),
        );

        if (addSerial == true && mounted) {
          final XFile? serialImage = await _picker.pickImage(
            source: source,
            imageQuality: AppConfig.imageQuality,
            maxWidth: AppConfig.maxImageDimension,
            maxHeight: AppConfig.maxImageDimension,
          );
          serialPath = serialImage?.path;
        }
      }

      final authState = ref.read(authProvider);
      Map<String, dynamic>? ocrData;

      // If authenticated, run the AI OCR pipeline via FastAPI backend
      if (authState.isAuthenticated && mounted) {
        // Show loading progress overlay
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Analyzing receipt with Gemini AI...', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        );

        try {
          final apiClient = ref.read(apiClientProvider);
          ocrData = await apiClient!.scanReceipt(
            receiptPath: receiptImage.path,
            serialPath: serialPath,
          );
        } catch (e) {
          debugPrint('OCR Scan encountered error, falling back to manual form: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  ErrorMessages.friendly(
                    e,
                    fallback: "Couldn't read that receipt automatically. Please enter details manually.",
                  ),
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } finally {
          if (mounted) Navigator.of(context, rootNavigator: true).pop(); // dismiss loader
        }
      }

      // Open review & confirmation modal dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => OcrReviewDialog(
            receiptFilePath: receiptImage.path,
            serialFilePath: serialPath,
            initialOcrData: ocrData,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ErrorMessages.friendly(e, fallback: "Couldn't open that photo. Please try again."),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Receipt & Warranty',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.primary),
                title: const Text('Take Photo with Camera'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _handleCapture(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppTheme.primary),
                title: const Text('Choose from Photo Gallery'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _handleCapture(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final filter = ref.watch(warrantyFilterProvider);
    final notifSettings = ref.watch(notificationSettingsProvider);
    final warrantiesAsync = ref.watch(warrantiesStreamProvider);

    ref.listen<AsyncValue<List<WarrantyModel>>>(warrantiesStreamProvider, (_, next) {
      next.whenData((list) => _syncNotificationsIfUnfiltered(list, filter, notifSettings));
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.receipt_long_rounded, color: AppTheme.primary),
            const SizedBox(width: 8),
            const Text('Varanti'),
            const SizedBox(width: 10),
            // Mode Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: authState.isGuest
                    ? Colors.amber.shade100
                    : Colors.blue.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                authState.isGuest ? 'Guest (Offline)' : 'Cloud Synced',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: authState.isGuest ? Colors.amber.shade900 : Colors.blue.shade900,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              notifSettings.enabled
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
            ),
            tooltip: 'Expiry Alert Settings',
            onPressed: _showNotificationSettings,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: authState.isGuest ? 'Sign In / Register' : 'Sign Out',
            onPressed: () {
              ref.read(authProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Migration progress indicator
          if (authState.isMigrating)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.blue.shade50,
              child: const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Migrating offline receipts to your cloud account...',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                  ),
                ],
              ),
            ),

          // Guest Mode Sync Banner
          if (authState.isGuest)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 22, color: Color(0xFFD97706)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Offline Guest Mode',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                        ),
                        Text(
                          'Receipts saved on device. Sign in to enable AI scan & cloud sync.',
                          style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () {
                      ref.read(authProvider.notifier).signOut();
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Sign In', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search items, stores, or serial numbers...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: (filter.query != null && filter.query!.isNotEmpty) ||
                        _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(warrantyFilterProvider.notifier).updateQuery('');
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                ref.read(warrantyFilterProvider.notifier).updateQuery(val);
              },
            ),
          ),

          // Horizontal Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _filterChip(
                  label: 'All Items',
                  isSelected: filter.selectedCategory == null,
                  onSelected: () {
                    ref.read(warrantyFilterProvider.notifier).updateCategory(null);
                  },
                ),
                ...AppConfig.categories.map((cat) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _filterChip(
                      label: cat,
                      isSelected: filter.selectedCategory == cat,
                      onSelected: () {
                        ref.read(warrantyFilterProvider.notifier).updateCategory(cat);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Summary Metrics Banner & List Content
          Expanded(
            child: warrantiesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                      const SizedBox(height: 12),
                      Text(
                        ErrorMessages.friendly(
                          err,
                          fallback: "Couldn't load your warranties right now.",
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(warrantiesStreamProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (warranties) {
                if (warranties.isEmpty) {
                  return _emptyState();
                }

                // Calculate metrics
                final activeCount = warranties.where((w) => w.status == 'active').length;
                final expiringCount = warranties.where((w) => w.status == 'expiring_soon').length;
                final expiredCount = warranties.where((w) => w.status == 'expired').length;

                return Column(
                  children: [
                    // Metrics Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: _metricCard('Active', activeCount, AppTheme.statusActive),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _metricCard('Expiring Soon', expiringCount, AppTheme.statusExpiringSoon),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _metricCard('Expired', expiredCount, AppTheme.statusExpired),
                          ),
                        ],
                      ),
                    ),

                    // Warranties Card List
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(warrantiesStreamProvider);
                          await ref.read(warrantiesStreamProvider.future);
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: warranties.length,
                          itemBuilder: (ctx, index) {
                            final item = warranties[index];
                            return _warrantyCard(item);
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.camera_alt_rounded),
        label: const Text('Scan Receipt'),
        onPressed: _showImageSourcePicker,
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: AppTheme.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? AppTheme.primary : const Color(0xFF475569),
        fontSize: 13,
      ),
    );
  }

  Widget _metricCard(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),

      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _warrantyCard(WarrantyModel item) {
    final statusColor = AppTheme.getStatusColor(item.status);
    final statusLabel = AppTheme.getStatusLabel(item.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.itemName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        if (item.merchantName != null && item.merchantName!.isNotEmpty)
                          Text(
                            item.merchantName!,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                      ],
                    ),
                  ),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Text(
                    'Expires: ${item.formattedExpirationDate}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const Spacer(),
                  Text(
                    item.daysRemaining > 0
                        ? '${item.daysRemaining}d left'
                        : item.daysRemaining == 0
                            ? 'Today'
                            : '${item.daysRemaining.abs()}d ago',
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
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_rounded, size: 64, color: AppTheme.primary),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Warranties Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the button below to snap your first receipt photo. We will automatically track its warranty for you.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Scan First Receipt'),
              onPressed: _showImageSourcePicker,
            ),
          ],
        ),
      ),
    );
  }
}
