import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:mobile/features/purchase_orders/domain/models/purchase_order_models.dart';

class MaterialRequestPdfGenerator {
  static Future<Uint8List> generate(
      PurchaseOrderDetail details, String userName,
      {String? notes, String? shopName, String? shopAddress, String? shopPhone}) async {
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: await PdfGoogleFonts.interRegular(),
        bold: await PdfGoogleFonts.interBold(),
      ),
    );

    final fontMedium = await PdfGoogleFonts.interMedium();

    final po = details.po;
    final items = details.items;
    final formattedDate = po.poDate.isNotEmpty
        ? po.poDate
        : DateFormat('dd/MM/yyyy').format(DateTime.now());

    // Chunking logic exactly like web app
    final pages = <List<PurchaseOrderLineItem>>[];
    if (items.isEmpty) {
      pages.add([]);
    } else {
      pages.add(items.take(10).toList());
      var remaining = items.skip(10).toList();
      while (remaining.isNotEmpty) {
        pages.add(remaining.take(14).toList());
        remaining = remaining.skip(14).toList();
      }
    }

    final totalPages = pages.length;



    // Colors exactly from web app
    final colorNavy = PdfColor.fromHex('#1a237e');
    final colorBlue700 = PdfColor.fromHex('#1d4ed8');
    final colorGray800 = PdfColor.fromHex('#1f2937');
    final colorGray900 = PdfColor.fromHex('#111827');
    final colorGray700 = PdfColor.fromHex('#374151');
    final colorGray600 = PdfColor.fromHex('#4b5563');
    final colorGray500 = PdfColor.fromHex('#6b7280');
    final colorGray400 = PdfColor.fromHex('#9ca3af');
    final colorGray300 = PdfColor.fromHex('#d1d5db');
    final colorGray50 = PdfColor.fromHex('#f9fafb');
    final colorYellow50 = PdfColor.fromHex('#fefce8');

    for (var i = 0; i < totalPages; i++) {
      final isFirstPage = i == 0;
      final isLastPage = i == totalPages - 1;
      final chunk = pages[i];
      final startItemNumber = i == 0 ? 1 : 10 + ((i - 1) * 14) + 1;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(0),
          build: (pw.Context context) {
            return pw.Container(
              color: PdfColors.white,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // 1. Official Header Section
                  pw.Container(
                    padding: const pw.EdgeInsets.only(
                        left: 32, right: 32, top: 64, bottom: 24),
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                          bottom: pw.BorderSide(color: colorGray800, width: 2)),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Top Left: Brand Identity
                        pw.Container(
                          width: PdfPageFormat.a4.width * 0.55,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                shopName ?? 'NEHA AUTO STORES',
                                style: pw.TextStyle(
                                  color: colorNavy,
                                  fontSize: 32,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 12),
                              pw.Text(
                                shopAddress ?? '5, Shri Datta nagar, Opp. Yogeshwari Mahavidyalaya,\nAmbajogai - Dist. Beed 431517',
                                style: pw.TextStyle(
                                  color: colorGray700,
                                  fontSize: 10,
                                  font: fontMedium,
                                  lineSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Top Right: Title & Meta
                        pw.Container(
                          width: PdfPageFormat.a4.width * 0.35,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Container(
                                width: 170,
                                alignment: pw.Alignment.center,
                                decoration: pw.BoxDecoration(
                                  color: colorBlue700,
                                  borderRadius: const pw.BorderRadius.all(
                                      pw.Radius.circular(6)),
                                ),
                                padding: const pw.EdgeInsets.only(
                                    left: 12, right: 10, top: 10, bottom: 10),
                                margin: const pw.EdgeInsets.only(bottom: 24),
                                child: pw.Text(
                                  'MATERIAL REQUEST',
                                  style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontSize: 14,
                                    fontWeight: pw.FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                              _buildMetaRow('Page', '${i + 1} of $totalPages',
                                  colorGray500, colorGray900, colorGray300,
                                  isBottomBorder: true),
                              _buildMetaRow('Date', formattedDate, colorGray500,
                                  colorGray900, colorGray300,
                                  isBottomBorder: true),
                              _buildMetaRow('PO Number', po.poNumber,
                                  colorGray500, colorGray900, colorGray300,
                                  isBottomBorder: false, valueSize: 14),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. Smart Layout Contact Box (Only First Page)
                  if (isFirstPage)
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      child: pw.Container(
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: colorGray300, width: 2),
                          color: colorGray50,
                        ),
                        child: pw.Row(
                          children: [
                            // Left: Request To
                            pw.Container(
                              width: PdfPageFormat.a4.width * 0.55,
                              padding: const pw.EdgeInsets.all(16),
                              decoration: pw.BoxDecoration(
                                border: pw.Border(
                                    right: pw.BorderSide(
                                        color: colorGray300, width: 2)),
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('REQUEST TO (VENDOR)',
                                      style: pw.TextStyle(
                                          fontSize: 9,
                                          color: colorGray500,
                                          fontWeight: pw.FontWeight.bold,
                                          letterSpacing: 1)),
                                  pw.SizedBox(height: 4),
                                  pw.Text(po.supplierName ?? 'UNKNOWN VENDOR',
                                      style: pw.TextStyle(
                                          fontSize: 16,
                                          color: colorGray900,
                                          fontWeight: pw.FontWeight.bold)),
                                ],
                              ),
                            ),
                            // Right: Site Contact
                            pw.Container(
                              width: PdfPageFormat.a4.width * 0.35,
                              padding: const pw.EdgeInsets.all(16),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('SITE CONTACT',
                                      style: pw.TextStyle(
                                          fontSize: 9,
                                          color: colorGray500,
                                          fontWeight: pw.FontWeight.bold,
                                          letterSpacing: 1)),
                                  pw.SizedBox(height: 4),
                                  pw.Text(userName,
                                      style: pw.TextStyle(
                                          fontSize: 16,
                                          color: colorGray900,
                                          fontWeight: pw.FontWeight.bold)),
                                  pw.Text(shopPhone ?? '9822197172',
                                      style: pw.TextStyle(
                                          fontSize: 14,
                                          color: colorGray900,
                                          fontWeight: pw.FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 3. The Table
                  pw.Container(
                    padding: pw.EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: isFirstPage ? 16 : 24,
                        bottom: 0),
                    child: pw.Table(
                      border: pw.TableBorder.all(color: colorGray300, width: 2),
                      columnWidths: {
                        0: const pw.FixedColumnWidth(40),
                        1: const pw.FixedColumnWidth(160),
                        2: const pw.FlexColumnWidth(),
                        3: const pw.FixedColumnWidth(80),
                      },
                      children: [
                        // Header
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: colorBlue700),
                          children: [
                            pw.Padding(
                                padding: const pw.EdgeInsets.all(10),
                                child: pw.Text('#',
                                    textAlign: pw.TextAlign.center,
                                    style: pw.TextStyle(
                                        color: PdfColors.white,
                                        fontSize: 10,
                                        fontWeight: pw.FontWeight.bold,
                                        letterSpacing: 1))),
                            pw.Padding(
                                padding: const pw.EdgeInsets.all(10),
                                child: pw.Text('PART NUMBER',
                                    style: pw.TextStyle(
                                        color: PdfColors.white,
                                        fontSize: 10,
                                        fontWeight: pw.FontWeight.bold,
                                        letterSpacing: 1))),
                            pw.Padding(
                                padding: const pw.EdgeInsets.all(10),
                                child: pw.Text('DESCRIPTION',
                                    style: pw.TextStyle(
                                        color: PdfColors.white,
                                        fontSize: 10,
                                        fontWeight: pw.FontWeight.bold,
                                        letterSpacing: 1))),
                            pw.Padding(
                                padding: const pw.EdgeInsets.all(10),
                                child: pw.Text('QUANTITY',
                                    textAlign: pw.TextAlign.right,
                                    style: pw.TextStyle(
                                        color: PdfColors.white,
                                        fontSize: 10,
                                        fontWeight: pw.FontWeight.bold,
                                        letterSpacing: 1))),
                          ],
                        ),
                        // Items
                        for (var j = 0; j < chunk.length; j++)
                          pw.TableRow(
                            children: [
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(10),
                                  child: pw.Text('${startItemNumber + j}',
                                      textAlign: pw.TextAlign.center,
                                      style: pw.TextStyle(
                                          color: colorGray700,
                                          fontSize: 10,
                                          font: fontMedium))),
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(10),
                                  child: pw.Text(chunk[j].partNumber,
                                      style: pw.TextStyle(
                                          color: colorGray900,
                                          fontSize: 12,
                                          fontWeight: pw.FontWeight.bold))),
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(10),
                                  child: pw.Text(chunk[j].itemName,
                                      style: pw.TextStyle(
                                          color: colorGray800,
                                          fontSize: 10,
                                          font: fontMedium))),
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(10),
                                  child: pw.Text('${chunk[j].orderedQty}',
                                      textAlign: pw.TextAlign.right,
                                      style: pw.TextStyle(
                                          color: colorGray900,
                                          fontSize: 14,
                                          fontWeight: pw.FontWeight.bold))),
                            ],
                          ),
                      ],
                    ),
                  ),

                  pw.Spacer(),

                  // 4. Footer Section
                  if (isLastPage)
                    pw.Container(
                      padding: const pw.EdgeInsets.only(
                          left: 40, right: 40, bottom: 32, top: 16),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          if (notes != null && notes.trim().isNotEmpty)
                            pw.Container(
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(
                                    color: colorGray300, width: 1),
                                color: colorYellow50,
                              ),
                              padding: const pw.EdgeInsets.all(12),
                              margin: const pw.EdgeInsets.only(bottom: 24),
                              child: pw.Text(
                                '"Note: ${notes.trim()}"',
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(
                                  color: colorGray800,
                                  fontSize: 10,
                                  fontStyle: pw.FontStyle.italic,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                          pw.Container(
                            decoration: pw.BoxDecoration(
                                border: pw.Border(
                                    top: pw.BorderSide(
                                        color: colorGray800, width: 2))),
                            padding: const pw.EdgeInsets.only(top: 16),
                            child: pw.Row(
                              mainAxisAlignment:
                                  pw.MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              children: [
                                pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text(
                                      'This is a digitally verified request and does not require a signature.',
                                      style: pw.TextStyle(
                                        color: colorGray600,
                                        fontSize: 9,
                                      ),
                                    ),
                                    pw.SizedBox(height: 6),
                                    pw.Row(
                                      children: [
                                        pw.Text(
                                          'Powered by ',
                                          style: pw.TextStyle(
                                            color: colorGray500,
                                            fontSize: 9,
                                            fontWeight: pw.FontWeight.bold,
                                          ),
                                        ),
                                        pw.Text(
                                          'SnapKhata',
                                          style: pw.TextStyle(
                                            color: colorGray900,
                                            fontSize: 9,
                                            fontWeight: pw.FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                pw.Column(
                                  children: [
                                    pw.SizedBox(height: 32),
                                    pw.Container(
                                      width: 140,
                                      height: 1,
                                      color: colorGray500,
                                    ),
                                    pw.SizedBox(height: 4),
                                    pw.Text(
                                      'User Name',
                                      style: pw.TextStyle(
                                        color: colorGray500,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    pw.Container(
                      padding: const pw.EdgeInsets.only(
                          left: 40, right: 40, bottom: 32, top: 16),
                      child: pw.Center(
                        child: pw.Text(
                          'Continued on next page...',
                          style: pw.TextStyle(
                            color: colorGray400,
                            fontSize: 10,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );
    }

    return await pdf.save();
  }

  static pw.Widget _buildMetaRow(String label, String value,
      PdfColor labelColor, PdfColor valueColor, PdfColor borderColor,
      {required bool isBottomBorder, double valueSize = 12}) {
    return pw.Container(
      width: 170, // Precision tabular width matches the badge width above
      decoration: isBottomBorder
          ? pw.BoxDecoration(
              border: pw.Border(
                  bottom: pw.BorderSide(color: borderColor, width: 1)))
          : null,
      padding: pw.EdgeInsets.only(bottom: 6, top: isBottomBorder ? 0 : 6),
      margin: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(
                color: labelColor,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.2),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
                color: valueColor,
                fontSize: valueSize,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }
}
