import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/warranty_model.dart';

class SavedPdfResult {
  final File file;
  final String filename;
  final String folderLabel;

  const SavedPdfResult({
    required this.file,
    required this.filename,
    required this.folderLabel,
  });
}

class PdfDossierService {
  static final PdfColor _brandCrimson = PdfColor.fromInt(0xFFE40034);
  static final PdfColor _inkBlack = PdfColor.fromInt(0xFF0D0D0F);
  static final PdfColor _mutedText = PdfColor.fromInt(0xFF5F6368);
  static final PdfColor _hairline = PdfColor.fromInt(0xFFE6E8EC);
  static final PdfColor _subtleBg = PdfColor.fromInt(0xFFFAFAFA);

  static Future<pw.MemoryImage?> _loadImage(String? urlOrPath) async {
    if (urlOrPath == null || urlOrPath.isEmpty) return null;
    try {
      if (urlOrPath.startsWith('http://') || urlOrPath.startsWith('https://')) {
        final resp = await http
            .get(Uri.parse(urlOrPath))
            .timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
          return pw.MemoryImage(resp.bodyBytes);
        }
        return null;
      }
      final file = File(urlOrPath);
      if (await file.exists()) {
        return pw.MemoryImage(await file.readAsBytes());
      }
    } catch (e) {
      debugPrint('Could not load image for PDF ($urlOrPath): $e');
    }
    return null;
  }

  static String sanitizeFilename(String itemName) {
    final slug = itemName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return 'warranty-dossier-${slug.isEmpty ? 'item' : slug}.pdf';
  }

  static String portfolioFilename([DateTime? now]) {
    final stamp = DateFormat('yyyyMMdd').format(now ?? DateTime.now());
    return 'varanti-warranties-$stamp.pdf';
  }

  static String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'ACTIVE';
      case 'expiring_soon':
        return 'EXPIRING SOON';
      case 'expired':
      default:
        return 'EXPIRED';
    }
  }

  static PdfColor _statusBg(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return PdfColor.fromInt(0xFFE8F7EF);
      case 'expiring_soon':
        return PdfColor.fromInt(0xFFFEF3C7);
      case 'expired':
      default:
        return PdfColor.fromInt(0xFFFDECEF);
    }
  }

  static PdfColor _statusFg(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return PdfColor.fromInt(0xFF0F9D58);
      case 'expiring_soon':
        return PdfColor.fromInt(0xFFD97706);
      case 'expired':
      default:
        return _brandCrimson;
    }
  }

  /// Generates clean, official, unwatermarked A4 PDF bytes for a single warranty claim dossier.
  static Future<Uint8List> buildDossierPdfBytes({
    required WarrantyModel warranty,
    String? userEmail,
    String? userName,
    String? userPhone,
  }) async {
    final pdf = pw.Document(
      title: 'Varanti Claim Dossier - ${warranty.itemName}',
      author: 'Varanti',
    );

    final receiptImage = await _loadImage(warranty.receiptImageUrl);
    final serialImage = await _loadImage(warranty.serialImageUrl);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Brand Accent Top Bar
              pw.Container(height: 3, color: _brandCrimson),
              pw.SizedBox(height: 14),

              // Header Banner
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'WARRANTY CLAIM DOSSIER',
                        style: pw.TextStyle(
                          fontSize: 19,
                          fontWeight: pw.FontWeight.bold,
                          color: _inkBlack,
                          letterSpacing: 0.6,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'VARANTi | Official Unwatermarked Proof of Purchase',
                        style: pw.TextStyle(fontSize: 9.5, color: _mutedText),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: pw.BoxDecoration(
                      color: _statusBg(warranty.status),
                      borderRadius: pw.BorderRadius.circular(999),
                    ),
                    child: pw.Text(
                      _statusLabel(warranty.status),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                        color: _statusFg(warranty.status),
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(thickness: 1, color: _hairline),
              pw.SizedBox(height: 12),

              // Product Info Grid
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: _subtleBg,
                  border: pw.Border.all(color: _hairline),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    _infoRow('Product / Item Name', warranty.itemName),
                    _infoRow('Store / Merchant', warranty.merchantName ?? 'N/A'),
                    _infoRow('Category', warranty.category),
                    _infoRow('Serial / Model Number', warranty.serialNumber ?? 'N/A'),
                    _infoRow('Purchase Date', warranty.formattedPurchaseDate),
                    _infoRow('Warranty Expiration', warranty.formattedExpirationDate),
                    _infoRow('Duration', '${warranty.warrantyDurationMonths} Months'),
                    _infoRow(
                      'Coverage Status',
                      warranty.daysRemaining > 0
                          ? '${warranty.daysRemaining} days remaining'
                          : warranty.daysRemaining == 0
                              ? 'Expired today'
                              : 'Expired ${warranty.daysRemaining.abs()} days ago',
                    ),
                    if (warranty.pricePaid != null)
                      _infoRow('Price Paid', warranty.formattedPrice),
                    if (userName != null && userName.isNotEmpty)
                      _infoRow('Claimant Name', userName),
                    if (userEmail != null && userEmail.isNotEmpty)
                      _infoRow('Claimant Email', userEmail),
                    if (userPhone != null && userPhone.isNotEmpty)
                      _infoRow('Claimant Phone', userPhone),
                  ],
                ),
              ),

              if (warranty.notes != null && warranty.notes!.isNotEmpty) ...[
                pw.SizedBox(height: 12),
                pw.Text(
                  'NOTES & TAGS',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9.5,
                    color: _mutedText,
                    letterSpacing: 1.0,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(warranty.notes!, style: const pw.TextStyle(fontSize: 10)),
              ],

              pw.SizedBox(height: 16),
              pw.Text(
                'PROOF OF PURCHASE (RECEIPT & SERIAL LABEL)',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                  color: _inkBlack,
                  letterSpacing: 0.8,
                ),
              ),
              pw.SizedBox(height: 8),

              // Embedded Receipt & Serial Photos
              pw.Expanded(
                child: (receiptImage == null && serialImage == null)
                    ? pw.Container(
                        width: double.infinity,
                        alignment: pw.Alignment.center,
                        padding: const pw.EdgeInsets.all(20),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: _hairline),
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Text(
                          'Receipt photo could not be attached offline. Please reconnect and re-export if needed.',
                          style: pw.TextStyle(fontSize: 10, color: _mutedText),
                        ),
                      )
                    : pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          if (receiptImage != null)
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    'Receipt Image',
                                    style: pw.TextStyle(fontSize: 9.5, color: _mutedText),
                                  ),
                                  pw.SizedBox(height: 4),
                                  pw.Expanded(
                                    child: pw.Image(receiptImage, fit: pw.BoxFit.contain),
                                  ),
                                ],
                              ),
                            ),
                          if (receiptImage != null && serialImage != null)
                            pw.SizedBox(width: 16),
                          if (serialImage != null)
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    'Serial Label Image',
                                    style: pw.TextStyle(fontSize: 9.5, color: _mutedText),
                                  ),
                                  pw.SizedBox(height: 4),
                                  pw.Expanded(
                                    child: pw.Image(serialImage, fit: pw.BoxFit.contain),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generates a clean, multi-page A4 PDF portfolio report of all saved warranties.
  static Future<Uint8List> buildPortfolioPdfBytes({
    required List<WarrantyModel> warranties,
    String? userName,
    String? userEmail,
  }) async {
    final pdf = pw.Document(
      title: 'Varanti Warranty Portfolio Report',
      author: 'Varanti',
    );

    final activeCount = warranties.where((w) => w.status == 'active').length;
    final expiringCount = warranties.where((w) => w.status == 'expiring_soon').length;
    final expiredCount = warranties.where((w) => w.status == 'expired').length;
    final generatedOn = DateFormat.yMMMd().format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(height: 3, color: _brandCrimson),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'VARANTi WARRANTY PORTFOLIO',
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: _inkBlack,
                  ),
                ),
                pw.Text(
                  'Generated $generatedOn',
                  style: pw.TextStyle(fontSize: 9, color: _mutedText),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(color: _hairline, thickness: 1),
            pw.SizedBox(height: 10),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Varanti | 100% Free & Unwatermarked Warranty Record',
              style: pw.TextStyle(fontSize: 8.5, color: _mutedText),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 8.5, color: _mutedText),
            ),
          ],
        ),
        build: (context) => [
          if ((userName != null && userName.isNotEmpty) ||
              (userEmail != null && userEmail.isNotEmpty)) ...[
            pw.Text(
              'Account: ${[
                if (userName != null && userName.isNotEmpty) userName,
                if (userEmail != null && userEmail.isNotEmpty) userEmail,
              ].join(' | ')}',
              style: pw.TextStyle(fontSize: 10, color: _mutedText),
            ),
            pw.SizedBox(height: 10),
          ],

          // Summary Row
          pw.Row(
            children: [
              _summaryBox('Total Items', '${warranties.length}', _inkBlack),
              pw.SizedBox(width: 8),
              _summaryBox('Active', '$activeCount', PdfColor.fromInt(0xFF0F9D58)),
              pw.SizedBox(width: 8),
              _summaryBox(
                'Expiring Soon',
                '$expiringCount',
                PdfColor.fromInt(0xFFD97706),
              ),
              pw.SizedBox(width: 8),
              _summaryBox('Expired', '$expiredCount', _brandCrimson),
            ],
          ),
          pw.SizedBox(height: 16),

          // Structured Table of All Warranties
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(color: _inkBlack),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            border: pw.TableBorder.all(color: _hairline, width: 0.7),
            headers: const [
              'Item',
              'Store',
              'Category',
              'Purchased',
              'Expires',
              'Serial',
              'Price',
              'Status',
            ],
            data: warranties
                .map(
                  (w) => [
                    w.itemName,
                    w.merchantName ?? '-',
                    w.category,
                    w.formattedPurchaseDate,
                    w.formattedExpirationDate,
                    w.serialNumber ?? '-',
                    w.pricePaid != null ? w.formattedPrice : '-',
                    _statusLabel(w.status),
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  /// Writes PDF bytes directly to device storage (Downloads/Varanti when writable,
  /// with automatic fallback to external app Downloads or Documents/Varanti).
  static Future<SavedPdfResult> savePdfBytesToDevice({
    required Uint8List bytes,
    required String filename,
  }) async {
    final candidates = <({Directory dir, String label})>[];

    if (!kIsWeb && Platform.isAndroid) {
      candidates.add((
        dir: Directory('/storage/emulated/0/Download/Varanti'),
        label: 'Downloads/Varanti',
      ));
      try {
        final extDownloads = await getExternalStorageDirectories(
          type: StorageDirectory.downloads,
        );
        if (extDownloads != null && extDownloads.isNotEmpty) {
          candidates.add((
            dir: Directory(p.join(extDownloads.first.path, 'Varanti')),
            label: 'App Downloads/Varanti',
          ));
        }
      } catch (_) {}
    } else if (!kIsWeb) {
      try {
        final dl = await getDownloadsDirectory();
        if (dl != null) {
          candidates.add((
            dir: Directory(p.join(dl.path, 'Varanti')),
            label: 'Downloads/Varanti',
          ));
        }
      } catch (_) {}
    }

    final docs = await getApplicationDocumentsDirectory();
    candidates.add((
      dir: Directory(p.join(docs.path, 'Varanti')),
      label: 'Documents/Varanti',
    ));

    Object? lastError;
    for (final candidate in candidates) {
      try {
        if (!await candidate.dir.exists()) {
          await candidate.dir.create(recursive: true);
        }
        final file = File(p.join(candidate.dir.path, filename));
        await file.writeAsBytes(bytes, flush: true);
        return SavedPdfResult(
          file: file,
          filename: filename,
          folderLabel: candidate.label,
        );
      } catch (e) {
        lastError = e;
      }
    }

    throw FileSystemException(
      'Unable to save PDF file ($lastError)',
      filename,
    );
  }

  /// Saves a single warranty Claim Dossier PDF directly to device storage.
  static Future<SavedPdfResult> saveDossierPdf({
    required WarrantyModel warranty,
    String? userEmail,
    String? userName,
    String? userPhone,
  }) async {
    final bytes = await buildDossierPdfBytes(
      warranty: warranty,
      userEmail: userEmail,
      userName: userName,
      userPhone: userPhone,
    );
    return savePdfBytesToDevice(
      bytes: bytes,
      filename: sanitizeFilename(warranty.itemName),
    );
  }

  /// Saves a multi-item Warranty Portfolio PDF directly to device storage.
  static Future<SavedPdfResult> savePortfolioPdf({
    required List<WarrantyModel> warranties,
    String? userName,
    String? userEmail,
  }) async {
    final bytes = await buildPortfolioPdfBytes(
      warranties: warranties,
      userName: userName,
      userEmail: userEmail,
    );
    return savePdfBytesToDevice(
      bytes: bytes,
      filename: portfolioFilename(),
    );
  }

  /// Shares an already-saved PDF file through the native OS share sheet.
  static Future<void> shareSavedPdf(SavedPdfResult saved, {String? subject}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(saved.file.path, mimeType: 'application/pdf')],
        subject: subject ?? saved.filename,
      ),
    );
  }

  /// Generates and immediately triggers the native OS share sheet for a Claim Dossier PDF.
  static Future<void> generateAndShareDossier({
    required WarrantyModel warranty,
    String? userEmail,
    String? userName,
    String? userPhone,
  }) async {
    final bytes = await buildDossierPdfBytes(
      warranty: warranty,
      userEmail: userEmail,
      userName: userName,
      userPhone: userPhone,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: sanitizeFilename(warranty.itemName),
    );
  }

  static pw.Widget _summaryBox(String label, String value, PdfColor accent) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: pw.BoxDecoration(
          color: _subtleBg,
          border: pw.Border.all(color: _hairline),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
                color: accent,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(label, style: pw.TextStyle(fontSize: 8.5, color: _mutedText)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9.5,
              color: _mutedText,
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
                color: _inkBlack,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
