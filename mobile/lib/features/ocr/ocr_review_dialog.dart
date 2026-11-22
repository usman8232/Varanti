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
import '../../core/theme/app_theme.dart';
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

  static const List<String> _baseCurrencies = ['USD', 'EUR', 'GBP', 'CAD', 'AUD', 'PKR'];

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

  static double? _parsePrice(String raw) {
    final cleaned = raw.trim().replaceAll(',', '').replaceAll(' ', '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
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

    final rawDuration = extracted['warranty_duration_months'] is int
        ? extracted['warranty_duration_months'] as int
        : int.tryParse(extracted['warranty_duration_months']?.toString() ?? '12') ?? 12;
    _durationController = TextEditingController(
      text: rawDuration.clamp(1, 600).toString(),
    );
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
    final parsed = int.tryParse(_durationController.text.trim()) ?? 12;
    final months = parsed.clamp(1, 600);
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
    if (_saved || _isSaving) return;
    final images = widget.initialOcrData?['images'] as Map<String, dynamic>?;
    if (images == null) return;
    final receiptPath = images['receipt_path']?.toString();
    final serialPath = images['serial_path']?.toString();
    final apiClient = _apiClient;
    if (apiClient != null && apiClient.accessToken != null) {
      apiClient
          .discardUploads(receiptPath: receiptPath, serialPath: serialPath)
          .catchError((_) {});
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

  Future<void> _pickExpirationDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expirationDate.isBefore(_purchaseDate) ? _purchaseDate : _expirationDate,
      firstDate: _purchaseDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _expirationDate = picked);
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

      final durationMonths = (int.tryParse(_durationController.text.trim()) ?? 12).clamp(1, 600);
      final warranty = WarrantyModel(
        id: const Uuid().v4(),
        itemName: _itemNameController.text.trim(),
        merchantName: _merchantController.text.trim().isEmpty
            ? null
            : _merchantController.text.trim(),
        category: _category,
        purchaseDate: _purchaseDate,
        warrantyDurationMonths: durationMonths,
        warrantyExpirationDate: _expirationDate,
        serialNumber: _serialController.text.trim().isEmpty
            ? null
            : _serialController.text.trim(),
        pricePaid: _parsePrice(_priceController.text),
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
          const SnackBar(content: Text('Warranty saved to your vault.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ErrorMessages.friendly(
                e,
                fallback: "Couldn't save this warranty. Please try again.",
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hairline = AppTheme.hairlineOf(context);
    final subtle = AppTheme.subtleSurfaceOf(context);
    final muted = AppTheme.mutedTextOf(context);
    final crimson = AppTheme.crimsonOf(context);
    final brightness = Theme.of(context).brightness;
    final needsReview = widget.initialOcrData?['needs_review'] == true ||
        widget.initialOcrData?['ocr_failed'] == true;

    return PopScope(
      canPop: !_isSaving,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540, maxHeight: 740),
          child: Column(
            children: [
              // Modal Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: crimson.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.document_scanner_outlined,
                        color: crimson,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Review Warranty',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: hairline),

              // Form Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Receipt Preview Card
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: subtle,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: hairline),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(widget.receiptFilePath),
                                  width: 68,
                                  height: 68,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    width: 68,
                                    height: 68,
                                    color: Theme.of(context).colorScheme.surface,
                                    child: Icon(Icons.receipt_long_rounded, color: muted),
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
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Coverage ends ${DateFormat.yMMMd().format(_expirationDate)}',
                                      style: TextStyle(color: muted, fontSize: 12),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        if (widget.serialFilePath != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: ShapeDecoration(
                                              color: AppTheme.getStatusSoftBg(
                                                'active',
                                                brightness,
                                              ),
                                              shape: const StadiumBorder(),
                                            ),
                                            child: const Text(
                                              'Serial Photo Added',
                                              style: TextStyle(
                                                color: AppTheme.statusActive,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        if (needsReview)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: ShapeDecoration(
                                              color: AppTheme.getStatusSoftBg(
                                                'expiring_soon',
                                                brightness,
                                              ),
                                              shape: const StadiumBorder(),
                                            ),
                                            child: const Text(
                                              'Please verify fields',
                                              style: TextStyle(
                                                color: AppTheme.statusExpiringSoon,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Item Name (Required)
                        TextFormField(
                          controller: _itemNameController,
                          decoration: const InputDecoration(
                            labelText: 'Product / Item Name *',
                            prefixIcon: Icon(Icons.devices_rounded),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty
                              ? 'Item name is required'
                              : null,
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: InkWell(
                                onTap: _pickPurchaseDate,
                                borderRadius: BorderRadius.circular(16),
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
                                onChanged: (_) => setState(_calculateExpiration),
                                validator: (val) {
                                  final n = int.tryParse(val?.trim() ?? '');
                                  if (n == null || n < 1) return 'Min 1 mo';
                                  if (n > 600) return 'Max 600 mo';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Expiration Date (Auto-calculated, tap to override)
                        InkWell(
                          onTap: _pickExpirationDate,
                          borderRadius: BorderRadius.circular(16),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Warranty Expiration Date',
                              prefixIcon: Icon(Icons.event_available_rounded),
                            ),
                            child: Text(DateFormat.yMMMd().format(_expirationDate)),
                          ),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _priceController,
                                keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Price Paid',
                                  prefixIcon: Icon(Icons.payments_outlined),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return null;
                                  final parsed = _parsePrice(val);
                                  if (parsed == null) return 'Enter a valid number';
                                  if (parsed < 0) return 'Must be 0 or more';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                initialValue: _currency,
                                decoration: const InputDecoration(labelText: 'Currency'),
                                items: _currencyOptions
                                    .map((code) => DropdownMenuItem(
                                          value: code,
                                          child: Text(code),
                                        ))
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

              Divider(height: 1, color: hairline),

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
                      child: FilledButton.icon(
                        icon: _isSaving
                            ? const SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_rounded, size: 18),
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
      ),
    );
  }
}
