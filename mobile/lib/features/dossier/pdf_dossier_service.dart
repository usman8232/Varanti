import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/warranty_model.dart';

class PdfDossierService {
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

  static Future<void> generateAndShareDossier({
    required WarrantyModel warranty,
    String? userEmail,
  }) async {
    final pdf = pw.Document();

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
              // Header Banner
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'WARRANTY CLAIM DOSSIER',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.Text(
                        'Generated via Varanti (Free & Unwatermarked)',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: warranty.status == 'active'
                          ? PdfColors.green100
                          : warranty.status == 'expiring_soon'
                              ? PdfColors.amber100
                              : PdfColors.red100,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text(
                      warranty.status.toUpperCase(),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                        color: warranty.status == 'active'
                            ? PdfColors.green900
                            : warranty.status == 'expiring_soon'
                                ? PdfColors.amber900
                                : PdfColors.red900,
                      ),
                    ),
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5, color: PdfColors.grey400),
              pw.SizedBox(height: 12),

              // Product Info Grid
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    _infoRow('Item / Product Name:', warranty.itemName),
                    _infoRow('Store / Merchant:', warranty.merchantName ?? 'N/A'),
                    _infoRow('Category:', warranty.category),
                    _infoRow('Serial / Model Number:', warranty.serialNumber ?? 'N/A'),
                    _infoRow('Purchase Date:', warranty.formattedPurchaseDate),
                    _infoRow('Warranty Expiration:', warranty.formattedExpirationDate),
                    _infoRow('Duration:', '${warranty.warrantyDurationMonths} Months'),
                    _infoRow('Days Remaining:', '${warranty.daysRemaining} days'),
                    if (warranty.pricePaid != null)
                      _infoRow('Price Paid:', warranty.formattedPrice),
                    if (userEmail != null && userEmail.isNotEmpty)
                      _infoRow('Claimant Email:', userEmail),
                  ],
                ),
              ),

              if (warranty.notes != null && warranty.notes!.isNotEmpty) ...[
                pw.SizedBox(height: 12),
                pw.Text('Notes:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                pw.Text(warranty.notes!, style: const pw.TextStyle(fontSize: 10)),
              ],

              pw.SizedBox(height: 16),
              pw.Text(
                'PROOF OF PURCHASE (RECEIPT & LABELS)',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.blue900),
              ),
              pw.SizedBox(height: 8),

              // Images display
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (receiptImage != null)
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Receipt Image:', style: const pw.TextStyle(fontSize: 10)),
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
                            pw.Text('Serial Label Image:', style: const pw.TextStyle(fontSize: 10)),
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

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: sanitizeFilename(warranty.itemName),
    );
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}
