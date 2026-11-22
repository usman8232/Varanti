import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/config/app_config.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_messages.dart';
import '../ocr/ocr_review_dialog.dart';

/// Shared Quick-Scan flow invoked from the bottom navigation Crimson Scan button
/// and empty-state CTAs (keeps the happy path <= 3 taps per SRS 5.4).
class ScanFlowHelper {
  static final ImagePicker _picker = ImagePicker();

  static void showSourcePicker(BuildContext context, WidgetRef ref) {
    final hairline = AppTheme.hairlineOf(context);
    final subtle = AppTheme.subtleSurfaceOf(context);
    final crimson = AppTheme.crimsonOf(context);

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: hairline,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Add Receipt & Warranty',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Take a photo or choose a receipt from your gallery.',
                style: TextStyle(fontSize: 13, color: AppTheme.mutedTextOf(ctx)),
              ),
              const SizedBox(height: 18),
              _SourceOptionTile(
                icon: Icons.photo_camera_outlined,
                iconBg: crimson.withValues(alpha: 0.12),
                iconColor: crimson,
                title: 'Take Photo with Camera',
                subtitle: 'Snap a fresh receipt directly',
                onTap: () {
                  Navigator.of(ctx).pop();
                  captureAndReview(context, ref, ImageSource.camera);
                },
              ),
              const SizedBox(height: 10),
              _SourceOptionTile(
                icon: Icons.photo_library_outlined,
                iconBg: subtle,
                iconColor: Theme.of(ctx).colorScheme.onSurface,
                title: 'Choose from Gallery',
                subtitle: 'Import JPG, PNG, or HEIC receipt photo',
                onTap: () {
                  Navigator.of(ctx).pop();
                  captureAndReview(context, ref, ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> captureAndReview(
    BuildContext context,
    WidgetRef ref,
    ImageSource source,
  ) async {
    try {
      final XFile? receiptImage = await _picker.pickImage(
        source: source,
        imageQuality: AppConfig.imageQuality,
        maxWidth: AppConfig.maxImageDimension,
        maxHeight: AppConfig.maxImageDimension,
      );

      if (receiptImage == null || !context.mounted) return;

      // Optional secondary serial label photo (SRS FR-IMG-03)
      String? serialPath;
      final addSerial = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Add Serial Label Photo?'),
          content: const Text(
            'Do you also want to attach a photo of the product serial number or warranty card?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Skip'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_a_photo_outlined, size: 16),
              onPressed: () => Navigator.of(ctx).pop(true),
              label: const Text('Add Photo'),
            ),
          ],
        ),
      );

      if (addSerial == true && context.mounted) {
        final XFile? serialImage = await _picker.pickImage(
          source: source,
          imageQuality: AppConfig.imageQuality,
          maxWidth: AppConfig.maxImageDimension,
          maxHeight: AppConfig.maxImageDimension,
        );
        serialPath = serialImage?.path;
      }

      if (!context.mounted) return;

      final authState = ref.read(authProvider);
      final apiClient = ref.read(apiClientProvider);
      Map<String, dynamic>? ocrData;

      if (authState.isAuthenticated && apiClient != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => PopScope(
            canPop: false,
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.hairlineOf(context)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppTheme.crimsonOf(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Scanning your receipt...',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Reading dates, store name, and product details',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.mutedTextOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        try {
          ocrData = await apiClient.scanReceipt(
            receiptPath: receiptImage.path,
            serialPath: serialPath,
          );
        } catch (e) {
          debugPrint('OCR scan failed, routing to manual entry: $e');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  ErrorMessages.friendly(
                    e,
                    fallback:
                        "Couldn't read that receipt automatically. You can enter the details below.",
                  ),
                ),
              ),
            );
          }
        } finally {
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }
        }
      }

      if (context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => OcrReviewDialog(
            receiptFilePath: receiptImage.path,
            serialFilePath: serialPath,
            initialOcrData: ocrData,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ErrorMessages.friendly(
                e,
                fallback: "Couldn't open that photo. Please try again.",
              ),
            ),
          ),
        );
      }
    }
  }
}

class _SourceOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SourceOptionTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hairline = AppTheme.hairlineOf(context);
    final muted = AppTheme.mutedTextOf(context);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: hairline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}
