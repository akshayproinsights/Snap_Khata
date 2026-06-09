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

  // ── Account-level totals (optional) ─────────────────────────────────────
  // When set, a "Account Summary" banner is rendered below the invoice totals
  // so the customer can see their full balance across ALL bills at a glance.
  final double? accountTotalBilled;
  final double? accountTotalPaid;
  final double? accountBalanceDue;

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
    this.accountTotalBilled,
    this.accountTotalPaid,
    this.accountBalanceDue,
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
// PDF Builder
// ─────────────────────────────────────────────────────────────────────────────

// Accepts pre-fetched fonts to avoid re-downloading on every call.
Future<Uint8List> _buildPdf(
  InvoiceData data,
  Uint8List? logoBytes, {
  required pw.Font regular,
  required pw.Font bold,
  required pw.Font semiBold,
  required pw.Font devanagariRegular,
  required pw.Font devanagariBold,
}) async {
  // ignore: avoid_print
  print('[PDF-gen] ⏱ _buildPdf() starting...');
  // ignore: avoid_print
  print('[PDF-gen] ⏱ fonts already loaded, building layout...');

  // ── Colour palette ───────────────────────────────────────────────────────
  const black         = PdfColor.fromInt(0xFF000000);
  const headerNavy    = PdfColor.fromInt(0xFF1a2744);
  const darkSlate     = PdfColor.fromInt(0xFF1e293b);
  const midSlate      = PdfColor.fromInt(0xFF475569);
  const lightGray     = PdfColor.fromInt(0xFFf1f5f9);
  const tableHeaderBg = PdfColor.fromInt(0xFFdde3ed);
  const rowAlt        = PdfColor.fromInt(0xFFf4f6f8);
  const white         = PdfColor.fromInt(0xFFFFFFFF);
  const green         = PdfColor.fromInt(0xFF16a34a);
  const greenBg       = PdfColor.fromInt(0xFFdcfce7);
  const orange        = PdfColor.fromInt(0xFFd97706);
  const orangeBg      = PdfColor.fromInt(0xFFfef3c7);
  const red           = PdfColor.fromInt(0xFFb91c1c);
  const snapBlue      = PdfColor.fromInt(0xFF4F46E5);

  // ── Helpers ──────────────────────────────────────────────────────────────
  String fmtIndian(double v) {
    final abs = v.abs();
    final isWhole = abs == abs.truncateToDouble();
    final str = isWhole ? abs.toStringAsFixed(0) : abs.toStringAsFixed(2);
    if (isWhole) {
      if (str.length <= 3) return str;
      final last3 = str.substring(str.length - 3);
      final rest  = str.substring(0, str.length - 3);
      final buf = StringBuffer(); var c = 0;
      for (var i = rest.length - 1; i >= 0; i--) {
        if (c > 0 && c % 2 == 0) buf.write(',');
        buf.write(rest[i]); c++;
      }
      return '${buf.toString().split('').reversed.join()},$last3';
    }
    final parts   = str.split('.');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? parts[1] : '00';
    if (intPart.length <= 3) return '$intPart.$decPart';
    final last3 = intPart.substring(intPart.length - 3);
    final rest  = intPart.substring(0, intPart.length - 3);
    final buf = StringBuffer(); var c = 0;
    for (var i = rest.length - 1; i >= 0; i--) {
      if (c > 0 && c % 2 == 0) buf.write(',');
      buf.write(rest[i]); c++;
    }
    return '${buf.toString().split('').reversed.join()},$last3.$decPart';
  }

  String fmtMoney(double v)  => '₹ ${fmtIndian(v)}';
  String fmtQty(double v)    => v == v.truncateToDouble() ? v.truncate().toString() : v.toStringAsFixed(2);

  String fmtDate(DateTime d) {
    const months = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day.toString().padLeft(2,'0')}-${months[d.month]}-${d.year}';
  }

  String numToWords(int n) {
    if (n == 0) return 'Zero';
    const ones = ['','One','Two','Three','Four','Five','Six','Seven','Eight','Nine','Ten','Eleven','Twelve','Thirteen','Fourteen','Fifteen','Sixteen','Seventeen','Eighteen','Nineteen'];
    const tens = ['','','Twenty','Thirty','Forty','Fifty','Sixty','Seventy','Eighty','Ninety'];
    String below1000(int num) {
      if (num < 20) return ones[num];
      if (num < 100) return tens[num ~/ 10] + (num % 10 != 0 ? ' ${ones[num % 10]}' : '');
      return '${ones[num ~/ 100]} Hundred${num % 100 != 0 ? ' ${below1000(num % 100)}' : ''}';
    }
    final parts = <String>[];
    final crore    = n ~/ 10000000; n %= 10000000;
    final lakh     = n ~/ 100000;   n %= 100000;
    final thousand = n ~/ 1000;     n %= 1000;
    if (crore    > 0) parts.add('${below1000(crore)} Crore');
    if (lakh     > 0) parts.add('${below1000(lakh)} Lakh');
    if (thousand > 0) parts.add('${below1000(thousand)} Thousand');
    if (n        > 0) parts.add(below1000(n));
    return parts.join(' ');
  }

  // Amount row helper
  pw.Widget amtRow(String label, String value, {
    bool isBold = false, PdfColor? valueColor,
  }) {
    return pw.Row(children: [
      pw.Expanded(
        child: pw.Text(label, style: pw.TextStyle(
          font: isBold ? bold : regular, fontSize: 8.5, color: midSlate)),
      ),
      pw.Text(':', style: pw.TextStyle(font: regular, fontSize: 8.5, color: midSlate)),
      pw.SizedBox(width: 4),
      pw.SizedBox(width: 95, child: pw.Text(value,
        textAlign: pw.TextAlign.right,
        style: pw.TextStyle(
          font: isBold ? bold : semiBold,
          fontSize: isBold ? 9.5 : 8.5,
          color: valueColor ?? darkSlate,
        ),
      )),
    ]);
  }

  // ── Calculations ─────────────────────────────────────────────────────────
  final isLedger   = data.documentType == 'ledger';
  final isGst      = data.gstMode != 'none';
  final isAutomobile = data.industry == 'automobile';

  final nonLedgerItems = isLedger
      ? data.items.where((i) {
          final t = i.type.toLowerCase();
          return t != 'invoice_header' && t != 'invoice_item' && t != 'payment';
        }).toList()
      : data.items;

  final taxableItems = nonLedgerItems.where((i) => !i.isLabor).toList();
  final laborItems   = nonLedgerItems.where((i) =>  i.isLabor).toList();

  final partsSubtotal = taxableItems.fold<double>(0, (s, i) => s + i.amount);
  final laborSubtotal = laborItems.fold<double>(0,   (s, i) => s + i.amount);
  final subtotal      = partsSubtotal + laborSubtotal;

  double gstAmt = 0;
  double grandTotal;
  if (isLedger) {
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
  final statusColor   = isPaid ? green  : orange;
  final statusBgColor = isPaid ? greenBg : orangeBg;
  final wordsTotal    = numToWords(grandTotal.round());
  final docTitle      = isGst
      ? 'Tax Invoice'
      : (data.documentType == 'ledger' ? 'Account Statement' : 'Order Details');

  // ── Column widths ────────────────────────────────────────────────────────
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

  // ── Table rows ───────────────────────────────────────────────────────────
  final tableRows = <pw.TableRow>[];

  // Header row
  tableRows.add(pw.TableRow(
    decoration: const pw.BoxDecoration(color: tableHeaderBg),
    children: List.generate(headers.length, (idx) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(headers[idx],
        textAlign: idx >= 3 ? pw.TextAlign.right : (idx == 2 ? pw.TextAlign.center : pw.TextAlign.left),
        style: pw.TextStyle(font: bold, fontSize: 8, color: darkSlate)),
    )),
  ));

  void addItemRows(List<InvoiceLineItem> rowItems, {String? label}) {
    if (label != null) {
      tableRows.add(pw.TableRow(
        decoration: const pw.BoxDecoration(color: lightGray),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: pw.Text(label, style: pw.TextStyle(font: bold, fontSize: 8, color: darkSlate)),
          ),
          ...List.filled(headers.length - 1, pw.SizedBox()),
        ],
      ));
    }
    for (var i = 0; i < rowItems.length; i++) {
      final item = rowItems[i];
      final srNo = data.items.indexOf(item) + 1;

      if (isLedger) {
        final typeStr         = item.type.toLowerCase();
        final isPayment       = typeStr == 'payment';
        final isInvoiceHeader = typeStr == 'invoice_header';
        final isInvoiceItem   = typeStr == 'invoice_item';

        if (isInvoiceHeader) {
          tableRows.add(pw.TableRow(
            decoration: const pw.BoxDecoration(
              color: tableHeaderBg,
              border: pw.Border(top: pw.BorderSide(color: darkSlate, width: 0.5)),
            ),
            children: [
              pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5), child: pw.SizedBox()),
              pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                child: pw.Text(item.name, style: pw.TextStyle(font: bold, fontSize: 8, color: darkSlate))),
              pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5), child: pw.SizedBox()),
              pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5), child: pw.SizedBox()),
              pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                child: pw.Text(fmtMoney(item.amount), textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(font: bold, fontSize: 8, color: darkSlate))),
            ],
          ));
        } else if (isInvoiceItem) {
          final qty  = item.qty;
          final rate = item.rate > 0 ? item.rate : (qty > 0 ? item.amount / qty : item.amount);
          tableRows.add(pw.TableRow(
            decoration: i.isOdd ? const pw.BoxDecoration(color: rowAlt) : null,
            children: [
              pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: pw.SizedBox()),
              pw.Padding(padding: const pw.EdgeInsets.fromLTRB(12, 4, 6, 4),
                child: pw.Text(item.name, style: pw.TextStyle(font: regular, fontSize: 7.5, color: midSlate))),
              pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: pw.Text(fmtQty(qty), textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: regular, fontSize: 7.5, color: midSlate))),
              pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: pw.Text(fmtMoney(rate), textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(font: regular, fontSize: 7.5, color: midSlate))),
              pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: pw.Text(fmtMoney(item.amount), textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(font: regular, fontSize: 7.5, color: midSlate))),
            ],
          ));
        } else if (isPayment) {
          tableRows.add(pw.TableRow(
            decoration: i.isOdd ? const pw.BoxDecoration(color: rowAlt) : null,
            children: [
              pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: pw.Text('$srNo', textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: regular, fontSize: 7.5, color: midSlate))),
              pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: pw.Text(item.name, style: pw.TextStyle(font: regular, fontSize: 7.5, color: green))),
              pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: pw.SizedBox()),
              pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: pw.SizedBox()),
              pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: pw.Text('− ${fmtMoney(item.amount)}', textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(font: bold, fontSize: 7.5, color: green))),
            ],
          ));
        } else {
          tableRows.add(pw.TableRow(
            decoration: i.isOdd ? const pw.BoxDecoration(color: rowAlt) : null,
            children: [
              pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: pw.Text('$srNo', textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: regular, fontSize: 7.5, color: midSlate))),
              pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: pw.Text(item.name, style: pw.TextStyle(font: regular, fontSize: 7.5, color: darkSlate))),
              pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: pw.SizedBox()),
              pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: pw.SizedBox()),
              pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: pw.Text(fmtMoney(item.amount), textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(font: regular, fontSize: 7.5, color: darkSlate))),
            ],
          ));
        }
      } else {
        // Standard invoice row
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
          decoration: i.isOdd ? const pw.BoxDecoration(color: rowAlt) : null,
          children: [
            pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: pw.Text('$srNo', textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: regular, fontSize: 7.5, color: midSlate))),
            pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: pw.Text(item.name, style: pw.TextStyle(font: regular, fontSize: 7.5, color: midSlate))),
            pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: pw.Text(fmtQty(qty), textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: regular, fontSize: 7.5, color: midSlate))),
            pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: pw.Text(fmtMoney(baseRate), textAlign: pw.TextAlign.right,
                style: pw.TextStyle(font: regular, fontSize: 7.5, color: midSlate))),
            if (isGst)
              pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: pw.Text(item.isLabor ? '—' : '${fmtMoney(itemGst)} (18%)',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(font: regular, fontSize: 7.5, color: midSlate))),
            pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: pw.Text(fmtMoney(itemTotal), textAlign: pw.TextAlign.right,
                style: pw.TextStyle(font: regular, fontSize: 7.5, color: midSlate))),
          ],
        ));
      }
    }
  }

  if (isAutomobile && (taxableItems.isNotEmpty || laborItems.isNotEmpty)) {
    if (taxableItems.isNotEmpty) addItemRows(taxableItems);
    if (laborItems.isNotEmpty)   addItemRows(laborItems, label: 'LABOUR & SERVICES');
  } else {
    addItemRows(data.items);
  }

  // Total/summary footer row
  if (data.items.isNotEmpty) {
    if (isLedger) {
      final totalBilled = data.items.fold<double>(0, (s, item) =>
          item.type.toLowerCase() == 'invoice_header' ? s + item.amount : s);
      tableRows.add(pw.TableRow(
        decoration: const pw.BoxDecoration(color: lightGray),
        children: [
          pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5), child: pw.SizedBox()),
          pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: pw.Text('Total Billed', textAlign: pw.TextAlign.right,
              style: pw.TextStyle(font: bold, fontSize: 8.5, color: darkSlate))),
          pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5), child: pw.SizedBox()),
          pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5), child: pw.SizedBox()),
          pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: pw.Text(fmtMoney(totalBilled), textAlign: pw.TextAlign.right,
              style: pw.TextStyle(font: bold, fontSize: 8.5, color: darkSlate))),
        ],
      ));
    } else {
      final totalQty = data.items.fold<double>(0, (s, i) => s + i.qty);
      tableRows.add(pw.TableRow(
        decoration: const pw.BoxDecoration(color: lightGray),
        children: [
          pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5), child: pw.SizedBox()),
          pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: pw.Text('Total', textAlign: pw.TextAlign.right,
              style: pw.TextStyle(font: bold, fontSize: 8.5, color: darkSlate))),
          pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: pw.Text(fmtQty(totalQty), textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: bold, fontSize: 8.5, color: darkSlate))),
          pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5), child: pw.SizedBox()),
          if (isGst)
            pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: pw.Text(fmtMoney(gstAmt), textAlign: pw.TextAlign.right,
                style: pw.TextStyle(font: bold, fontSize: 8.5, color: darkSlate))),
          pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: pw.Text(fmtMoney(grandTotal), textAlign: pw.TextAlign.right,
              style: pw.TextStyle(font: bold, fontSize: 8.5, color: darkSlate))),
        ],
      ));
    }
  }

  // ── Build document ───────────────────────────────────────────────────────
  final String docTitleMeta;
  if (data.documentType == 'ledger') {
    docTitleMeta = 'Account Statement - ${data.customerName}';
  } else if (data.documentType == 'bill') {
    docTitleMeta = 'Order Details #${data.receiptNumber} - ${data.customerName}';
  } else {
    docTitleMeta = isGst ? 'Tax Invoice #${data.receiptNumber}' : 'Order Details #${data.receiptNumber}';
  }

  final doc = pw.Document(title: docTitleMeta, author: 'SnapKhata', creator: 'SnapKhata');

  final theme = pw.ThemeData.withFont(
    base: regular,
    bold: bold,
    fontFallback: [devanagariRegular, devanagariBold],
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
      footer: (context) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('snapkhata.com', style: pw.TextStyle(font: regular, fontSize: 7.5, color: snapBlue)),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(font: regular, fontSize: 7.5, color: midSlate)),
          ],
        ),
      ),
      build: (context) => [
        // ── Document title ───────────────────────────────────────────
        pw.Center(
          child: pw.Text(docTitle, style: pw.TextStyle(
            font: bold, fontSize: 15, color: headerNavy, letterSpacing: 0.3)),
        ),
        pw.SizedBox(height: 8),

        // ── Header + Bill To ─────────────────────────────────────────
        pw.Container(
          width: double.infinity,
          decoration: const pw.BoxDecoration(
            color: white,
            border: pw.Border(
              left: pw.BorderSide(color: black, width: 1.2),
              right: pw.BorderSide(color: black, width: 1.2),
              top: pw.BorderSide(color: black, width: 1.2),
              bottom: pw.BorderSide(color: black, width: 1.2),
            ),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Shop name + logo row
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logoBytes != null && logoBytes.isNotEmpty) ...[
                      pw.Container(
                        width: 44, height: 44,
                        margin: const pw.EdgeInsets.only(right: 10),
                        decoration: pw.BoxDecoration(
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          border: pw.Border.all(color: tableHeaderBg, width: 1),
                        ),
                        child: pw.ClipRRect(
                          horizontalRadius: 4, verticalRadius: 4,
                          child: pw.Image(pw.MemoryImage(logoBytes),
                            fit: pw.BoxFit.cover, width: 44, height: 44),
                        ),
                      ),
                    ],
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(data.shopName.toUpperCase(), style: pw.TextStyle(
                            font: bold, fontSize: 14, color: darkSlate, letterSpacing: 0.6)),
                          if (data.shopAddress != null && data.shopAddress!.isNotEmpty) ...[
                            pw.SizedBox(height: 3),
                            pw.Text(data.shopAddress!, style: pw.TextStyle(font: regular, fontSize: 8, color: midSlate)),
                          ],
                          if (data.shopPhone != null && data.shopPhone!.isNotEmpty) ...[
                            pw.SizedBox(height: 2),
                            pw.Text('Phone: +91 ${data.shopPhone!.replaceAll('+91', '').trim()}',
                              style: pw.TextStyle(font: regular, fontSize: 8, color: midSlate)),
                          ],
                        ],
                      ),
                    ),
                    if (data.shopGst != null && data.shopGst!.isNotEmpty)
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: pw.BoxDecoration(
                          color: tableHeaderBg,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                        ),
                        child: pw.Text('GSTIN: ${data.shopGst}',
                          style: pw.TextStyle(font: semiBold, fontSize: 7.5, color: darkSlate)),
                      ),
                  ],
                ),
              ),
              // Divider
              pw.Container(height: 1.2, color: black),
              // Bill To / Invoice Details row
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(9),
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(right: pw.BorderSide(color: black, width: 1.2)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(data.documentType == 'ledger' ? 'Customer Details:' : 'Bill To:',
                            style: pw.TextStyle(font: bold, fontSize: 8, color: darkSlate)),
                          pw.SizedBox(height: 4),
                          pw.Text(data.customerName,
                            style: pw.TextStyle(font: bold, fontSize: 10, color: darkSlate)),
                          if (data.customerPhone != null && data.customerPhone!.isNotEmpty) ...[
                            pw.SizedBox(height: 2),
                            pw.Text('Contact No: ${data.customerPhone!.replaceAll('+91', '').trim()}',
                              style: pw.TextStyle(font: regular, fontSize: 8, color: midSlate)),
                          ],
                          if (data.vehicleNumber != null && data.vehicleNumber!.isNotEmpty) ...[
                            pw.SizedBox(height: 2),
                            pw.Text('Vehicle: ${data.vehicleNumber}',
                              style: pw.TextStyle(font: regular, fontSize: 8, color: midSlate)),
                          ],
                          if (data.odometerReading != null && data.odometerReading!.isNotEmpty) ...[
                            pw.SizedBox(height: 2),
                            pw.Text('Odometer: ${data.odometerReading} km',
                              style: pw.TextStyle(font: regular, fontSize: 8, color: midSlate)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 206,
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.all(9),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(isGst ? 'Invoice Details:'
                              : (data.documentType == 'ledger' ? 'Statement Info:' : 'Order Details:'),
                            style: pw.TextStyle(font: bold, fontSize: 8, color: darkSlate)),
                          pw.SizedBox(height: 4),
                          if (data.documentType != 'ledger') ...[
                            pw.Text('No: ${data.receiptNumber}',
                              style: pw.TextStyle(font: regular, fontSize: 8, color: midSlate)),
                            pw.SizedBox(height: 2),
                          ],
                          pw.Text('Date: ${fmtDate(data.date)}',
                            style: pw.TextStyle(font: regular, fontSize: 8, color: midSlate)),
                          pw.SizedBox(height: 5),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: pw.BoxDecoration(
                              color: statusBgColor,
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                            ),
                            child: pw.Text(displayStatus,
                              style: pw.TextStyle(font: bold, fontSize: 8, color: statusColor)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Items table (natively pageable by MultiPage) ─────────────
        pw.Table(
          columnWidths: columnWidths,
          border: const pw.TableBorder(
            left: pw.BorderSide(color: black, width: 1.2),
            right: pw.BorderSide(color: black, width: 1.2),
            bottom: pw.BorderSide(color: black, width: 1.2),
            horizontalInside: pw.BorderSide(color: darkSlate, width: 0.7),
            verticalInside: pw.BorderSide(color: darkSlate, width: 0.7),
          ),
          children: tableRows,
        ),

        // ── Totals section ───────────────────────────────────────────
        pw.Container(
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              left: pw.BorderSide(color: black, width: 1.2),
              right: pw.BorderSide(color: black, width: 1.2),
              bottom: pw.BorderSide(color: black, width: 1.2),
            ),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(9),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(right: pw.BorderSide(color: black, width: 1.2)),
                  ),
                  child: isAutomobile && laborSubtotal > 0 && !isLedger
                      ? pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Row(children: [
                              pw.Text('Labour: ', style: pw.TextStyle(font: bold, fontSize: 9, color: darkSlate)),
                              pw.Text(fmtMoney(laborSubtotal), style: pw.TextStyle(font: regular, fontSize: 9, color: midSlate)),
                            ]),
                          ],
                        )
                      : pw.SizedBox(),
                ),
              ),
              pw.SizedBox(
                width: 206,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(9),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (isLedger) ...[
                        amtRow('Total Billed', fmtMoney(grandTotal), isBold: true),
                        pw.SizedBox(height: 3),
                        amtRow('Amount Paid',
                          received != null && received > 0 ? '- ${fmtMoney(received)}' : '₹ 0',
                          valueColor: green),
                        pw.SizedBox(height: 3),
                        amtRow('Net Balance', fmtMoney(balance),
                          isBold: true, valueColor: balance > 0 ? red : green),
                        pw.Divider(color: darkSlate, height: 10, thickness: 0.5),
                        pw.Text('Amount In Words:', style: pw.TextStyle(font: bold, fontSize: 8, color: darkSlate)),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          '${numToWords(balance.round())} Rupees ${balance > 0 ? 'Payable' : 'Credit Balance'}',
                          style: pw.TextStyle(font: regular, fontSize: 8, color: midSlate)),
                      ] else ...[
                        if (isGst) ...[
                          amtRow('Total GST (18%)', fmtMoney(gstAmt)),
                          pw.SizedBox(height: 3),
                        ],
                        amtRow('Total Billed', fmtMoney(grandTotal), isBold: true),
                        pw.SizedBox(height: 3),
                        amtRow('Amount Paid',
                          received != null && received > 0 ? '- ${fmtMoney(received)}' : '₹ 0'),
                        pw.SizedBox(height: 3),
                        amtRow('Balance Due', fmtMoney(balance),
                          isBold: true, valueColor: balance > 0 ? red : green),
                        pw.Divider(color: darkSlate, height: 10, thickness: 0.5),
                        pw.Text('Amount In Words:', style: pw.TextStyle(font: bold, fontSize: 8, color: darkSlate)),
                        pw.SizedBox(height: 2),
                        pw.Text('$wordsTotal Rupees only',
                          style: pw.TextStyle(font: regular, fontSize: 8, color: midSlate)),
                        if (!isLedger && data.accountTotalBilled != null && data.accountBalanceDue != null) ...[
                          pw.Divider(color: darkSlate, height: 10, thickness: 0.5),
                          pw.Text('Account Summary:', style: pw.TextStyle(font: bold, fontSize: 8, color: darkSlate)),
                          pw.SizedBox(height: 3),
                          amtRow('Total Billed', fmtMoney(data.accountTotalBilled!)),
                          pw.SizedBox(height: 3),
                          amtRow('Total Paid', fmtMoney(data.accountTotalPaid ?? 0.0), valueColor: green),
                          pw.SizedBox(height: 3),
                          amtRow('Total Due', fmtMoney(data.accountBalanceDue!),
                            isBold: true,
                            valueColor: data.accountBalanceDue! > 0 ? red : green),
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
              left: pw.BorderSide(color: black, width: 1.2),
              right: pw.BorderSide(color: black, width: 1.2),
              bottom: pw.BorderSide(color: black, width: 1.2),
            ),
            color: lightGray,
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Terms And Conditions:',
                style: pw.TextStyle(font: bold, fontSize: 8, color: darkSlate)),
              pw.SizedBox(height: 2),
              pw.Text(
                (data.customTerms != null && data.customTerms!.trim().isNotEmpty)
                    ? data.customTerms!.trim()
                    : 'Thank you for doing business with us.',
                style: pw.TextStyle(font: regular, fontSize: 8, color: midSlate)),
            ],
          ),
        ),

        // ── Signature section ────────────────────────────────────────
        pw.Container(
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              left: pw.BorderSide(color: black, width: 1.2),
              right: pw.BorderSide(color: black, width: 1.2),
              bottom: pw.BorderSide(color: black, width: 1.2),
            ),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(right: pw.BorderSide(color: black, width: 1.2)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text('This is a computer-generated document.',
                        style: pw.TextStyle(font: regular, fontSize: 7.5, color: midSlate)),
                      pw.SizedBox(height: 3),
                      pw.Row(children: [
                        pw.Text('Powered by ', style: pw.TextStyle(font: regular, fontSize: 7.5, color: midSlate)),
                        pw.Text('SnapKhata', style: pw.TextStyle(font: bold, fontSize: 7.5, color: snapBlue)),
                      ]),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(
                width: 206,
                child: pw.Container(
                  padding: const pw.EdgeInsets.fromLTRB(12, 44, 12, 10),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(height: 1.0, color: darkSlate, width: 150),
                      pw.SizedBox(height: 4),
                      pw.Text('For ${data.shopName.toUpperCase()}',
                        style: pw.TextStyle(font: bold, fontSize: 8, color: darkSlate)),
                      pw.SizedBox(height: 2),
                      pw.Text('Authorised Signatory',
                        style: pw.TextStyle(font: regular, fontSize: 7.5, color: midSlate)),
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

  // ── Heavy operation: encode PDF bytes ──────────────────────────────────
  // On Flutter Web there is only one JS thread. doc.save() is pure CPU work
  // and will block the event loop (freezing the spinner) if called without
  // enableEventLoopBalancing. With it set to true, the pdf library periodically
  // yields control back to the browser during the xref output phase so the UI
  // stays alive. (Dart VM uses a background isolate, so this flag is a no-op there.)
  // ignore: avoid_print
  print('[PDF-gen] ⏱ generating byte stream (event-loop balanced)...');
  final resultBytes = await doc.save(enableEventLoopBalancing: true);

  // ignore: avoid_print
  print('[PDF-gen] ⏱ document saved successfully! Size: ${resultBytes.length} bytes.');

  return resultBytes;
}

// ─────────────────────────────────────────────────────────────────────────────
// Generator
// ─────────────────────────────────────────────────────────────────────────────

class InvoicePdfGenerator {
  InvoicePdfGenerator._();

  // ── Font cache (prevents re-downloading large font files on every call) ──
  static pw.Font? _cachedRegular;
  static pw.Font? _cachedBold;
  static pw.Font? _cachedSemiBold;
  static pw.Font? _cachedDevanagariRegular;
  static pw.Font? _cachedDevanagariBold;

  /// Downloads all fonts from Google Fonts CDN and caches them statically.
  /// Subsequent calls are instant (returns from cache immediately).
  static Future<void> _ensureFonts() async {
    // ignore: avoid_print
    print('[PDF-gen] ⏱ fetching notoSansRegular...');
    _cachedRegular          ??= await PdfGoogleFonts.notoSansRegular();
    // ignore: avoid_print
    print('[PDF-gen] ⏱ fetching notoSansBold...');
    _cachedBold             ??= await PdfGoogleFonts.notoSansBold();
    // ignore: avoid_print
    print('[PDF-gen] ⏱ fetching notoSansMedium...');
    _cachedSemiBold         ??= await PdfGoogleFonts.notoSansMedium();
    // ignore: avoid_print
    print('[PDF-gen] ⏱ fetching notoSansDevanagariRegular...');
    _cachedDevanagariRegular ??= await PdfGoogleFonts.notoSansDevanagariRegular();
    // ignore: avoid_print
    print('[PDF-gen] ⏱ fetching notoSansDevanagariBold...');
    _cachedDevanagariBold   ??= await PdfGoogleFonts.notoSansDevanagariBold();
    // ignore: avoid_print
    print('[PDF-gen] ⏱ fonts fetched successfully.');
  }

  // ── Tracks whether font TTF tables have been parsed (one-time, expensive) ──
  static bool _fontsParsed = false;

  /// Forces all 5 font files to run their TtfParser table-parse eagerly.
  ///
  /// Inside doc.save(), PdfTtfFont calls TtfParser(bytes) which synchronously
  /// parses the full TTF file (_parseCMap + _parseIndexes + _parseGlyphs).
  /// For 5 large NotoSans variants this can block the Flutter Web JS thread
  /// for 3-8 seconds, freezing the UI. Running a tiny 1-word dummy PDF during
  /// preWarm forces this parsing to happen in the background so the real PDF
  /// generates instantly.
  static Future<void> _preParseFonts() async {
    if (_fontsParsed) return;
    _fontsParsed = true;
    // ignore: avoid_print
    print('[PDF-gen] ⏱ pre-parsing TTF tables (background warm-up)...');
    try {
      final dummy = pw.Document();
      final theme = pw.ThemeData.withFont(
        base: _cachedRegular!,
        bold: _cachedBold!,
        fontFallback: [_cachedDevanagariRegular!, _cachedDevanagariBold!],
      );
      // Reference all 5 fonts explicitly so every TtfParser call is forced now.
      dummy.addPage(pw.Page(
        pageTheme: pw.PageTheme(theme: theme),
        build: (ctx) => pw.Column(children: [
          pw.Text('a', style: pw.TextStyle(font: _cachedRegular)),
          pw.Text('b', style: pw.TextStyle(font: _cachedBold)),
          pw.Text('c', style: pw.TextStyle(font: _cachedSemiBold)),
        ]),
      ));
      // This triggers TtfParser for all fonts in the theme — the slow one-time work.
      await dummy.save(enableEventLoopBalancing: true);
      // ignore: avoid_print
      print('[PDF-gen] ⏱ TTF tables pre-parsed — future PDFs will be instant.');
    } catch (e) {
      // Non-fatal: real PDF will still work, just might be slow on first call
      _fontsParsed = false;
      // ignore: avoid_print
      print('[PDF-gen] ⚠ pre-parse warm-up failed: $e');
    }
  }

  /// Call this when the party detail page loads to pre-warm fonts + logo
  /// so that the first PDF generation is instant.
  static void preWarm([String? logoUrl]) {
    // 1. Download fonts eagerly in the background.
    // 2. Once fonts are downloaded, trigger dummy PDF to pre-parse TTF tables.
    //    This moves the expensive TtfParser() work off the download button tap.
    _ensureFonts().then((_) => _preParseFonts().ignore()).ignore();
    // Pre-fetch logo in parallel.
    if (logoUrl != null && logoUrl.isNotEmpty) {
      _fetchLogoBytes(logoUrl).ignore();
    }
  }

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

  // ─────────────────────────────────────────────────────────────────────────
  // Main public API
  // ─────────────────────────────────────────────────────────────────────────

  static Future<Uint8List> generate(InvoiceData data) async {
    // ignore: avoid_print
    print('[PDF-gen] ⏱ generate() called using PdfGoogleFonts');

    // Fetch logo + ensure fonts in parallel for maximum speed.
    // ignore: avoid_print
    print('[PDF-gen] ⏱ fetching shop logo... URL: ${data.shopLogoUrl}');
    final logoFuture = (data.shopLogoUrl != null && data.shopLogoUrl!.isNotEmpty)
        ? _fetchLogoBytes(data.shopLogoUrl!)
        : Future<Uint8List?>.value(null);

    // _ensureFonts() is idempotent — if already cached, returns instantly.
    await Future.wait([logoFuture, _ensureFonts()]);
    final Uint8List? logoBytes = await logoFuture;

    // ignore: avoid_print
    print('[PDF-gen] ⏱ shop logo fetch complete. Invoking _buildPdf()...');
    final pdfBytes = await _buildPdf(
      data,
      logoBytes,
      regular: _cachedRegular!,
      bold: _cachedBold!,
      semiBold: _cachedSemiBold!,
      devanagariRegular: _cachedDevanagariRegular!,
      devanagariBold: _cachedDevanagariBold!,
    );

    // ignore: avoid_print
    print('[PDF-gen] ⏱ generate() finished.');
    return pdfBytes;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Data builder helpers
  // ─────────────────────────────────────────────────────────────────────────

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
    // Account-level totals — shown in the Account Summary banner
    double? accountTotalBilled,
    double? accountTotalPaid,
    double? accountBalanceDue,
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
      shopName:          shopName,
      shopAddress:       shopAddress,
      shopPhone:         shopPhone,
      shopGst:           shopGst,
      shopLogoUrl:       shopLogoUrl,
      customerName:      customerName,
      customerPhone:     customerPhone,
      vehicleNumber:     vehicleNumber,
      odometerReading:   odometerReading,
      receiptNumber:     receiptNumber,
      date:              date,
      status:            status,
      items:             items,
      totalAmount:       totalAmount,
      receivedAmount:    receivedAmount,
      balanceDue:        balanceDue,
      gstMode:           gstMode,
      industry:          industry,
      documentType:      documentType,
      customTerms:       customTerms,
      accountTotalBilled:  accountTotalBilled,
      accountTotalPaid:    accountTotalPaid,
      accountBalanceDue:   accountBalanceDue,
    );
  }
}
