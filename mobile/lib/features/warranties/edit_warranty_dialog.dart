import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/config/app_config.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/error_messages.dart';
import '../../data/models/warranty_model.dart';
import '../notifications/notification_service.dart';

class EditWarrantyDialog extends ConsumerStatefulWidget {
  final WarrantyModel warranty;

  const EditWarrantyDialog({super.key, required this.warranty});

  @override
  ConsumerState<EditWarrantyDialog> createState() => _EditWarrantyDialogState();
}

class _EditWarrantyDialogState extends ConsumerState<EditWarrantyDialog> {
  static const List<String> _baseCurrencies = ['USD', 'EUR', 'GBP', 'CAD', 'AUD'];

  final _formKey = GlobalKey<FormState>();

  late TextEditingController _itemNameController;
  late TextEditingController _merchantController;
  late TextEditingController _serialController;
  late TextEditingController _priceController;
  late TextEditingController _durationController;
  late TextEditingController _notesController;

  late String _category;
  late String _currency;
  late List<String> _currencyOptions;
  late DateTime _purchaseDate;
  late DateTime _expirationDate;
  bool _isSaving = false;

  static String _normalizeCurrency(String raw) {
    final code = raw.trim().toUpperCase();
    if (RegExp(r'^[A-Z]{3}$').hasMatch(code)) return code;
    return AppConfig.defaultCurrency;
  }

  @override
  void initState() {
    super.initState();
    final w = widget.warranty;
    _itemNameController = TextEditingController(text: w.itemName);
    _merchantController = TextEditingController(text: w.merchantName ?? '');
    _serialController = TextEditingController(text: w.serialNumber ?? '');
    _priceController = TextEditingController(
      text: w.pricePaid != null ? w.pricePaid!.toString() : '',
    );
    _durationController = TextEditingController(
      text: w.warrantyDurationMonths.clamp(1, 600).toString(),
    );
    _notesController = TextEditingController(text: w.notes ?? '');

    _category = AppConfig.categories.contains(w.category)
        ? w.category
        : AppConfig.defaultCategory;
    _currency = _normalizeCurrency(w.currency);
    _currencyOptions = _baseCurrencies.contains(_currency)
        ? List<String>.from(_baseCurrencies)
        : [_currency, ..._baseCurrencies];
    _purchaseDate = w.purchaseDate;
    _expirationDate = w.warrantyExpirationDate;
  }

  void _recalculateExpiration() {
    final months = int.tryParse(_durationController.text.trim()) ?? 12;
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

  @override
  void dispose() {
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
        _recalculateExpiration();
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
      final notifSettings = ref.read(notificationSettingsProvider);

      final draft = WarrantyModel(
        id: widget.warranty.id,
        userId: widget.warranty.userId,
        itemName: _itemNameController.text.trim(),
        merchantName: _merchantController.text.trim().isEmpty
            ? null
            : _merchantController.text.trim(),
        category: _category,
        purchaseDate: _purchaseDate,
        warrantyDurationMonths: int.tryParse(_durationController.text.trim()) ?? 12,
        warrantyExpirationDate: _expirationDate,
        serialNumber: _serialController.text.trim().isEmpty
            ? null
            : _serialController.text.trim(),
        pricePaid: double.tryParse(_priceController.text.trim()),
        currency: _currency,
        receiptImageUrl: widget.warranty.receiptImageUrl,
        receiptImagePath: widget.warranty.receiptImagePath,
        serialImageUrl: widget.warranty.serialImageUrl,
        serialImagePath: widget.warranty.serialImagePath,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: widget.warranty.createdAt,
        updatedAt: DateTime.now(),
        isLocalOnly: widget.warranty.isLocalOnly,
      );

      final saved = await repo.updateWarranty(draft);
      await NotificationService.instance.scheduleForWarranty(saved, notifSettings);
      ref.invalidate(warrantiesStreamProvider);

      if (mounted) {
        Navigator.of(context).pop(saved);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Warranty updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ErrorMessages.friendly(e, fallback: "Couldn't save your changes. Please try again."),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
              child: Row(
                children: [
                  const Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Edit Warranty',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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

                      TextFormField(
                        controller: _merchantController,
                        decoration: const InputDecoration(
                          labelText: 'Store / Merchant Name',
                          prefixIcon: Icon(Icons.storefront_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),

                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: AppConfig.categories
                            .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _category = val);
                        },
                      ),
                      const SizedBox(height: 14),

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
                              onChanged: (_) => setState(_recalculateExpiration),
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

                      InkWell(
                        onTap: _pickExpirationDate,
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Warranty Expiration Date',
                            prefixIcon: Icon(Icons.event_available_rounded),
                          ),
                          child: Text(DateFormat.yMMMd().format(_expirationDate)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _serialController,
                        decoration: const InputDecoration(
                          labelText: 'Serial / Model Number (Optional)',
                          prefixIcon: Icon(Icons.tag_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),

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
                          : const Icon(Icons.save_rounded),
                      label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
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
