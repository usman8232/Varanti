import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/error_messages.dart';
import '../../data/models/warranty_model.dart';
import '../notifications/notification_service.dart';

class OcrReviewDialog extends ConsumerStatefulWidget {
  final String receiptFilePath;
  final String? serialFilePath;
  final Map<String, dynamic>? initialOcrData;

  const OcrReviewDialog({
    super.key,
    required this.receiptFilePath,
    this.serialFilePath,
    this.initialOcrData,
  });

  @override
  ConsumerState<OcrReviewDialog> createState() => _OcrReviewDialogState();
}

class _OcrReviewDialogState extends ConsumerState<OcrReviewDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _itemNameController;
  late TextEditingController _merchantController;
  late TextEditingController _serialController;
  late TextEditingController _priceController;
  late TextEditingController _durationController;
  late TextEditingController _notesController;

  static const List<String> _baseCurrencies = ['USD', 'EUR', 'GBP', 'CAD', 'AUD'];

  late String _category;
  late String _currency;
  late List<String> _currencyOptions;
  late DateTime _purchaseDate;
  late DateTime _expirationDate;
  ApiClient? _apiClient;
  bool _isSaving = false;
  bool _saved = false;

  static String _normalizeCurrency(dynamic raw) {
    final code = (raw ?? AppConfig.defaultCurrency).toString().trim().toUpperCase();
    if (RegExp(r'^[A-Z]{3}$').hasMatch(code)) return code;
    return AppConfig.defaultCurrency;
  }

  @override
  void initState() {
    super.initState();
    final extracted = (widget.initialOcrData?['extracted'] as Map<String, dynamic>?) ?? {};

    _itemNameController = TextEditingController(text: extracted['item_name'] ?? '');
    _merchantController = TextEditingController(text: extracted['merchant_name'] ?? '');
    _serialController = TextEditingController(text: extracted['serial_number'] ?? '');
    _priceController = TextEditingController(
      text: extracted['total_amount'] != null ? extracted['total_amount'].toString() : '',
    );

    final duration = extracted['warranty_duration_months'] is int
        ? extracted['warranty_duration_months']
        : int.tryParse(extracted['warranty_duration_months']?.toString() ?? '12') ?? 12;
    _durationController = TextEditingController(text: duration.clamp(1, 600).toString());
    _notesController = TextEditingController();

    _category = AppConfig.defaultCategory;
    _currency = _normalizeCurrency(extracted['currency']);
    _currencyOptions = _baseCurrencies.contains(_currency)
        ? List<String>.from(_baseCurrencies)
        : [_currency, ..._baseCurrencies];
    _apiClient = ref.read(apiClientProvider);

    if (extracted['purchase_date'] != null) {
      try {
        _purchaseDate = DateTime.parse(extracted['purchase_date'].toString());
      } catch (_) {
        _purchaseDate = DateTime.now();
      }
    } else {
      _purchaseDate = DateTime.now();
    }

    _calculateExpiration();
  }

  void _calculateExpiration() {
    final months = int.tryParse(_durationController.text.trim()) ?? 12;
    // Purchase date + calendar months
    int year = _purchaseDate.year + (months ~/ 12);
    int month = _purchaseDate.month + (months % 12);
    if (month > 12) {
      year += 1;
      month -= 12;
    }
    final daysInTargetMonth = DateTime(year, month + 1, 0).day;
    final day = _purchaseDate.day > daysInTargetMonth ? daysInTargetMonth : _purchaseDate.day;
    _expirationDate = DateTime(year, month, day);
  }

  Future<String> _persistLocalCopy(String sourcePath) async {
    try {
      final src = File(sourcePath);
      if (!await src.exists()) return sourcePath;
      final docsDir = await getApplicationDocumentsDirectory();
      final receiptsDir = Directory(p.join(docsDir.path, 'varanti_receipts'));
      if (!await receiptsDir.exists()) {
        await receiptsDir.create(recursive: true);
      }
      final ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
      final destPath = p.join(receiptsDir.path, '${const Uuid().v4()}$ext');
      await src.copy(destPath);
      return destPath;
    } catch (_) {
      return sourcePath;
    }
  }

  void _discardUploadedImagesIfUnsaved() {
    if (_saved) return;
    final images = widget.initialOcrData?['images'] as Map<String, dynamic>?;
    if (images == null) return;
    final receiptPath = images['receipt_path']?.toString();
    final serialPath = images['serial_path']?.toString();
    final apiClient = _apiClient;
    if (apiClient != null && apiClient.accessToken != null) {
      apiClient.discardUploads(receiptPath: receiptPath, serialPath: serialPath).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _discardUploadedImagesIfUnsaved();
    _itemNameController.dispose();
    _merchantController.dispose();
    _serialController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickPurchaseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        _purchaseDate = picked;
        _calculateExpiration();
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final repo = ref.read(warrantyRepositoryProvider);
      final authState = ref.read(authProvider);
      final images = widget.initialOcrData?['images'] as Map<String, dynamic>?;

      String receiptUrl = images?['receipt_url']?.toString() ?? widget.receiptFilePath;
      String? serialUrl = images?['serial_url']?.toString() ?? widget.serialFilePath;
      if (authState.isGuest) {
        receiptUrl = await _persistLocalCopy(widget.receiptFilePath);
        if (widget.serialFilePath != null && widget.serialFilePath!.isNotEmpty) {
          serialUrl = await _persistLocalCopy(widget.serialFilePath!);
        }
      }

      final warranty = WarrantyModel(
        id: const Uuid().v4(),
        itemName: _itemNameController.text.trim(),
        merchantName: _merchantController.text.trim().isEmpty ? null : _merchantController.text.trim(),
        category: _category,
        purchaseDate: _purchaseDate,
        warrantyDurationMonths: int.tryParse(_durationController.text.trim()) ?? 12,
        warrantyExpirationDate: _expirationDate,
        serialNumber: _serialController.text.trim().isEmpty ? null : _serialController.text.trim(),
        pricePaid: double.tryParse(_priceController.text.trim()),
        currency: _currency,
        receiptImageUrl: receiptUrl,
        receiptImagePath: images?['receipt_path']?.toString(),
        serialImageUrl: serialUrl,
        serialImagePath: images?['serial_path']?.toString(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      final savedWarranty = await repo.saveWarranty(warranty);
      _saved = true;
      final notifSettings = ref.read(notificationSettingsProvider);
      await NotificationService.instance.scheduleForWarranty(savedWarranty, notifSettings);
      ref.invalidate(warrantiesStreamProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Warranty saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ErrorMessages.friendly(e, fallback: "Couldn't save this warranty. Please try again."),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 720),
        child: Column(
          children: [
            // Modal Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
              child: Row(
                children: [
                  const Icon(Icons.document_scanner_rounded, color: Color(0xFF2563EB)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Review Warranty Details',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Image Thumbnail Preview
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              File(widget.receiptFilePath),
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.receipt, color: Colors.grey),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Receipt Attached',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                                if (widget.serialFilePath != null)
                                  const Text(
                                    '+ Serial Label Attached',
                                    style: TextStyle(color: Color(0xFF10B981), fontSize: 12),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  'Expires: ${DateFormat.yMMMd().format(_expirationDate)}',
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Item Name (Required)
                      TextFormField(
                        controller: _itemNameController,
                        decoration: const InputDecoration(
                          labelText: 'Product / Item Name *',
                          prefixIcon: Icon(Icons.devices_rounded),
                        ),
                        validator: (val) =>
                            val == null || val.trim().isEmpty ? 'Item name is required' : null,
                      ),
                      const SizedBox(height: 14),

                      // Merchant Name
                      TextFormField(
                        controller: _merchantController,
                        decoration: const InputDecoration(
                          labelText: 'Store / Merchant Name',
                          prefixIcon: Icon(Icons.storefront_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Category Dropdown
                      DropdownButtonFormField<String>(
                        initialValue: _category,

                        decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: AppConfig.categories.map((cat) {
                          return DropdownMenuItem(value: cat, child: Text(cat));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _category = val);
                        },
                      ),
                      const SizedBox(height: 14),

                      // Purchase Date & Duration Row
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: InkWell(
                              onTap: _pickPurchaseDate,
                              borderRadius: BorderRadius.circular(12),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Purchase Date',
                                  prefixIcon: Icon(Icons.calendar_today_rounded),
                                ),
                                child: Text(DateFormat.yMMMd().format(_purchaseDate)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _durationController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Duration',
                                suffixText: 'mo',
                              ),
                              onChanged: (_) => setState(() => _calculateExpiration()),
                              validator: (val) {
                                final n = int.tryParse(val ?? '');
                                if (n == null || n < 1) return 'Min 1 mo';
                                if (n > 600) return 'Max 600 mo';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Serial Number
                      TextFormField(
                        controller: _serialController,
                        decoration: const InputDecoration(
                          labelText: 'Serial / Model Number (Optional)',
                          prefixIcon: Icon(Icons.tag_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Price Paid & Currency
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _priceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Price Paid',
                                prefixIcon: Icon(Icons.attach_money_rounded),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              initialValue: _currency,
                              decoration: const InputDecoration(labelText: 'Currency'),
                              items: _currencyOptions
                                  .map((code) => DropdownMenuItem(value: code, child: Text(code)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _currency = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Notes / Tags
                      TextFormField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Notes or Tags (Optional)',
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Modal Footer Buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(_isSaving ? 'Saving...' : 'Save Warranty'),
                      onPressed: _isSaving ? null : _save,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
