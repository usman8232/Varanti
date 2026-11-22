import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_messages.dart';
import '../../data/models/warranty_model.dart';
import '../dossier/pdf_dossier_service.dart';
import '../notifications/notification_service.dart';
import 'edit_warranty_dialog.dart';
import 'widgets/warranty_card.dart';

class WarrantyDetailScreen extends ConsumerStatefulWidget {
  final WarrantyModel warranty;

  const WarrantyDetailScreen({super.key, required this.warranty});

  @override
  ConsumerState<WarrantyDetailScreen> createState() =>
      _WarrantyDetailScreenState();
}

class _WarrantyDetailScreenState extends ConsumerState<WarrantyDetailScreen> {
  late WarrantyModel _warranty;
  bool _isExportingPdf = false;

  @override
  void initState() {
    super.initState();
    _warranty = widget.warranty;
  }

  Future<void> _edit() async {
    final updated = await showDialog<WarrantyModel>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditWarrantyDialog(warranty: _warranty),
    );
    if (updated != null && mounted) {
      setState(() => _warranty = updated);
    }
  }

  Future<void> _exportPdf(String? userEmail) async {
    if (_isExportingPdf) return;
    setState(() => _isExportingPdf = true);
    try {
      await PdfDossierService.generateAndShareDossier(
        warranty: _warranty,
        userEmail: userEmail,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ErrorMessages.friendly(
                e,
                fallback: "Couldn't create the PDF right now. Please try again.",
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  Future<void> _delete() async {
    final crimson = AppTheme.crimsonOf(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Warranty?'),
        content: const Text(
          'This permanently deletes this warranty and removes its saved receipt photos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: crimson),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final repo = ref.read(warrantyRepositoryProvider);
        await repo.deleteWarranty(_warranty.id);
        await NotificationService.instance.cancelForWarranty(_warranty.id);
        ref.invalidate(warrantiesStreamProvider);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Warranty deleted.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ErrorMessages.friendly(
                  e,
                  fallback: "Couldn't delete this warranty. Please try again.",
                ),
              ),
            ),
          );
        }
      }
    }
  }

  void _openFullScreenPhoto(String title, String imageUrlOrPath) {
    final isRemote = imageUrlOrPath.startsWith('http://') ||
        imageUrlOrPath.startsWith('https://');
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(title, style: const TextStyle(color: Colors.white)),
            leading: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5.0,
              child: isRemote
                  ? Image.network(
                      imageUrlOrPath,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white54,
                        size: 48,
                      ),
                    )
                  : Image.file(
                      File(imageUrlOrPath),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white54,
                        size: 48,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  double _remainingFraction(WarrantyModel w) {
    final purchase = DateTime(
      w.purchaseDate.year,
      w.purchaseDate.month,
      w.purchaseDate.day,
    );
    final exp = DateTime(
      w.warrantyExpirationDate.year,
      w.warrantyExpirationDate.month,
      w.warrantyExpirationDate.day,
    );
    final totalDays = exp.difference(purchase).inDays;
    if (totalDays <= 0) return w.daysRemaining > 0 ? 1.0 : 0.0;
    return (w.daysRemaining / totalDays).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final warranty = _warranty;
    final statusColor = AppTheme.getStatusColor(warranty.status);
    final hairline = AppTheme.hairlineOf(context);
    final subtle = AppTheme.subtleSurfaceOf(context);
    final muted = AppTheme.mutedTextOf(context);
    final crimson = AppTheme.crimsonOf(context);

    final remainingFraction = _remainingFraction(warranty);
    final remainingPct = (remainingFraction * 100).round();

    final countdownLabel = warranty.daysRemaining > 0
        ? '${warranty.daysRemaining} days remaining'
        : warranty.daysRemaining == 0
            ? 'Expired today'
            : 'Expired ${warranty.daysRemaining.abs()} days ago';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          warranty.itemName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Warranty',
            onPressed: _edit,
          ),
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Export Claim PDF',
            onPressed: _isExportingPdf
                ? null
                : () => _exportPdf(authState.user?.email),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: crimson),
            tooltip: 'Delete Warranty',
            onPressed: _delete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Visual Graph 3: Warranty Lifespan Progress Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      WarrantyStatusPill(status: warranty.status),
                      const Spacer(),
                      Text(
                        '$remainingPct% left',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    countdownLabel,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Lifespan Progress Track
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: 9,
                      child: Stack(
                        children: [
                          Container(color: subtle),
                          FractionallySizedBox(
                            widthFactor: remainingFraction == 0
                                ? 0.0
                                : remainingFraction.clamp(0.04, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: statusColor,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'Bought ${warranty.formattedPurchaseDate}',
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                      const Spacer(),
                      Text(
                        'Ends ${warranty.formattedExpirationDate}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Metadata Specification Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SPECIFICATIONS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: muted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _detailRow(context, Icons.devices_rounded, 'Product', warranty.itemName),
                  Divider(height: 22, color: hairline),
                  _detailRow(
                    context,
                    Icons.storefront_rounded,
                    'Store',
                    warranty.merchantName ?? 'Not specified',
                  ),
                  Divider(height: 22, color: hairline),
                  _detailRow(context, Icons.category_outlined, 'Category', warranty.category),
                  Divider(height: 22, color: hairline),
                  _detailRow(
                    context,
                    Icons.calendar_today_rounded,
                    'Purchase Date',
                    warranty.formattedPurchaseDate,
                  ),
                  Divider(height: 22, color: hairline),
                  _detailRow(
                    context,
                    Icons.event_available_rounded,
                    'Expiration Date',
                    warranty.formattedExpirationDate,
                  ),
                  Divider(height: 22, color: hairline),
                  _detailRow(
                    context,
                    Icons.timer_outlined,
                    'Duration',
                    '${warranty.warrantyDurationMonths} Months',
                  ),
                  if (warranty.serialNumber != null &&
                      warranty.serialNumber!.isNotEmpty) ...[
                    Divider(height: 22, color: hairline),
                    _detailRow(
                      context,
                      Icons.tag_rounded,
                      'Serial Number',
                      warranty.serialNumber!,
                    ),
                  ],
                  if (warranty.pricePaid != null) ...[
                    Divider(height: 22, color: hairline),
                    _detailRow(
                      context,
                      Icons.payments_outlined,
                      'Price Paid',
                      warranty.formattedPrice,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (warranty.notes != null && warranty.notes!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NOTES & TAGS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        color: muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      warranty.notes!,
                      style: const TextStyle(fontSize: 14, height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Proof of Purchase Photos
            Row(
              children: [
                Text(
                  'PROOF OF PURCHASE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: muted,
                  ),
                ),
                const Spacer(),
                Text(
                  'Tap to zoom',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _imagePreviewBox(
                    context: context,
                    title: 'Receipt Photo',
                    imageUrlOrPath: warranty.receiptImageUrl,
                  ),
                ),
                if (warranty.serialImageUrl != null &&
                    warranty.serialImageUrl!.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: _imagePreviewBox(
                      context: context,
                      title: 'Serial Label',
                      imageUrlOrPath: warranty.serialImageUrl!,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),

            // Primary Crimson Pill CTA: Export Official Claim PDF (SRS FR-EXP-01..03)
            FilledButton.icon(
              icon: _isExportingPdf
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded, size: 19),
              label: Text(
                _isExportingPdf
                    ? 'Preparing Claim PDF...'
                    : 'Export Official Claim PDF',
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _isExportingPdf
                  ? null
                  : () => _exportPdf(authState.user?.email),
            ),
            const SizedBox(height: 8),
            Text(
              'Clean A4 PDF with receipt proof and zero watermarks.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final muted = AppTheme.mutedTextOf(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: muted),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: muted, fontSize: 13)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _imagePreviewBox({
    required BuildContext context,
    required String title,
    required String imageUrlOrPath,
  }) {
    final hairline = AppTheme.hairlineOf(context);
    final subtle = AppTheme.subtleSurfaceOf(context);
    final muted = AppTheme.mutedTextOf(context);

    final isRemote = imageUrlOrPath.startsWith('http://') ||
        imageUrlOrPath.startsWith('https://');

    final Widget imageWidget = isRemote
        ? Image.network(
            imageUrlOrPath,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Center(
              child: Icon(Icons.broken_image_outlined, color: muted),
            ),
          )
        : Image.file(
            File(imageUrlOrPath),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Center(
              child: Icon(Icons.broken_image_outlined, color: muted),
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 12, color: muted)),
        const SizedBox(height: 6),
        Material(
          color: subtle,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: hairline),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openFullScreenPhoto(title, imageUrlOrPath),
            child: SizedBox(
              height: 168,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageWidget,
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.zoom_in_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
