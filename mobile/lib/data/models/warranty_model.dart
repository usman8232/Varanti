import 'package:intl/intl.dart';

class WarrantyModel {
  final String id;
  final String? userId;
  final String itemName;
  final String? merchantName;
  final String category;
  final DateTime purchaseDate;
  final int warrantyDurationMonths;
  final DateTime warrantyExpirationDate;
  final String? serialNumber;
  final double? pricePaid;
  final String currency;
  final String receiptImageUrl;
  final String? receiptImagePath;
  final String? serialImageUrl;
  final String? serialImagePath;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isLocalOnly;

  WarrantyModel({
    required this.id,
    this.userId,
    required this.itemName,
    this.merchantName,
    this.category = 'Consumer Tech',
    required this.purchaseDate,
    this.warrantyDurationMonths = 12,
    required this.warrantyExpirationDate,
    this.serialNumber,
    this.pricePaid,
    this.currency = 'USD',
    required this.receiptImageUrl,
    this.receiptImagePath,
    this.serialImageUrl,
    this.serialImagePath,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.isLocalOnly = false,
  });

  /// Days remaining until warranty expires (calendar-day based)
  int get daysRemaining {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(
      warrantyExpirationDate.year,
      warrantyExpirationDate.month,
      warrantyExpirationDate.day,
    );
    return exp.difference(today).inDays;
  }

  /// Active (> 30 days), Expiring Soon (1-30 days), Expired (<= 0 days)
  String get status {
    final days = daysRemaining;
    if (days > 30) return 'active';
    if (days >= 1) return 'expiring_soon';
    return 'expired';
  }

  String get formattedPurchaseDate => DateFormat.yMMMd().format(purchaseDate);
  String get formattedExpirationDate => DateFormat.yMMMd().format(warrantyExpirationDate);

  String get formattedPrice {
    if (pricePaid == null) return '';
    return '$currency ${pricePaid!.toStringAsFixed(2)}';
  }

  factory WarrantyModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is DateTime) return val;
      return DateTime.parse(val.toString());
    }

    return WarrantyModel(
      id: json['id'].toString(),
      userId: json['user_id']?.toString(),
      itemName: json['item_name'] ?? '',
      merchantName: json['merchant_name'],
      category: json['category'] ?? 'Consumer Tech',
      purchaseDate: parseDate(json['purchase_date']),
      warrantyDurationMonths: json['warranty_duration_months'] is int
          ? json['warranty_duration_months']
          : int.tryParse(json['warranty_duration_months']?.toString() ?? '12') ?? 12,
      warrantyExpirationDate: parseDate(json['warranty_expiration_date']),
      serialNumber: json['serial_number'],
      pricePaid: json['price_paid'] != null ? double.tryParse(json['price_paid'].toString()) : null,
      currency: json['currency'] ?? 'USD',
      receiptImageUrl: json['receipt_image_url'] ?? '',
      receiptImagePath: json['receipt_image_path'],
      serialImageUrl: json['serial_image_url'],
      serialImagePath: json['serial_image_path'],
      notes: json['notes'],
      createdAt: json['created_at'] != null ? parseDate(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? parseDate(json['updated_at']) : null,
      isLocalOnly: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_name': itemName,
      'merchant_name': merchantName,
      'category': category,
      'purchase_date': DateFormat('yyyy-MM-dd').format(purchaseDate),
      'warranty_duration_months': warrantyDurationMonths,
      'warranty_expiration_date': DateFormat('yyyy-MM-dd').format(warrantyExpirationDate),
      'serial_number': serialNumber,
      'price_paid': pricePaid,
      'currency': currency,
      'receipt_image_url': receiptImageUrl,
      'receipt_image_path': receiptImagePath,
      'serial_image_url': serialImageUrl,
      'serial_image_path': serialImagePath,
      'notes': notes,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'item_name': itemName,
      'merchant_name': merchantName,
      'category': category,
      'purchase_date': DateFormat('yyyy-MM-dd').format(purchaseDate),
      'warranty_duration_months': warrantyDurationMonths,
      'warranty_expiration_date': DateFormat('yyyy-MM-dd').format(warrantyExpirationDate),
      'serial_number': serialNumber,
      'price_paid': pricePaid,
      'currency': currency,
      'notes': notes,
    };
  }

  factory WarrantyModel.fromSqlite(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) => DateTime.parse(val.toString());

    return WarrantyModel(
      id: map['id'].toString(),
      userId: map['user_id']?.toString(),
      itemName: map['item_name'] ?? '',
      merchantName: map['merchant_name'],
      category: map['category'] ?? 'Consumer Tech',
      purchaseDate: parseDate(map['purchase_date']),
      warrantyDurationMonths: map['warranty_duration_months'] is int
          ? map['warranty_duration_months']
          : int.tryParse(map['warranty_duration_months']?.toString() ?? '12') ?? 12,
      warrantyExpirationDate: parseDate(map['warranty_expiration_date']),
      serialNumber: map['serial_number'],
      pricePaid: map['price_paid'] != null ? double.tryParse(map['price_paid'].toString()) : null,
      currency: map['currency'] ?? 'USD',
      receiptImageUrl: map['receipt_image_url'] ?? '',
      receiptImagePath: map['receipt_image_path'],
      serialImageUrl: map['serial_image_url'],
      serialImagePath: map['serial_image_path'],
      notes: map['notes'],
      createdAt: map['created_at'] != null ? parseDate(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? parseDate(map['updated_at']) : null,
      isLocalOnly: (map['is_local_only'] == 1),
    );
  }

  Map<String, dynamic> toSqlite() {
    return {
      'id': id,
      'user_id': userId,
      'item_name': itemName,
      'merchant_name': merchantName,
      'category': category,
      'purchase_date': DateFormat('yyyy-MM-dd').format(purchaseDate),
      'warranty_duration_months': warrantyDurationMonths,
      'warranty_expiration_date': DateFormat('yyyy-MM-dd').format(warrantyExpirationDate),
      'serial_number': serialNumber,
      'price_paid': pricePaid,
      'currency': currency,
      'receipt_image_url': receiptImageUrl,
      'receipt_image_path': receiptImagePath,
      'serial_image_url': serialImageUrl,
      'serial_image_path': serialImagePath,
      'notes': notes,
      'created_at': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updated_at': updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'is_local_only': isLocalOnly ? 1 : 0,
    };
  }

  WarrantyModel copyWith({
    String? id,
    String? userId,
    String? itemName,
    String? merchantName,
    String? category,
    DateTime? purchaseDate,
    int? warrantyDurationMonths,
    DateTime? warrantyExpirationDate,
    String? serialNumber,
    double? pricePaid,
    String? currency,
    String? receiptImageUrl,
    String? receiptImagePath,
    String? serialImageUrl,
    String? serialImagePath,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isLocalOnly,
  }) {
    return WarrantyModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      itemName: itemName ?? this.itemName,
      merchantName: merchantName ?? this.merchantName,
      category: category ?? this.category,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      warrantyDurationMonths: warrantyDurationMonths ?? this.warrantyDurationMonths,
      warrantyExpirationDate: warrantyExpirationDate ?? this.warrantyExpirationDate,
      serialNumber: serialNumber ?? this.serialNumber,
      pricePaid: pricePaid ?? this.pricePaid,
      currency: currency ?? this.currency,
      receiptImageUrl: receiptImageUrl ?? this.receiptImageUrl,
      receiptImagePath: receiptImagePath ?? this.receiptImagePath,
      serialImageUrl: serialImageUrl ?? this.serialImageUrl,
      serialImagePath: serialImagePath ?? this.serialImagePath,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isLocalOnly: isLocalOnly ?? this.isLocalOnly,
    );
  }
}
