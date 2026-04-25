import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/udhar/domain/models/unified_ledger.dart';
import 'package:mobile/features/udhar/presentation/providers/udhar_provider.dart';
import 'package:mobile/features/inventory/presentation/providers/vendor_ledger_provider.dart';
import 'package:mobile/features/udhar/presentation/providers/udhar_search_provider.dart';

final unifiedLedgerProvider = Provider<List<UnifiedLedger>>((ref) {
  final udharState = ref.watch(udharProvider);
  final vendorState = ref.watch(vendorLedgerProvider);
  final filterMode = ref.watch(udharFilterProvider);
  final searchQuery = ref.watch(udharSearchQueryProvider).toLowerCase();

  List<UnifiedLedger> unifiedList = [];

  // Add Customers
  if (filterMode == UdharFilterMode.all || filterMode == UdharFilterMode.pending || filterMode == UdharFilterMode.customers) {
    for (var ledger in udharState.ledgers) {
      if (filterMode == UdharFilterMode.pending && ledger.balanceDue == 0) continue;
      
      if (searchQuery.isNotEmpty && !ledger.customerName.toLowerCase().contains(searchQuery)) continue;

      unifiedList.add(
        UnifiedLedger(
          id: ledger.id,
          name: ledger.customerName,
          phone: ledger.customerPhone,
          balanceDue: ledger.balanceDue,
          lastActivityDate: ledger.lastPaymentDate,
          type: LedgerType.customer,
          originalLedger: ledger,
        ),
      );
    }
  }

  // Add Suppliers
  if (filterMode == UdharFilterMode.all || filterMode == UdharFilterMode.pending || filterMode == UdharFilterMode.suppliers) {
    for (var ledger in vendorState.ledgers) {
      if (filterMode == UdharFilterMode.pending && ledger.balanceDue == 0) continue;
      
      if (searchQuery.isNotEmpty && !ledger.vendorName.toLowerCase().contains(searchQuery)) continue;

      unifiedList.add(
        UnifiedLedger(
          id: ledger.id,
          name: ledger.vendorName,
          phone: null,
          balanceDue: ledger.balanceDue,
          lastActivityDate: ledger.lastPaymentDate,
          type: LedgerType.supplier,
          originalLedger: ledger,
        ),
      );
    }
  }

  // Filter out zero balances if pending is selected
  // Note: the new UI filter uses unified pills. Let's see if we need a custom UdharFilterMode
  
  // Sort by recent activity
  unifiedList.sort((a, b) {
    if (a.lastActivityDate == null && b.lastActivityDate == null) return 0;
    if (a.lastActivityDate == null) return 1;
    if (b.lastActivityDate == null) return -1;
    return b.lastActivityDate!.compareTo(a.lastActivityDate!);
  });

  return unifiedList;
});
