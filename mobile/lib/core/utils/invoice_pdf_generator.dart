import 'dart:math';
import 'dart:typed_data';
import 'package:dio/dio.dart';
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
  final String documentType; // 'order' | 'ledger' | 'bill'
  final String? customTerms; // optional custom terms text
  final String? shopLogoUrl; // optional logo rendered in the PDF header

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
    this.customTerms,
    this.shopLogoUrl,
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
  // Devanagari fallback fonts (Marathi / Hindi support)
  static pw.Font? _cachedDevanagariRegular;
  static pw.Font? _cachedDevanagariBold;
  static pw.Font? _cachedDevanagariMedium;

  static Future<void> _ensureFonts() async {
    // Primary: NotoSans (Latin, numbers, ₹ symbol)
    _cachedRegular  ??= await PdfGoogleFonts.notoSansRegular();
    _cachedBold     ??= await PdfGoogleFonts.notoSansBold();
    _cachedSemiBold ??= await PdfGoogleFonts.notoSansMedium();
    // Fallback: NotoSansDevanagari (Marathi, Hindi — Devanagari script)
    _cachedDevanagariRegular ??= await PdfGoogleFonts.notoSansDevanagariRegular();
    _cachedDevanagariBold    ??= await PdfGoogleFonts.notoSansDevanagariBold();
    _cachedDevanagariMedium  ??= await PdfGoogleFonts.notoSansDevanagariMedium();
  }

  // ── Color palette ─────────────────────────────────────────────────────
  static const _black        = PdfColor.fromInt(0xFF000000);
  static const _headerNavy  = PdfColor.fromInt(0xFF1a2744);
  static const _headerNavyLight = PdfColor.fromInt(0xFF243460);
  static const _darkSlate   = PdfColor.fromInt(0xFF1e293b);
  static const _midSlate    = PdfColor.fromInt(0xFF475569);
  static const _lightGray   = PdfColor.fromInt(0xFFf1f5f9);
  static const _tableHeaderBg = PdfColor.fromInt(0xFFdde3ed);
  static const _rowAlt      = PdfColor.fromInt(0xFFf4f6f8);

  static const _white       = PdfColor.fromInt(0xFFFFFFFF);
  static const _green       = PdfColor.fromInt(0xFF16a34a);
  static const _greenBg     = PdfColor.fromInt(0xFFdcfce7);
  static const _orange      = PdfColor.fromInt(0xFFd97706);
  static const _orangeBg    = PdfColor.fromInt(0xFFfef3c7);
  static const _red         = PdfColor.fromInt(0xFFb91c1c);
  static const _snapBlue    = PdfColor.fromInt(0xFF4F46E5);

  // ── Number formatting ─────────────────────────────────────────────────────

  static String _fmtMoney(double v) {
    final abs = v.abs();
    return '₹ ${_formatIndianNumber(abs)}';
  }

  static String _formatIndianNumber(double v) {
    // Show decimals only when there are actual paise (non-zero cents)
    final isWholeNumber = v == v.truncateToDouble();
    final str = isWholeNumber ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
    if (isWholeNumber) {
      // Format whole number with Indian grouping: e.g. 42450 → 42,450
      if (str.length <= 3) return str;
      final last3 = str.substring(str.length - 3);
      final rest = str.substring(0, str.length - 3);
      final buf = StringBuffer();
      var count = 0;
      for (var i = rest.length - 1; i >= 0; i--) {
        if (count > 0 && count % 2 == 0) buf.write(',');
        buf.write(rest[i]);
        count++;
      }
      final reversedRest = buf.toString().split('').reversed.join();
      return '$reversedRest,$last3';
    }
    // Has paise — show with 2 decimal places
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

  // ── Logo image cache (avoids re-downloading within a session) ───────────
  static final Map<String, Uint8List> _logoCache = {};

  /// Downloads [url] and returns the raw bytes, or null on any error.
  static Future<Uint8List?> _fetchLogoBytes(String url) async {
    if (url.isEmpty) return null;
    if (_logoCache.containsKey(url)) return _logoCache[url];
    try {
      final dio = Dio();
      final response = await dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      if (response.statusCode == 200 && response.data != null && response.data!.isNotEmpty) {
        final bytes = Uint8List.fromList(response.data!);
        _logoCache[url] = bytes;
        return bytes;
      }
    } catch (_) {
      // Network error or timeout — logo will be skipped
    }
    return null;
  }

  static Future<Uint8List> generate(InvoiceData data) async {
    await _ensureFonts();
    final regular   = _cachedRegular!;
    final bold      = _cachedBold!;
    final semiBold  = _cachedSemiBold!;

    final doc = pw.Document(
      title: _docTitle(data),
      author: 'SnapKhata',
      creator: 'SnapKhata',
    );

    final theme = pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      // Allow Devanagari glyphs (Marathi/Hindi) to render correctly in all text
      fontFallback: [_cachedDevanagariRegular!, _cachedDevanagariBold!],
    );

    // ── Ledger totals use authoritative amounts from call-site ────────────
    // Items now include invoice_header + invoice_item rows (same amounts),
    // so we must NOT sum items for ledger — use data.totalAmount instead.
    final items     = data.items;
    final isLedger  = data.documentType == 'ledger';

    final nonLedgerItems = isLedger
        ? items.where((i) {
            final t = i.type.toLowerCase();
            return t != 'invoice_header' && t != 'invoice_item' && t != 'payment';
          }).toList()
        : items;

    final taxableItems = nonLedgerItems.where((i) => !i.isLabor).toList();
    final laborItems   = nonLedgerItems.where((i) => i.isLabor).toList();
    final isGst        = data.gstMode != 'none';
    final isAutomobile = data.industry == 'automobile';

    final partsSubtotal = taxableItems.fold<double>(0, (s, i) => s + i.amount);
    final laborSubtotal = laborItems.fold<double>(0, (s, i) => s + i.amount);
    final subtotal      = partsSubtotal + laborSubtotal;

    double gstAmt = 0;
    double grandTotal;

    if (isLedger) {
      // Ledger: use authoritative totalAmount (= _totalInvoiced from call site)
      grandTotal = data.totalAmount;
    } else if (isGst) {
      if (data.gstMode == 'included') {
        gstAmt     = subtotal * 18 / 118;
        grandTotal = nonLedgerItems.isNotEmpty ? subtotal : data.totalAmount;
      } else {
        gstAmt     = subtotal * 0.18;
        grandTotal = nonLedgerItems.isNotEmpty ? (subtotal + gstAmt) : data.totalAmount;
      }
    } else {
      grandTotal = nonLedgerItems.isNotEmpty ? subtotal : data.totalAmount;
    }

    final received = data.receivedAmount;
    final balance  = received != null
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

    final isPaid        = displayStatus == 'PAID';
    final statusColor   = isPaid ? _green  : _orange;
    final statusBgColor = isPaid ? _greenBg : _orangeBg;
    final wordsTotal    = _numberToWords(grandTotal.round());
    final docTitle      = isGst
        ? 'Tax Invoice'
        : (data.documentType == 'ledger'
            ? 'Account Statement'
            : 'Order Details');

    // ── Column widths for items table ─────────────────────────────────────
    final List<String> headers;
    final List<double> widths;
    if (isLedger) {
      headers = ['#', 'Item Name', 'Qty', 'Price/Unit (₹)', 'Amount (₹)'];
      widths  = [0.05, 0.45, 0.10, 0.20, 0.20];
    } else if (isGst) {
      headers = ['#', 'Item Name', 'Qty', 'Price/Unit (₹)', 'GST (₹)', 'Amount (₹)'];
      widths  = [0.05, 0.33, 0.10, 0.17, 0.17, 0.18];
    } else {
      headers = ['#', 'Item Name', 'Qty', 'Price/Unit (₹)', 'Amount (₹)'];
      widths  = [0.05, 0.45, 0.10, 0.20, 0.20];
    }
    final columnWidths = <int, pw.TableColumnWidth>{};
    for (var i = 0; i < widths.length; i++) {
      columnWidths[i] = pw.FlexColumnWidth(widths[i]);
    }

    // ── Build all table rows (header + items + totals row) ────────────────
    final tableRows = <pw.TableRow>[];

    // Header row
    tableRows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(color: _tableHeaderBg),
      children: List.generate(headers.length, (idx) {
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: pw.Text(
            headers[idx],
            textAlign: idx >= 3
                ? pw.TextAlign.right
                : (idx == 2 ? pw.TextAlign.center : pw.TextAlign.left),
            style: pw.TextStyle(font: bold, fontSize: 8, color: _darkSlate),
          ),
        );
      }),
    ));

    // Item rows helper
    void addItemRows(List<InvoiceLineItem> rowItems, {String? label}) {
      if (label != null) {
        tableRows.add(pw.TableRow(
          decoration: const pw.BoxDecoration(color: _lightGray),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: pw.Text(label, style: pw.TextStyle(font: bold, fontSize: 8, color: _darkSlate)),
            ),
            ...List.filled(headers.length - 1, pw.SizedBox()),
          ],
        ));
      }
      for (var i = 0; i < rowItems.length; i++) {
        final item = rowItems[i];
        final srNo = items.indexOf(item) + 1;

        if (isLedger) {
          // ── Account Statement rows — 5 columns matching standard invoice ──
          // Columns: # | Item Name | Qty | Price/Unit (₹) | Amount (₹)
          final typeStr         = item.type.toLowerCase();
          final isPayment       = typeStr == 'payment';
          final isInvoiceHeader = typeStr == 'invoice_header';
          final isInvoiceItem   = typeStr == 'invoice_item';

          if (isInvoiceHeader) {
            // ── Invoice section header — Invoice #N — DD MMM YYYY ─────────
            tableRows.add(pw.TableRow(
              decoration: const pw.BoxDecoration(
                color: _tableHeaderBg,
                border: pw.Border(top: pw.BorderSide(color: _darkSlate, width: 0.5)),
              ),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  child: pw.SizedBox(),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  child: pw.Text(item.name,
                    style: pw.TextStyle(font: bold, fontSize: 8, color: _darkSlate)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  child: pw.SizedBox(),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  child: pw.SizedBox(),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  child: pw.Text(_fmtMoney(item.amount),
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(font: bold, fontSize: 8, color: _darkSlate)),
                ),
              ],
            ));
          } else if (isInvoiceItem) {
            // ── Invoice line item — Qty + Rate + Amount like standard invoice
            final qty  = item.qty;
            final rate = item.rate > 0 ? item.rate : (qty > 0 ? item.amount / qty : item.amount);
            tableRows.add(pw.TableRow(
              decoration: i.isOdd ? const pw.BoxDecoration(color: _rowAlt) : null,
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: pw.SizedBox(),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(12, 4, 6, 4),
                  child: pw.Text(item.name,
                    style: pw.TextStyle(font: regular, fontSize: 7.5, color: _midSlate)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: pw.Text(_fmtQty(qty),
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: regular, fontSize: 7.5, color: _midSlate)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: pw.Text(_fmtMoney(rate),
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(font: regular, fontSize: 7.5, color: _midSlate)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: pw.Text(_fmtMoney(item.amount),
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(font: regular, fontSize: 7.5, color: _midSlate)),
                ),
              ],
            ));
          } else if (isPayment) {
            // ── Payment received — shown in green with minus sign ─────────
            tableRows.add(pw.TableRow(
              decoration: i.isOdd ? const pw.BoxDecoration(color: _rowAlt) : null,
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: pw.Text('$srNo',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: regular, fontSize: 7.5, color: _midSlate)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: pw.Text(item.name,
                    style: pw.TextStyle(font: regular, fontSize: 7.5, color: _green)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: pw.SizedBox(),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: pw.SizedBox(),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: pw.Text('− ${_fmtMoney(item.amount)}',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(font: bold, fontSize: 7.5, color: _green)),
                ),
              ],
            ));
          } else {
            // ── Fallback: invoice summary row when no items available ──────
            tableRows.add(pw.TableRow(
              decoration: i.isOdd ? const pw.BoxDecoration(color: _rowAlt) : null,
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: pw.Text('$srNo',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: regular, fontSize: 7.5, color: _midSlate)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: pw.Text(item.name,
                    style: pw.TextStyle(font: regular, fontSize: 7.5, color: _darkSlate)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: pw.SizedBox(),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: pw.SizedBox(),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: pw.Text(_fmtMoney(item.amount),
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(font: regular, fontSize: 7.5, color: _darkSlate)),
                ),
              ],
            ));
          }

        } else {
          // ── Standard invoice row ──────────────────────────────────────────
          final qty     = item.qty;
          final baseAmt = isGst && data.gstMode == 'included'
              ? item.amount * 100 / 118
              : item.amount;
          final baseRate = item.rate > 0
              ? (isGst && data.gstMode == 'included' ? item.rate * 100 / 118 : item.rate)
              : baseAmt / (qty > 0 ? qty : 1);
          final itemGst   = item.isLabor ? 0.0 : baseAmt * 0.18;
          final itemTotal = isGst ? (item.isLabor ? baseAmt : baseAmt + itemGst) : item.amount;

          tableRows.add(pw.TableRow(
            decoration: i.isOdd ? const pw.BoxDecoration(color: _rowAlt) : null,
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: pw.Text('$srNo',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: regular, fontSize: 7.5, color: _midSlate)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: pw.Text(item.name,
                  style: pw.TextStyle(font: regular, fontSize: 7.5, color: _midSlate)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: pw.Text(_fmtQty(qty),
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: regular, fontSize: 7.5, color: _midSlate)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: pw.Text(_fmtMoney(baseRate),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(font: regular, fontSize: 7.5, color: _midSlate)),
              ),
              if (isGst)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: pw.Text(
                    item.isLabor ? '—' : '${_fmtMoney(itemGst)} (18%)',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(font: regular, fontSize: 7.5, color: _midSlate)),
                ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: pw.Text(_fmtMoney(itemTotal),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(font: regular, fontSize: 7.5, color: _midSlate)),
              ),
            ],
          ));
        }
      }
    }

    if (isAutomobile && (taxableItems.isNotEmpty || laborItems.isNotEmpty)) {
      if (taxableItems.isNotEmpty) {
        addItemRows(taxableItems, label: 'SPARE PARTS & CONSUMABLES');
      }
      if (laborItems.isNotEmpty) {
        addItemRows(laborItems, label: 'LABOUR & SERVICES');
      }
    } else {
      addItemRows(items);
    }

    // Total / summary row at the bottom of the table
    if (items.isNotEmpty) {
      if (isLedger) {
        // Ledger: show Total Billed | — | Net Balance in a 4-col footer
        // Sum only invoice_header rows — each one holds the full invoice total.
        // invoice_item rows are the individual line items that make up the same
        // total, so including them too would double-count every invoice.
        final totalBilled = items.fold<double>(0, (s, item) =>
            item.type.toLowerCase() == 'invoice_header' ? s + item.amount : s);
        tableRows.add(pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: _lightGray,
          ),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: pw.SizedBox(),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: pw.Text('Total Billed',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(font: bold, fontSize: 8.5, color: _darkSlate)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: pw.SizedBox(),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: pw.SizedBox(),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: pw.Text(_fmtMoney(totalBilled),
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(font: bold, fontSize: 8.5, color: _darkSlate)),
            ),
          ],
        ));
      } else {
        final totalQty = items.fold<double>(0, (s, i) => s + i.qty);
        tableRows.add(pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: _lightGray,
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
                textAlign: pw.TextAlign.right,
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
            if (isGst)
              pw.Padding(
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
        ));
      }
    }


    // ── Assemble all MultiPage widgets ────────────────────────────────────
    // KEY FIX: Each section is a top-level widget in MultiPage.build list.
    // The Table widget is natively pageable — MultiPage will split it across
    // pages automatically without leaving blank space.
    // ── Pre-fetch logo bytes before entering the synchronous build: callback ──
    // pw.MultiPage's build: callback is synchronous — await is not allowed inside it.
    // We resolve the image bytes here (in the async generate() body) then reference
    // the already-fetched Uint8List inside the widget tree.
    final Uint8List? logoBytes = (data.shopLogoUrl != null && data.shopLogoUrl!.isNotEmpty)
        ? await _fetchLogoBytes(data.shopLogoUrl!)
        : null;

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
        footer: (context) => _buildFooter(context, regular),
        build: (context) => [
          // ── Document title ───────────────────────────────────────────
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

          // ── Shop header (TOP section — full 4-side border) ───────────
          pw.Container(
            width: double.infinity,
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                left:   pw.BorderSide(color: _black, width: 1.2),
                right:  pw.BorderSide(color: _black, width: 1.2),
                top:    pw.BorderSide(color: _black, width: 1.2),
                bottom: pw.BorderSide(color: _black, width: 1.2),
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Colored shop name bar
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: _headerNavy,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // ── Logo + shop name ──────────────────────────────────
                      if (logoBytes != null && logoBytes.isNotEmpty)
                        pw.Container(
                          width: 44,
                          height: 44,
                          margin: const pw.EdgeInsets.only(right: 10),
                          decoration: pw.BoxDecoration(
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                            color: _headerNavyLight,
                          ),
                          child: pw.ClipRRect(
                            horizontalRadius: 6,
                            verticalRadius: 6,
                            child: pw.Image(
                              pw.MemoryImage(logoBytes),
                              fit: pw.BoxFit.cover,
                              width: 44,
                              height: 44,
                            ),
                          ),
                        ),
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
                // Address + phone sub-bar
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
          ),

          // ── Bill To / Invoice Details ────────────────────────────────
          // No top border — it's shared with the bottom of the section above
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                left:   pw.BorderSide(color: _black, width: 1.2),
                right:  pw.BorderSide(color: _black, width: 1.2),
                bottom: pw.BorderSide(color: _black, width: 1.2),
              ),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Bill To
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(9),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(right: pw.BorderSide(color: _darkSlate, width: 0.7)),
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
                // Invoice / Order Details (right panel, fixed width)
                pw.SizedBox(
                  width: 170,
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.all(9),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          isGst
                              ? 'Invoice Details:'
                              : (data.documentType == 'ledger'
                                  ? 'Statement Info:'
                                  : 'Order Details:'),
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
                            style: pw.TextStyle(font: bold, fontSize: 8, color: statusColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Items table (natively pageable by MultiPage) ─────────────
          pw.Table(
            columnWidths: columnWidths,
            border: const pw.TableBorder(
              left: pw.BorderSide(color: _black, width: 1.2),
              right: pw.BorderSide(color: _black, width: 1.2),
              bottom: pw.BorderSide(color: _black, width: 1.2),
              horizontalInside: pw.BorderSide(color: _darkSlate, width: 0.7),
              verticalInside: pw.BorderSide(color: _darkSlate, width: 0.7),
            ),
            children: tableRows,
          ),

          // ── Totals section ───────────────────────────────────────────
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                left:   pw.BorderSide(color: _black, width: 1.2),
                right:  pw.BorderSide(color: _black, width: 1.2),
                bottom: pw.BorderSide(color: _black, width: 1.2),
              ),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Left: automobile parts/labour breakdown (or empty spacer)
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(9),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(right: pw.BorderSide(color: _darkSlate, width: 0.7)),
                    ),
                    child: isAutomobile && (partsSubtotal > 0 || laborSubtotal > 0) && !isLedger
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
                // Right: amounts panel
                pw.SizedBox(
                  width: 205,
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.all(9),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (isLedger) ...[
                          // ── Account Statement summary ──────────────────
                          _amtRow('Total Billed', _fmtMoney(grandTotal), isBold: true, regular: regular, semiBold: semiBold, bold: bold),
                          pw.SizedBox(height: 3),
                          _amtRow('Amount Paid', received != null && received > 0 ? '- ${_fmtMoney(received)}' : '₹ 0', valueColor: _green, regular: regular, semiBold: semiBold, bold: bold),
                          pw.SizedBox(height: 3),
                          _amtRow('Net Balance', _fmtMoney(balance), isBold: true, valueColor: balance > 0 ? _red : _green, regular: regular, semiBold: semiBold, bold: bold),
                          pw.Divider(color: _darkSlate, height: 10, thickness: 0.5),
                          pw.Text('Amount In Words:', style: pw.TextStyle(font: bold, fontSize: 8, color: _darkSlate)),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            '${_numberToWords(balance.round())} Rupees ${balance > 0 ? 'Payable' : 'Credit Balance'}',
                            style: pw.TextStyle(font: regular, fontSize: 8, color: _midSlate),
                          ),
                        ] else ...[
                          // ── Standard invoice summary ───────────────────
                          if (isGst) ...[
                            _amtRow('Total GST (18%)', _fmtMoney(gstAmt), regular: regular, semiBold: semiBold, bold: bold),
                            pw.SizedBox(height: 3),
                          ],
                          _amtRow('Total Billed', _fmtMoney(grandTotal), isBold: true, regular: regular, semiBold: semiBold, bold: bold),
                          pw.SizedBox(height: 3),
                          _amtRow('Amount Paid', received != null && received > 0 ? '- ${_fmtMoney(received)}' : '₹ 0', regular: regular, semiBold: semiBold, bold: bold),
                          pw.SizedBox(height: 3),
                          _amtRow('Balance Due', _fmtMoney(balance), isBold: true, valueColor: balance > 0 ? _red : _green, regular: regular, semiBold: semiBold, bold: bold),
                          pw.Divider(color: _darkSlate, height: 10, thickness: 0.5),
                          pw.Text('Amount In Words:', style: pw.TextStyle(font: bold, fontSize: 8, color: _darkSlate)),
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
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Terms & Conditions ───────────────────────────────────────
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                left:   pw.BorderSide(color: _black, width: 1.2),
                right:  pw.BorderSide(color: _black, width: 1.2),
                bottom: pw.BorderSide(color: _black, width: 1.2),
              ),
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
                  (data.customTerms != null && data.customTerms!.trim().isNotEmpty)
                      ? data.customTerms!.trim()
                      : 'Thank you for doing business with us.',
                  style: pw.TextStyle(font: regular, fontSize: 8, color: _midSlate),
                ),
              ],
            ),
          ),

          // ── Signature section ────────────────────────────────────────
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                left:   pw.BorderSide(color: _black, width: 1.2),
                right:  pw.BorderSide(color: _black, width: 1.2),
                bottom: pw.BorderSide(color: _black, width: 1.2),
              ),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(right: pw.BorderSide(color: _darkSlate, width: 0.7)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      mainAxisAlignment: pw.MainAxisAlignment.end,
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
                        pw.Container(height: 1.0, color: _darkSlate, width: 130),
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
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }


  // ── Amount row helper ─────────────────────────────────────────────────────

  static pw.Widget _amtRow(
    String label,
    String value, {
    bool isBold = false,
    PdfColor? valueColor,
    required pw.Font regular,
    required pw.Font semiBold,
    required pw.Font bold,
  }) {
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
        pw.Text(':', style: pw.TextStyle(font: regular, fontSize: 8.5, color: _midSlate)),
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

  // ── Page footer ───────────────────────────────────────────────────────────

  static pw.Widget _buildFooter(pw.Context context, pw.Font regular) {
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
  // Data builder helpers
  // ─────────────────────────────────────────────────────────────────────────

  static String _docTitle(InvoiceData data) {
    final isGst = data.gstMode != 'none';
    if (data.documentType == 'ledger') return 'Account Statement - ${data.customerName}';
    if (data.documentType == 'bill') return 'Order Details #${data.receiptNumber} - ${data.customerName}';
    return isGst ? 'Tax Invoice #${data.receiptNumber}' : 'Order Details #${data.receiptNumber}';
  }

  /// Builds [InvoiceData] from the `/api/public/receipts/{id}` JSON response.
  static InvoiceData fromApiJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final items = rawItems.map((e) {
      final m = e as Map<String, dynamic>;
      return InvoiceLineItem(
        name:   m['name']?.toString() ?? 'Item',
        qty:    double.tryParse(m['qty']?.toString() ?? m['quantity']?.toString() ?? '1') ?? 1,
        rate:   double.tryParse(m['rate']?.toString() ?? '0') ?? 0,
        amount: double.tryParse(m['amount']?.toString() ?? '0') ?? 0,
        type:   m['type']?.toString() ?? 'part',
      );
    }).toList();

    DateTime date = DateTime.now();
    final rawDate = json['created_at']?.toString();
    if (rawDate != null && rawDate.isNotEmpty) {
      date = DateTime.tryParse(rawDate) ?? date;
    }

    return InvoiceData(
      shopName:        json['shop_name']?.toString() ?? 'Our Shop',
      shopAddress:     json['shop_address']?.toString(),
      shopPhone:       json['shop_phone']?.toString(),
      shopGst:         json['shop_gst']?.toString(),
      customerName:    json['customer_name']?.toString() ?? 'Customer',
      customerPhone:   json['customer_phone']?.toString(),
      vehicleNumber:   json['vehicle_number']?.toString(),
      odometerReading: json['odometer_reading']?.toString(),
      receiptNumber:   json['id']?.toString() ?? '',
      date:            date,
      status:          json['status']?.toString() ?? 'UNPAID',
      items:           items,
      totalAmount:     double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0,
      receivedAmount:  json['received_amount'] != null
          ? double.tryParse(json['received_amount'].toString())
          : null,
      balanceDue:      json['balance_due'] != null
          ? double.tryParse(json['balance_due'].toString())
          : null,
      gstMode:         json['gst_mode']?.toString() ?? 'none',
      industry:        json['industry']?.toString() ?? 'general',
      documentType:    json['type']?.toString() ?? 'order',
      customTerms:     json['custom_terms']?.toString(),
    );
  }

  /// Builds [InvoiceData] from local transaction data (Flutter share sheet).
  static InvoiceData fromLocalTransaction({
    required String shopName,
    String? shopAddress,
    String? shopPhone,
    String? shopGst,
    String? shopLogoUrl,
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
    String? customTerms,
    String documentType = 'order',
  }) {
    final items = rawItems.map((m) {
      return InvoiceLineItem(
        name:   m['name']?.toString() ?? m['item_name']?.toString() ?? 'Item',
        qty:    double.tryParse(m['qty']?.toString() ?? m['quantity']?.toString() ?? '1') ?? 1,
        rate:   double.tryParse(m['rate']?.toString() ?? '0') ?? 0,
        amount: double.tryParse(m['amount']?.toString() ?? '0') ?? 0,
        type:   m['type']?.toString() ?? 'part',
      );
    }).toList();

    return InvoiceData(
      shopName:        shopName,
      shopAddress:     shopAddress,
      shopPhone:       shopPhone,
      shopGst:         shopGst,
      shopLogoUrl:     shopLogoUrl,
      customerName:    customerName,
      customerPhone:   customerPhone,
      vehicleNumber:   vehicleNumber,
      odometerReading: odometerReading,
      receiptNumber:   receiptNumber,
      date:            date,
      status:          status,
      items:           items,
      totalAmount:     totalAmount,
      receivedAmount:  receivedAmount,
      balanceDue:      balanceDue,
      gstMode:         gstMode,
      industry:        industry,
      documentType:    documentType,
      customTerms:     customTerms,
    );
  }
}
