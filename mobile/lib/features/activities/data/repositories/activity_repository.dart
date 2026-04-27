import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/activities/domain/models/activity_item.dart';

class ActivityRepository {
  final Dio _dio;

  ActivityRepository() : _dio = ApiClient().dio;

  /// Fetches unified activities from both customer and vendor backend endpoints.
  ///
  /// Uses the authenticated backend API so results are automatically scoped
  /// to the currently logged-in merchant (by JWT / username). This prevents
  /// cross-user data leakage that would occur with un-filtered Supabase queries.
  ///
  /// Uses [Future.wait] for concurrent fetching and merges/sorts results in-memory.
  Future<List<ActivityItem>> fetchRecentActivities({int limit = 100}) async {
    try {
      final results = await Future.wait([
        _fetchCustomerTransactions(limit),
        _fetchVendorTransactions(limit),
      ]);

      final customerActivities = results[0];
      final vendorActivities = results[1];

      // Merge and sort descending by date
      final allActivities = [...customerActivities, ...vendorActivities];
      allActivities.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

      // Apply final limit and return
      return allActivities.take(limit).toList();
    } catch (e) {
      throw Exception('ActivityRepository Error: $e');
    }
  }

  /// Calls GET /api/udhar/transactions/all — JWT-authenticated, user-scoped.
  /// Response shape: { status: "success", data: [ { id, transaction_type,
  ///   amount, receipt_number, created_at, customer_ledgers: { customer_name, balance_due } } ] }
  Future<List<ActivityItem>> _fetchCustomerTransactions(int limit) async {
    final response = await _dio.get(
      '/api/udhar/transactions/all',
      queryParameters: {'limit': limit},
    );

    final data = (response.data['data'] as List?) ?? [];
    return data.map((json) {
      final ledger = json['customer_ledgers'] as Map<String, dynamic>?;
      return ActivityItem.customer(
        id: json['id'].toString(),
        entityName: ledger?['customer_name']
            ?? json['_enriched_customer_name']
            ?? 'Unknown Customer',
        transactionDate: DateTime.parse(json['created_at']),
        amount: (json['amount'] as num).toDouble(),
        displayId: json['receipt_number']?.toString(),
        transactionType: json['transaction_type'] ?? 'INVOICE',
        balanceDue: (ledger?['balance_due'] as num?)?.toDouble() ?? 0.0,
        // Navigation context from verified_invoices enrichment
        receiptLink: json['receipt_link'] as String? ?? '',
        invoiceDate: json['invoice_date'] as String? ?? '',
        mobileNumber: json['mobile_number'] as String? ?? '',
        paymentMode: json['payment_mode'] as String? ?? 'Cash',
        invoiceBalanceDue: (json['invoice_balance_due'] as num?)?.toDouble() ?? 0.0,
        receivedAmount: (json['received_amount'] as num?)?.toDouble() ?? 0.0,
        items: (json['items'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [],
        isVerified: json['is_verified'] as bool? ?? true,
      );
    }).toList();
  }

  /// Calls GET /api/vendor-ledgers/transactions/all — JWT-authenticated, user-scoped.
  /// Response shape: { status: "success", data: [ { id, transaction_type,
  ///   amount, invoice_number, is_paid, created_at, vendor_ledgers: { vendor_name, balance_due } } ] }
  Future<List<ActivityItem>> _fetchVendorTransactions(int limit) async {
    final response = await _dio.get(
      '/api/vendor-ledgers/transactions/all',
      queryParameters: {'limit': limit},
    );

    final data = (response.data['data'] as List?) ?? [];
    return data.map((json) {
      final ledger = json['vendor_ledgers'] as Map<String, dynamic>?;
      final rawItems = json['inventory_items'];
      final List<Map<String, dynamic>> items = rawItems is List
          ? rawItems.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : [];
      return ActivityItem.vendor(
        id: json['id'].toString(),
        entityName: ledger?['vendor_name']
            ?? json['vendor_name_enriched']
            ?? 'Unknown Vendor',
        transactionDate: DateTime.parse(json['created_at']),
        amount: (json['amount'] as num).toDouble(),
        displayId: json['invoice_number']?.toString(),
        isPaid: json['is_paid'] ?? false,
        balanceDue: (ledger?['balance_due'] as num?)?.toDouble() ?? 0.0,
        totalPriceHike: (json['total_price_hike'] as num?)?.toDouble() ?? 0.0,
        // Navigation context from inventory_items enrichment
        receiptLink: json['receipt_link'] as String? ?? '',
        invoiceDate: json['invoice_date'] as String? ?? '',
        inventoryItems: items,
        isVerified: json['is_verified'] as bool? ?? false,
        balanceOwed: (json['balance_owed'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();
  }
}
