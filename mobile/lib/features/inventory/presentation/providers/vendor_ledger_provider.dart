import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:dio/dio.dart';
import '../../domain/models/vendor_ledger_models.dart';

class VendorLedgerState {
  final bool isLoading;
  final List<VendorLedger> ledgers;
  final String? error;

  VendorLedgerState({
    this.isLoading = false,
    this.ledgers = const [],
    this.error,
  });

  VendorLedgerState copyWith({
    bool? isLoading,
    List<VendorLedger>? ledgers,
    String? error,
    bool clearError = false,
  }) {
    return VendorLedgerState(
      isLoading: isLoading ?? this.isLoading,
      ledgers: ledgers ?? this.ledgers,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class VendorLedgerNotifier extends Notifier<VendorLedgerState> {
  late final Dio _dio;

  @override
  VendorLedgerState build() {
    _dio = ApiClient().dio;
    Future.microtask(() => fetchLedgers());
    return VendorLedgerState();
  }

  Future<void> fetchLedgers() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _dio.get('/api/vendor-ledgers/vendor-ledgers');
      final data = response.data['data'] as List?;
      if (data != null) {
        final ledgers = data.map((e) => VendorLedger.fromJson(e)).toList();
        state = state.copyWith(isLoading: false, ledgers: ledgers);
      } else {
        state = state.copyWith(
            isLoading: false, error: 'Failed to parse vendor ledgers');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<List<VendorLedgerTransaction>> fetchTransactions(int ledgerId) async {
    try {
      final response = await _dio.get('/api/vendor-ledgers/vendor-ledgers/$ledgerId/transactions');
      final data = response.data['data'] as List?;
      if (data != null) {
        return data.map((e) => VendorLedgerTransaction.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> recordPayment(int ledgerId, double amount, String notes, {String? vendorName}) async {
    try {
      int effectiveLedgerId = ledgerId;

      if (effectiveLedgerId == -1 && vendorName != null && vendorName.isNotEmpty) {
        final createResponse = await _dio.post('/api/vendor-ledgers/vendor-ledgers', data: {
          'vendor_name': vendorName,
        });
        final data = createResponse.data['data'];
        if (data != null && data['id'] != null) {
          effectiveLedgerId = data['id'];
        } else {
          return false;
        }
      }

      if (effectiveLedgerId == -1) {
        return false;
      }

      await _dio.post('/api/vendor-ledgers/vendor-ledgers/$effectiveLedgerId/pay', data: {
        'amount': amount,
        'notes': notes,
      });
      // Refresh list after successful payment
      await fetchLedgers();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> toggleTransactionPaidStatus(int transactionId, bool markAsPaid) async {
    try {
      await _dio.post('/api/vendor-ledgers/vendor-ledgers/transactions/$transactionId/toggle-paid', data: {
        'is_paid': markAsPaid,
      });
      // Refresh list after successful toggle
      await fetchLedgers();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteTransaction(int transactionId) async {
    try {
      await _dio.delete('/api/vendor-ledgers/vendor-ledgers/transactions/$transactionId');
      await fetchLedgers();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> batchTogglePaidStatus(List<int> transactionIds, bool markAsPaid) async {
    try {
      await _dio.post('/api/vendor-ledgers/vendor-ledgers/transactions/batch-toggle-paid', data: {
        'transaction_ids': transactionIds,
        'is_paid': markAsPaid,
      });
      await fetchLedgers();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> batchDeleteTransactions(List<int> transactionIds) async {
    try {
      await _dio.post('/api/vendor-ledgers/vendor-ledgers/transactions/batch-delete', data: {
        'transaction_ids': transactionIds,
      });
      await fetchLedgers();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> markInvoiceAsPaid({
    required String vendorName,
    required String invoiceNumber,
    required double amount,
    String? date,
  }) async {
    try {
      await _dio.post('/api/vendor-ledgers/vendor-ledgers/onboard-invoice-paid', data: {
        'vendor_name': vendorName,
        'invoice_number': invoiceNumber,
        'amount': amount,
        'date': date,
      });
      await fetchLedgers();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>> fetchInvoiceItems(String invoiceNumber) async {
    try {
      final response = await _dio.get('/api/inventory/items', queryParameters: {
        'invoice_number': invoiceNumber,
        'show_all': true,
      });
      return response.data['items'] ?? [];
    } catch (e) {
      return [];
    }
  }

  /// Fetches the receipt_link (original photo URL) for a given invoice number.
  Future<String?> fetchReceiptLink(String invoiceNumber) async {
    try {
      final response = await _dio.get('/api/inventory/items', queryParameters: {
        'invoice_number': invoiceNumber,
        'show_all': true,
      });
      final items = response.data['items'] as List?;
      if (items != null && items.isNotEmpty) {
        final link = items.first['receipt_link'] as String?;
        if (link != null && link.isNotEmpty && link != 'null') return link;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> deleteLedger(int ledgerId) async {
    try {
      await _dio.delete('/api/vendor-ledgers/vendor-ledgers/$ledgerId');
      await fetchLedgers();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Fetches all inventory items (purchase invoices) for a specific vendor.
  /// This combines with ledger transactions to show complete vendor history.
  Future<List<Map<String, dynamic>>> fetchInventoryItemsByVendor(String vendorName) async {
    try {
      final response = await _dio.get('/api/inventory/items', queryParameters: {
        'show_all': true,
      });
      final items = response.data['items'] as List? ?? [];
      
      // Filter items by vendor name (case-insensitive match)
      final vendorItems = items.where((item) {
        final itemVendor = item['vendor_name']?.toString().toLowerCase() ?? '';
        final searchVendor = vendorName.toLowerCase();
        return itemVendor == searchVendor || itemVendor.contains(searchVendor);
      }).toList();
      
      // Group by invoice number to create invoice-level summary
      final Map<String, Map<String, dynamic>> invoiceGroups = {};
      for (final item in vendorItems) {
        final invoiceNum = item['invoice_number']?.toString() ?? '';
        final invoiceDate = item['invoice_date']?.toString() ?? '';
        final key = invoiceNum.isNotEmpty ? invoiceNum : '${invoiceDate}_${item['id']}';
        
        if (!invoiceGroups.containsKey(key)) {
          invoiceGroups[key] = {
            'invoice_number': invoiceNum,
            'invoice_date': invoiceDate,
            'vendor_name': item['vendor_name'],
            'receipt_link': item['receipt_link'],
            'upload_date': item['upload_date'],
            'total_amount': 0.0,
            'item_count': 0,
            'items': <Map<String, dynamic>>[],
          };
        }
        
        final netBill = double.tryParse(item['net_bill']?.toString() ?? '0') ?? 0.0;
        invoiceGroups[key]!['total_amount'] = (invoiceGroups[key]!['total_amount'] as double) + netBill;
        invoiceGroups[key]!['item_count'] = (invoiceGroups[key]!['item_count'] as int) + 1;
        (invoiceGroups[key]!['items'] as List<Map<String, dynamic>>).add(item as Map<String, dynamic>);
      }
      
      // Convert to list and sort by date (newest first)
      final invoices = invoiceGroups.values.toList();
      invoices.sort((a, b) {
        final dateA = DateTime.tryParse(a['invoice_date']?.toString() ?? '') ?? DateTime(0);
        final dateB = DateTime.tryParse(b['invoice_date']?.toString() ?? '') ?? DateTime(0);
        return dateB.compareTo(dateA);
      });
      
      return invoices;
    } catch (e) {
      return [];
    }
  }
}

final vendorLedgerProvider =
    NotifierProvider<VendorLedgerNotifier, VendorLedgerState>(VendorLedgerNotifier.new);
