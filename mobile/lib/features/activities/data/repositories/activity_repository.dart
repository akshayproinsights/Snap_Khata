import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/features/activities/domain/models/activity_item.dart';

class ActivityRepository {
  final SupabaseClient _supabase;

  ActivityRepository(this._supabase);

  /// Fetches unified activities from both customer and vendor tables.
  /// 
  /// Uses [Future.wait] for concurrent fetching and merges/sorts results in-memory.
  Future<List<ActivityItem>> fetchRecentActivities({int limit = 50}) async {
    try {
      // 1. Fetch concurrently from both transaction flows
      final results = await Future.wait([
        _fetchCustomerTransactions(limit),
        _fetchVendorTransactions(limit),
      ]);

      final customerActivities = results[0];
      final vendorActivities = results[1];

      // 2. Merge and Sort descending by date
      final allActivities = [...customerActivities, ...vendorActivities];
      allActivities.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

      // 3. Apply final limit and return
      return allActivities.take(limit).toList();
    } catch (e) {
      // Production-ready error handling - rethrow with context or handle as per app policy
      throw Exception('ActivityRepository Error: $e');
    }
  }

  Future<List<ActivityItem>> _fetchCustomerTransactions(int limit) async {
    final response = await _supabase
        .from('ledger_transactions')
        .select('*, customer_ledgers(customer_name, balance_due)')
        .order('created_at', ascending: false)
        .limit(limit);

    final data = response as List<dynamic>;
    return data.map((json) {
      final ledger = json['customer_ledgers'] as Map<String, dynamic>?;
      return ActivityItem.customer(
        id: json['id'].toString(),
        entityName: ledger?['customer_name'] ?? 'Unknown Customer',
        transactionDate: DateTime.parse(json['created_at']),
        amount: (json['amount'] as num).toDouble(),
        displayId: json['receipt_number']?.toString(),
        transactionType: json['transaction_type'] ?? 'INVOICE',
        balanceDue: (ledger?['balance_due'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();
  }

  Future<List<ActivityItem>> _fetchVendorTransactions(int limit) async {
    final response = await _supabase
        .from('vendor_ledger_transactions')
        .select('*, vendor_ledgers(vendor_name, balance_due)')
        .order('created_at', ascending: false)
        .limit(limit);

    final data = response as List<dynamic>;
    return data.map((json) {
      final ledger = json['vendor_ledgers'] as Map<String, dynamic>?;
      return ActivityItem.vendor(
        id: json['id'].toString(),
        entityName: ledger?['vendor_name'] ?? 'Unknown Vendor',
        transactionDate: DateTime.parse(json['created_at']),
        amount: (json['amount'] as num).toDouble(),
        displayId: json['invoice_number']?.toString(),
        isPaid: json['is_paid'] ?? false,
        balanceDue: (ledger?['balance_due'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();
  }
}
