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

class WarrantyDetailScreen extends ConsumerStatefulWidget {
  final WarrantyModel warranty;

  const WarrantyDetailScreen({super.key, required this.warranty});

  @override
  ConsumerState<WarrantyDetailScreen> createState() => _WarrantyDetailScreenState();
}

class _WarrantyDetailScreenState extends ConsumerState<WarrantyDetailScreen> {
  late WarrantyModel _warranty;

  @override
  void initState() {
    super.initState();
    _warranty = widget.warranty;
  }

  Future<void> _edit() async {
    final updated = await showDialog<WarrantyModel>(
      context: context,
      builder: (_) => EditWarrantyDialog(warranty: _warranty),
    );
    if (updated != null && mounted) {
      setState(() => _warranty = updated);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Warranty?'),
        content: const Text(
          'This will permanently delete this warranty and remove any associated receipts from storage.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
            const SnackBar(content: Text('Warranty deleted')),
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
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final warranty = _warranty;
    final statusColor = AppTheme.getStatusColor(warranty.status);
    final statusLabel = AppTheme.getStatusLabel(warranty.status);

    return Scaffold(
      appBar: AppBar(
        title: Text(warranty.itemName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Warranty',
            onPressed: _edit,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Export Claim PDF',
            onPressed: () async {
              try {
                await PdfDossierService.generateAndShareDossier(
                  warranty: warranty,
                  userEmail: authState.user?.email,
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ErrorMessages.friendly(
                          e,
                          fallback: "Couldn't create the PDF right now. Please try again.",
                        ),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Delete',
            onPressed: _delete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Header Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),

              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.shield_rounded, color: statusColor, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          warranty.daysRemaining > 0
                              ? '${warranty.daysRemaining} days remaining'
                              : warranty.daysRemaining == 0
                                  ? 'Expires today'
                                  : 'Expired ${warranty.daysRemaining.abs()} days ago',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Metadata Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _detailRow(Icons.devices_rounded, 'Product', warranty.itemName),
                    const Divider(height: 20),
                    _detailRow(Icons.storefront_rounded, 'Store', warranty.merchantName ?? 'Not specified'),
                    const Divider(height: 20),
                    _detailRow(Icons.category_outlined, 'Category', warranty.category),
                    const Divider(height: 20),
                    _detailRow(Icons.calendar_today_rounded, 'Purchase Date', warranty.formattedPurchaseDate),
                    const Divider(height: 20),
                    _detailRow(Icons.event_available_rounded, 'Expiration Date', warranty.formattedExpirationDate),
                    const Divider(height: 20),
                    _detailRow(Icons.timer_outlined, 'Duration', '${warranty.warrantyDurationMonths} Months'),
                    if (warranty.serialNumber != null) ...[
                      const Divider(height: 20),
                      _detailRow(Icons.tag_rounded, 'Serial Number', warranty.serialNumber!),
                    ],
                    if (warranty.pricePaid != null) ...[
                      const Divider(height: 20),
                      _detailRow(Icons.attach_money_rounded, 'Price Paid', warranty.formattedPrice),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (warranty.notes != null && warranty.notes!.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Notes & Tags',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      Text(warranty.notes!, style: const TextStyle(color: Color(0xFF475569))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Attached Images Section
            const Text(
              'Proof of Purchase Photos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _imagePreviewBox(
                    title: 'Receipt Image',
                    imageUrlOrPath: warranty.receiptImageUrl,
                  ),
                ),
                if (warranty.serialImageUrl != null && warranty.serialImageUrl!.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: _imagePreviewBox(
                      title: 'Serial Label',
                      imageUrlOrPath: warranty.serialImageUrl!,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 28),

            // Export Dossier Button
            ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('Export Official Claim PDF'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () async {
                try {
                  await PdfDossierService.generateAndShareDossier(
                    warranty: warranty,
                    userEmail: authState.user?.email,
                  );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ErrorMessages.friendly(
                            e,
                            fallback: "Couldn't create the PDF right now. Please try again.",
                          ),
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF64748B)),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 14)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _imagePreviewBox({required String title, required String imageUrlOrPath}) {
    Widget imageWidget;
    if (imageUrlOrPath.startsWith('http://') || imageUrlOrPath.startsWith('https://')) {
      imageWidget = Image.network(
        imageUrlOrPath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
      );
    } else {
      imageWidget = Image.file(
        File(imageUrlOrPath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
      );
    }


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 160,
            width: double.infinity,
            color: Colors.grey.shade100,
            child: imageWidget,
          ),
        ),
      ],
    );
  }
}
