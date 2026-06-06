import 'dart:math';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model passed to the generator
// ─────────────────────────────────────────────────────────────────────────────

class InvoiceData {
  final String shopName;
  final String? shopAddress;
  final String? shopPhone;
  final String? shopGst;
  final String customerName;
  final String? customerPhone;
  final String? vehicleNumber;
  final String? odometerReading;
  final String receiptNumber;
  final DateTime date;
  final String status; // 'PAID' | 'UNPAID' | 'PARTIAL'
  final List<InvoiceLineItem> items;
  final double totalAmount;
  final double? receivedAmount;
  final double? balanceDue;
  final String gstMode; // 'none' | 'included' | 'excluded'
  final String industry; // 'automobile' | 'general' etc.
  final String documentType; // 'order' | 'ledger'

  const InvoiceData({
    required this.shopName,
    this.shopAddress,
    this.shopPhone,
    this.shopGst,
    required this.customerName,
    this.customerPhone,
    this.vehicleNumber,
    this.odometerReading,
    required this.receiptNumber,
    required this.date,
    required this.status,
    required this.items,
    required this.totalAmount,
    this.receivedAmount,
    this.balanceDue,
    required this.gstMode,
    required this.industry,
    required this.documentType,
  });
}

class InvoiceLineItem {
  final String name;
  final double qty;
  final double rate;
  final double amount;
  final String type; // 'part' | 'labor' | 'labour' | 'service'

  const InvoiceLineItem({
    required this.name,
    required this.qty,
    required this.rate,
    required this.amount,
    required this.type,
  });

  bool get isLabor {
    final t = type.toLowerCase();
    return t == 'labor' || t == 'labour' || t == 'service';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Generator
// ─────────────────────────────────────────────────────────────────────────────

class InvoicePdfGenerator {
  InvoicePdfGenerator._();

  // ── Font cache (prevents re-downloading large font files every call) ─────
  static pw.Font? _cachedRegular;
  static pw.Font? _cachedBold;
  static pw.Font? _cachedSemiBold;

  static Future<void> _ensureFonts() async {
    // Only download once per app session — NotoSans fonts are 4–10 MB each
    // and loading all three simultaneously on low-memory devices causes OOM.
    _cachedRegular ??= await PdfGoogleFonts.notoSansRegular();
    _cachedBold    ??= await PdfGoogleFonts.notoSansBold();
    _cachedSemiBold ??= await PdfGoogleFonts.notoSansMedium();
  }

  // ── Color palette (Vyapar-inspired, professional) ─────────────────────
  static const _black = PdfColor.fromInt(0xFF000000);
  static const _headerNavy = PdfColor.fromInt(0xFF1a2744);
  static const _headerNavyLight = PdfColor.fromInt(0xFF243460);
  static const _darkSlate = PdfColor.fromInt(0xFF1e293b);
  static const _midSlate = PdfColor.fromInt(0xFF475569);
  static const _lightGray = PdfColor.fromInt(0xFFf1f5f9);
  static const _tableHeaderBg = PdfColor.fromInt(0xFFdde3ed);
  static const _rowAlt = PdfColor.fromInt(0xFFf4f6f8);   // alternating row – visible
  static const _borderGray = PdfColor.fromInt(0xFFb0bec5); // inner dividers
  static const _white = PdfColor.fromInt(0xFFFFFFFF);
  static const _green = PdfColor.fromInt(0xFF16a34a);
  static const _greenBg = PdfColor.fromInt(0xFFdcfce7);
  static const _orange = PdfColor.fromInt(0xFFd97706);
  static const _orangeBg = PdfColor.fromInt(0xFFfef3c7);
  static const _red = PdfColor.fromInt(0xFFb91c1c);
  static const _snapBlue = PdfColor.fromInt(0xFF4F46E5);

  // ── Border helpers ────────────────────────────────────────────────────
  // Outer frame = 1.2 pt solid black  (was 0.5 — that's why it looked faint)
  // Inner dividers = 0.5 pt for a clean hierarchy
  static const _outerBorder = pw.Border.fromBorderSide(
    pw.BorderSide(color: _black, width: 1.2),
  );
  static const _outerBorderBottom = pw.Border(
    bottom: pw.BorderSide(color: _black, width: 1.2),
  );

  // ── Number formatting ─────────────────────────────────────────────────────

  static String _fmtMoney(double v) {
    // Indian locale formatting: 1,00,000.00
    final abs = v.abs();
    final formatted = _formatIndianNumber(abs);
    return '₹ $formatted';
  }

  static String _formatIndianNumber(double v) {
    final str = v.toStringAsFixed(2);
    final parts = str.split('.');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? parts[1] : '00';

    if (intPart.length <= 3) return '$intPart.$decPart';
    final last3 = intPart.substring(intPart.length - 3);
    final rest = intPart.substring(0, intPart.length - 3);
    final buf = StringBuffer();
    var count = 0;
    for (var i = rest.length - 1; i >= 0; i--) {
      if (count > 0 && count % 2 == 0) buf.write(',');
      buf.write(rest[i]);
      count++;
    }
    final reversedRest = buf.toString().split('').reversed.join();
    return '$reversedRest,$last3.$decPart';
  }

  static String _fmtQty(double v) {
    if (v == v.truncateToDouble()) return v.truncate().toString();
    return v.toStringAsFixed(2);
  }

  static String _fmtDate(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day.toString().padLeft(2, '0')}-${months[d.month]}-${d.year}';
  }

  /// Converts a whole-number amount to Indian Rupee words.
  static String _numberToWords(int n) {
    if (n == 0) return 'Zero';
    const ones = [
      '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight',
      'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen',
      'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen',
    ];
    const tens = [
      '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty',
      'Sixty', 'Seventy', 'Eighty', 'Ninety',
    ];

    String below1000(int num) {
      if (num < 20) return ones[num];
      if (num < 100) {
        return tens[num ~/ 10] + (num % 10 != 0 ? ' ${ones[num % 10]}' : '');
      }
      return '${ones[num ~/ 100]} Hundred${num % 100 != 0 ? ' ${below1000(num % 100)}' : ''}';
    }

    final parts = <String>[];
    final crore = n ~/ 10000000; n %= 10000000;
    final lakh = n ~/ 100000; n %= 100000;
    final thousand = n ~/ 1000; n %= 1000;

    if (crore > 0) parts.add('${below1000(crore)} Crore');
    if (lakh > 0) parts.add('${below1000(lakh)} Lakh');
    if (thousand > 0) parts.add('${below1000(thousand)} Thousand');
    if (n > 0) parts.add(below1000(n));
    return parts.join(' ');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Main public API
  // ─────────────────────────────────────────────────────────────────────────

  /// Generates a PDF as [Uint8List]. Call [Printing.sharePdf] to share it.
  static Future<Uint8List> generate(InvoiceData data) async {
    // Load fonts (cached after first call to avoid repeated ~10 MB downloads).
    await _ensureFonts();
    final regularFont = _cachedRegular!;
    final boldFont    = _cachedBold!;
    final semiBoldFont = _cachedSemiBold!;

    final doc = pw.Document(
      title: _docTitle(data),
      author: 'SnapKhata',
      creator: 'SnapKhata',
    );

    final theme = pw.ThemeData.withFont(
      base: regularFont,
      bold: boldFont,
    );

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          theme: theme,
          margin: const pw.EdgeInsets.symmetric(
            horizontal: 14 * PdfPageFormat.mm,
            vertical: 14 * PdfPageFormat.mm,
          ),
        ),
        build: (context) => _buildContent(data, regularFont, boldFont, semiBoldFont),
        footer: (context) => _buildFooter(context, data, regularFont),
      ),
    );

    return doc.save();
  }

  static String _docTitle(InvoiceData data) {
    final isGst = data.gstMode != 'none';
    if (data.documentType == 'ledger') return 'Account Statement - ${data.customerName}';
    return isGst ? 'Tax Invoice #${data.receiptNumber}' : 'Order Details #${data.receiptNumber}';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Content builders
  // ─────────────────────────────────────────────────────────────────────────

  static List<pw.Widget> _buildContent(
    InvoiceData data,
    pw.Font regular,
    pw.Font bold,
    pw.Font semiBold,
  ) {
    final isGst = data.gstMode != 'none';
    final isAutomobile = data.industry == 'automobile';

    // Compute financial figures
    final items = data.items;
    final taxableItems = items.where((i) => !i.isLabor).toList();
    final laborItems = items.where((i) => i.isLabor).toList();

    final partsSubtotal = taxableItems.fold<double>(0, (s, i) => s + i.amount);
    final laborSubtotal = laborItems.fold<double>(0, (s, i) => s + i.amount);
    final subtotal = partsSubtotal + laborSubtotal;

    double gstAmt = 0;
    double grandTotal;
    double taxableValue = subtotal;

    if (isGst) {
      if (data.gstMode == 'included') {
        gstAmt = subtotal * 18 / 118;
        taxableValue = subtotal - gstAmt;
        grandTotal = items.isNotEmpty ? subtotal : data.totalAmount;
      } else {
        gstAmt = subtotal * 0.18;
        taxableValue = subtotal;
        grandTotal = items.isNotEmpty ? (subtotal + gstAmt) : data.totalAmount;
      }
    } else {
      grandTotal = items.isNotEmpty ? subtotal : data.totalAmount;
    }

    final received = data.receivedAmount;
    final balance = received != null
        ? max(0.0, grandTotal - received)
        : (data.balanceDue ?? 0.0);

    final String displayStatus;
    if (received != null) {
      if (received >= grandTotal) {
        displayStatus = 'PAID';
      } else if (received > 0) {
        displayStatus = 'PARTIAL';
      } else {
        displayStatus = 'UNPAID';
      }
    } else {
      displayStatus = data.status;
    }

    final wordsTotal = _numberToWords(grandTotal.round());
    final docTitle = isGst ? 'Tax Invoice' : (data.documentType == 'ledger' ? 'Account Statement' : 'Order Details');

    final isPaid = displayStatus == 'PAID';
    final statusColor = isPaid ? _green : _orange;
    final statusBgColor = isPaid ? _greenBg : _orangeBg;

    return [
      // ── Document title ─────────────────────────────────────────────────
      pw.Center(
        child: pw.Text(
          docTitle,
          style: pw.TextStyle(
            font: bold,
            fontSize: 15,
            color: _headerNavy,
            letterSpacing: 0.3,
          ),
        ),
      ),
      pw.SizedBox(height: 8),

      // ── Main bordered document ──────────────────────────────────────────
      pw.Container(
        decoration: const pw.BoxDecoration(
          border: _outerBorder, // 1.2 pt — crisp outer frame
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Shop header ────────────────────────────────────────────────
            _shopHeader(data, regular, bold, semiBold),

            // ── Bill To / Invoice Details grid ─────────────────────────────
            _metaGrid(data, displayStatus, statusColor, statusBgColor, regular, bold, semiBold),

            // ── Items table ────────────────────────────────────────────────
            _itemsTable(
              data: data,
              items: items,
              taxableItems: taxableItems,
              laborItems: laborItems,
              isGst: isGst,
              isAutomobile: isAutomobile,
              gstAmt: gstAmt,
              grandTotal: grandTotal,
              regular: regular,
              bold: bold,
            ),

            // ── Summary row (totals) ────────────────────────────────────────
            _totalsSection(
              isGst: isGst,
              isAutomobile: isAutomobile,
              partsSubtotal: partsSubtotal,
              laborSubtotal: laborSubtotal,
              subtotal: subtotal,
              gstAmt: gstAmt,
              grandTotal: grandTotal,
              taxableValue: taxableValue,
              received: received,
              balance: balance,
              wordsTotal: wordsTotal,
              regular: regular,
              bold: bold,
              semiBold: semiBold,
              balanceDue: data.balanceDue,
            ),

            // ── Terms ───────────────────────────────────────────────────────
            _termsSection(regular, bold),

            // ── Footer (signatory) ──────────────────────────────────────────
            _signatureSection(data, regular, bold),
          ],
        ),
      ),
    ];
  }

  // ── Shop Header (Vyapar-style colored bar) ───────────────────────────────

  static pw.Widget _shopHeader(
    InvoiceData data,
    pw.Font regular,
    pw.Font bold,
    pw.Font semiBold,
  ) {
    return pw.Container(
      width: double.infinity,
      decoration: const pw.BoxDecoration(
        border: _outerBorderBottom, // crisp 1.2 pt separator
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // ── Colored top bar with shop name ──────────────────────────────
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: _headerNavy,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    data.shopName.toUpperCase(),
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 14,
                      color: _white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                if (data.shopGst != null && data.shopGst!.isNotEmpty)
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: pw.BoxDecoration(
                      color: _headerNavyLight,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                    ),
                    child: pw.Text(
                      'GSTIN: ${data.shopGst}',
                      style: pw.TextStyle(font: semiBold, fontSize: 7.5, color: _white),
                    ),
                  ),
              ],
            ),
          ),
          // ── Sub-header: address + phone ─────────────────────────────────
          if ((data.shopAddress != null && data.shopAddress!.isNotEmpty) ||
              (data.shopPhone != null && data.shopPhone!.isNotEmpty))
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              color: _lightGray,
              child: pw.Row(
                children: [
                  if (data.shopAddress != null && data.shopAddress!.isNotEmpty)
                    pw.Expanded(
                      child: pw.Text(
                        data.shopAddress!,
                        style: pw.TextStyle(font: regular, fontSize: 8, color: _midSlate),
                      ),
                    ),
                  if (data.shopPhone != null && data.shopPhone!.isNotEmpty)
                    pw.Text(
                      'Ph: ${data.shopPhone!.replaceAll('+91', '').trim()}',
                      style: pw.TextStyle(font: regular, fontSize: 8, color: _midSlate),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Bill To / Invoice Details ────────────────────────────────────────────

  static pw.Widget _metaGrid(
    InvoiceData data,
    String displayStatus,
    PdfColor statusColor,
    PdfColor statusBgColor,
    pw.Font regular,
    pw.Font bold,
    pw.Font semiBold,
  ) {
    final isGst = data.gstMode != 'none';

    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: _outerBorderBottom, // 1.2 pt separator
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Bill To
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(9),
              decoration: const pw.BoxDecoration(
                border: pw.Border(right: pw.BorderSide(color: _borderGray, width: 0.5)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    data.documentType == 'ledger' ? 'Customer Details:' : 'Bill To:',
                    style: pw.TextStyle(font: bold, fontSize: 8, color: _darkSlate),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    data.customerName,
                    style: pw.TextStyle(font: bold, fontSize: 10, color: _darkSlate),
                  ),
                  if (data.customerPhone != null && data.customerPhone!.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Contact No: ${data.customerPhone!.replaceAll('+91', '').trim()}',
                      style: pw.TextStyle(font: regular, fontSize: 8, color: _midSlate),
                    ),
                  ],
                  if (data.vehicleNumber != null && data.vehicleNumber!.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Vehicle: ${data.vehicleNumber}',
                      style: pw.TextStyle(font: regular, fontSize: 8, color: _midSlate),
                    ),
                  ],
                  if (data.odometerReading != null && data.odometerReading!.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Odometer: ${data.odometerReading} km',
                      style: pw.TextStyle(font: regular, fontSize: 8, color: _midSlate),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Invoice / Order Details
          pw.SizedBox(
            width: 170,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(9),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    isGst ? 'Invoice Details:' : (data.documentType == 'ledger' ? 'Statement Info:' : 'Order Details:'),
                    style: pw.TextStyle(font: bold, fontSize: 8, color: _darkSlate),
                  ),
                  pw.SizedBox(height: 4),
                  if (data.documentType != 'ledger') ...[
                    pw.Text(
                      'No: ${data.receiptNumber}',
                      style: pw.TextStyle(font: regular, fontSize: 8, color: _midSlate),
                    ),
                    pw.SizedBox(height: 2),
                  ],
                  pw.Text(
                    'Date: ${_fmtDate(data.date)}',
                    style: pw.TextStyle(font: regular, fontSize: 8, color: _midSlate),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: pw.BoxDecoration(
                      color: statusBgColor,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                    ),
                    child: pw.Text(
                      displayStatus,
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 8,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Items Table ──────────────────────────────────────────────────────────

  static pw.Widget _itemsTable({
    required InvoiceData data,
    required List<InvoiceLineItem> items,
    required List<InvoiceLineItem> taxableItems,
    required List<InvoiceLineItem> laborItems,
    required bool isGst,
    required bool isAutomobile,
    required double gstAmt,
    required double grandTotal,
    required pw.Font regular,
    required pw.Font bold,
  }) {
    // Header cells
    final headers = isGst
        ? ['#', 'Item Name', 'Qty', 'Price/Unit (₹)', 'GST (₹)', 'Amount (₹)']
        : ['#', 'Item Name', 'Qty', 'Price/Unit (₹)', 'Amount (₹)'];
    final widths = isGst
        ? [0.05, 0.33, 0.10, 0.17, 0.17, 0.18]
        : [0.05, 0.45, 0.10, 0.20, 0.20];

    pw.Widget cell(String text, {
      bool isHeader = false,
      bool rightAlign = false,
      bool centerAlign = false,
      PdfColor? color,
    }) {
      return pw.Text(
        text,
        textAlign: rightAlign
            ? pw.TextAlign.right
            : (centerAlign ? pw.TextAlign.center : pw.TextAlign.left),
        style: pw.TextStyle(
          font: isHeader ? bold : regular,
          fontSize: isHeader ? 8 : 7.5,
          color: color ?? (isHeader ? _darkSlate : _midSlate),
        ),
      );
    }

    pw.TableRow headerRow() {
      return pw.TableRow(
        decoration: const pw.BoxDecoration(color: _tableHeaderBg),
        children: List.generate(headers.length, (i) {
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: cell(
              headers[i],
              isHeader: true,
              rightAlign: i >= (isGst ? 3 : 3),
              centerAlign: i == 2,
            ),
          );
        }),
      );
    }

    List<pw.TableRow> buildItemRows(List<InvoiceLineItem> rowItems, {bool sectionLabel = false, String? label}) {
      final rows = <pw.TableRow>[];
      if (sectionLabel && label != null) {
        rows.add(pw.TableRow(
          decoration: const pw.BoxDecoration(color: _lightGray),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 8,
                  color: _darkSlate,
                ),
              ),
            ),
            ...List.filled(headers.length - 1, pw.SizedBox()),
          ],
        ));
      }
      for (var i = 0; i < rowItems.length; i++) {
        final item = rowItems[i];
        final srNo = items.indexOf(item) + 1;
        final qty = item.qty;
        final baseAmt = isGst && data.gstMode == 'included'
            ? item.amount * 100 / 118
            : item.amount;
        final baseRate = item.rate > 0
            ? (isGst && data.gstMode == 'included' ? item.rate * 100 / 118 : item.rate)
            : baseAmt / (qty > 0 ? qty : 1);
        final itemGst = item.isLabor ? 0.0 : baseAmt * 0.18;
        final itemTotal = isGst ? (item.isLabor ? baseAmt : baseAmt + itemGst) : item.amount;

        rows.add(pw.TableRow(
          decoration: i.isOdd ? const pw.BoxDecoration(color: _rowAlt) : null,
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: cell('$srNo', centerAlign: true),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: cell(item.name),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: cell(_fmtQty(qty), centerAlign: true),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: cell(_fmtMoney(baseRate), rightAlign: true),
            ),
            if (isGst) pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: cell(
                item.isLabor ? '—' : '${_fmtMoney(itemGst)} (18%)',
                rightAlign: true,
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: cell(_fmtMoney(itemTotal), rightAlign: true),
            ),
          ],
        ));
      }
      return rows;
    }

    // Total row
    final totalQty = items.fold<double>(0, (s, i) => s + i.qty);
    pw.TableRow totalRow() {
      return pw.TableRow(
        decoration: const pw.BoxDecoration(
          color: _lightGray,
          border: pw.Border(
            top: pw.BorderSide(color: _darkSlate, width: 0.8), // strong top line
          ),
        ),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: pw.SizedBox(),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: pw.Text(
              'Total',
              style: pw.TextStyle(font: bold, fontSize: 8.5, color: _darkSlate),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: pw.Text(
              _fmtQty(totalQty),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: bold, fontSize: 8.5, color: _darkSlate),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: pw.SizedBox(),
          ),
          if (isGst) pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: pw.Text(
              _fmtMoney(gstAmt),
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(font: bold, fontSize: 8.5, color: _darkSlate),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: pw.Text(
              _fmtMoney(grandTotal),
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(font: bold, fontSize: 8.5, color: _darkSlate),
            ),
          ),
        ],
      );
    }

    final columnWidths = <int, pw.TableColumnWidth>{};
    for (var i = 0; i < widths.length; i++) {
      columnWidths[i] = pw.FlexColumnWidth(widths[i]);
    }

    final tableRows = <pw.TableRow>[headerRow()];
    if (isAutomobile && (taxableItems.isNotEmpty || laborItems.isNotEmpty)) {
      if (taxableItems.isNotEmpty) {
        tableRows.addAll(buildItemRows(taxableItems, sectionLabel: true, label: 'SPARE PARTS & CONSUMABLES'));
      }
      if (laborItems.isNotEmpty) {
        tableRows.addAll(buildItemRows(laborItems, sectionLabel: true, label: 'LABOUR & SERVICES'));
      }
    } else {
      tableRows.addAll(buildItemRows(items));
    }
    if (items.isNotEmpty) tableRows.add(totalRow());

    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: _outerBorderBottom, // 1.2 pt bottom
      ),
      child: pw.Table(
        columnWidths: columnWidths,
        border: pw.TableBorder(
          horizontalInside: const pw.BorderSide(color: _borderGray, width: 0.4),
          verticalInside: const pw.BorderSide(color: _borderGray, width: 0.4),
        ),
        children: tableRows,
      ),
    );
  }

  // ── Totals / Summary ─────────────────────────────────────────────────────

  static pw.Widget _totalsSection({
    required bool isGst,
    required bool isAutomobile,
    required double partsSubtotal,
    required double laborSubtotal,
    required double subtotal,
    required double gstAmt,
    required double grandTotal,
    required double taxableValue,
    required double? received,
    required double balance,
    required String wordsTotal,
    required pw.Font regular,
    required pw.Font bold,
    required pw.Font semiBold,
    double? balanceDue,
  }) {
    pw.Widget amtRow(String label, String value, {bool isBold = false, PdfColor? valueColor}) {
      return pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                font: isBold ? bold : regular,
                fontSize: 8.5,
                color: _midSlate,
              ),
            ),
          ),
          pw.Text(
            ':',
            style: pw.TextStyle(font: regular, fontSize: 8.5, color: _midSlate),
          ),
          pw.SizedBox(width: 4),
          pw.SizedBox(
            width: 95,
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                font: isBold ? bold : semiBold,
                fontSize: isBold ? 9.5 : 8.5,
                color: valueColor ?? _darkSlate,
              ),
            ),
          ),
        ],
      );
    }

    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: _outerBorderBottom, // 1.2 pt separator
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Left: automobile breakdown or empty
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(9),
              decoration: const pw.BoxDecoration(
                border: pw.Border(right: pw.BorderSide(color: _borderGray, width: 0.5)),
              ),
              child: isAutomobile && (partsSubtotal > 0 || laborSubtotal > 0)
                  ? pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (partsSubtotal > 0) ...[
                          pw.Row(children: [
                            pw.Text('Spare Parts: ', style: pw.TextStyle(font: bold, fontSize: 9, color: _darkSlate)),
                            pw.Text(_fmtMoney(partsSubtotal), style: pw.TextStyle(font: regular, fontSize: 9, color: _midSlate)),
                          ]),
                          pw.SizedBox(height: 3),
                        ],
                        if (laborSubtotal > 0)
                          pw.Row(children: [
                            pw.Text('Servicing: ', style: pw.TextStyle(font: bold, fontSize: 9, color: _darkSlate)),
                            pw.Text(_fmtMoney(laborSubtotal), style: pw.TextStyle(font: regular, fontSize: 9, color: _midSlate)),
                          ]),
                      ],
                    )
                  : pw.SizedBox(),
            ),
          ),
          // Right: totals
          pw.SizedBox(
            width: 205,
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(9),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  amtRow('Sub Total', _fmtMoney(subtotal)),
                  if (isGst) ...[
                    pw.SizedBox(height: 3),
                    amtRow('Total GST (18%)', _fmtMoney(gstAmt)),
                  ],
                  pw.SizedBox(height: 3),
                  amtRow('Total', _fmtMoney(grandTotal), isBold: true),
                  if (received != null && received > 0) ...[
                    pw.SizedBox(height: 3),
                    amtRow('Amount Paid', '-${_fmtMoney(received)}'),
                  ],
                  if (balance > 0) ...[
                    pw.SizedBox(height: 3),
                    amtRow('Balance Due', _fmtMoney(balance), isBold: true, valueColor: _red),
                  ],
                  pw.Divider(color: _darkSlate, height: 10, thickness: 0.5),
                  pw.Text(
                    'Invoice Amount In Words :',
                    style: pw.TextStyle(font: bold, fontSize: 8, color: _darkSlate),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    '$wordsTotal Rupees only',
                    style: pw.TextStyle(font: regular, fontSize: 8, color: _midSlate),
                  ),
                  if (received != null && received > 0) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Received  : ${_fmtMoney(received)}',
                      style: pw.TextStyle(font: regular, fontSize: 8, color: _midSlate),
                    ),
                    pw.Text(
                      'Balance   : ${_fmtMoney(balance)}',
                      style: pw.TextStyle(font: regular, fontSize: 8, color: balance > 0 ? _red : _green),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Terms ────────────────────────────────────────────────────────────────

  static pw.Widget _termsSection(pw.Font regular, pw.Font bold) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: const pw.BoxDecoration(
        border: _outerBorderBottom, // 1.2 pt separator
        color: _lightGray,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Terms And Conditions:',
            style: pw.TextStyle(font: bold, fontSize: 8, color: _darkSlate),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Thank you for doing business with us.',
            style: pw.TextStyle(font: regular, fontSize: 8, color: _midSlate),
          ),
        ],
      ),
    );
  }

  // ── Signature / Footer ───────────────────────────────────────────────────

  static pw.Widget _signatureSection(InvoiceData data, pw.Font regular, pw.Font bold) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: const pw.BoxDecoration(
              border: pw.Border(right: pw.BorderSide(color: _borderGray, width: 0.5)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'This is a computer-generated document.',
                  style: pw.TextStyle(font: regular, fontSize: 7.5, color: _midSlate),
                ),
                pw.SizedBox(height: 3),
                pw.Row(
                  children: [
                    pw.Text(
                      'Powered by ',
                      style: pw.TextStyle(font: regular, fontSize: 7.5, color: _midSlate),
                    ),
                    pw.Text(
                      'SnapKhata',
                      style: pw.TextStyle(font: bold, fontSize: 7.5, color: _snapBlue),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(
          width: 170,
          child: pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(12, 44, 12, 10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Signature line — 1.0 pt so it's clearly visible
                pw.Container(
                  height: 1.0,
                  color: _darkSlate,
                  width: 130,
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'For ${data.shopName.toUpperCase()}',
                  style: pw.TextStyle(font: bold, fontSize: 8, color: _darkSlate),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Authorised Signatory',
                  style: pw.TextStyle(font: regular, fontSize: 7.5, color: _midSlate),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Page footer ──────────────────────────────────────────────────────────

  static pw.Widget _buildFooter(pw.Context context, InvoiceData data, pw.Font regular) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'snapkhata.com',
            style: pw.TextStyle(font: regular, fontSize: 7.5, color: _snapBlue),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(font: regular, fontSize: 7.5, color: _midSlate),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Data builder helper — creates InvoiceData from public API response JSON
  // ─────────────────────────────────────────────────────────────────────────

  /// Builds [InvoiceData] from the `/api/public/receipts/{id}` JSON response.
  static InvoiceData fromApiJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final items = rawItems.map((e) {
      final m = e as Map<String, dynamic>;
      return InvoiceLineItem(
        name: m['name']?.toString() ?? 'Item',
        qty: double.tryParse(m['qty']?.toString() ?? m['quantity']?.toString() ?? '1') ?? 1,
        rate: double.tryParse(m['rate']?.toString() ?? '0') ?? 0,
        amount: double.tryParse(m['amount']?.toString() ?? '0') ?? 0,
        type: m['type']?.toString() ?? 'part',
      );
    }).toList();

    DateTime date = DateTime.now();
    final rawDate = json['created_at']?.toString();
    if (rawDate != null && rawDate.isNotEmpty) {
      date = DateTime.tryParse(rawDate) ?? date;
    }

    return InvoiceData(
      shopName: json['shop_name']?.toString() ?? 'Our Shop',
      shopAddress: json['shop_address']?.toString(),
      shopPhone: json['shop_phone']?.toString(),
      shopGst: json['shop_gst']?.toString(),
      customerName: json['customer_name']?.toString() ?? 'Customer',
      customerPhone: json['customer_phone']?.toString(),
      vehicleNumber: json['vehicle_number']?.toString(),
      odometerReading: json['odometer_reading']?.toString(),
      receiptNumber: json['id']?.toString() ?? '',
      date: date,
      status: json['status']?.toString() ?? 'UNPAID',
      items: items,
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0,
      receivedAmount: json['received_amount'] != null
          ? double.tryParse(json['received_amount'].toString())
          : null,
      balanceDue: json['balance_due'] != null
          ? double.tryParse(json['balance_due'].toString())
          : null,
      gstMode: json['gst_mode']?.toString() ?? 'none',
      industry: json['industry']?.toString() ?? 'general',
      documentType: json['type']?.toString() ?? 'order',
    );
  }

  /// Builds [InvoiceData] from a [LedgerTransaction] + [CustomerLedger] + shop data.
  /// Use this for the Flutter share sheet where the data is already loaded locally.
  static InvoiceData fromLocalTransaction({
    required String shopName,
    String? shopAddress,
    String? shopPhone,
    String? shopGst,
    required String customerName,
    String? customerPhone,
    String? vehicleNumber,
    String? odometerReading,
    required String receiptNumber,
    required DateTime date,
    required double totalAmount,
    double? receivedAmount,
    double? balanceDue,
    required List<Map<String, dynamic>> rawItems,
    String gstMode = 'none',
    String industry = 'general',
    String status = 'UNPAID',
  }) {
    final items = rawItems.map((m) {
      return InvoiceLineItem(
        name: m['name']?.toString() ?? m['item_name']?.toString() ?? 'Item',
        qty: double.tryParse(m['qty']?.toString() ?? m['quantity']?.toString() ?? '1') ?? 1,
        rate: double.tryParse(m['rate']?.toString() ?? '0') ?? 0,
        amount: double.tryParse(m['amount']?.toString() ?? '0') ?? 0,
        type: m['type']?.toString() ?? 'part',
      );
    }).toList();

    return InvoiceData(
      shopName: shopName,
      shopAddress: shopAddress,
      shopPhone: shopPhone,
      shopGst: shopGst,
      customerName: customerName,
      customerPhone: customerPhone,
      vehicleNumber: vehicleNumber,
      odometerReading: odometerReading,
      receiptNumber: receiptNumber,
      date: date,
      status: status,
      items: items,
      totalAmount: totalAmount,
      receivedAmount: receivedAmount,
      balanceDue: balanceDue,
      gstMode: gstMode,
      industry: industry,
      documentType: 'order',
    );
  }
}
