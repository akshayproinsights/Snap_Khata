import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/udhar/domain/models/unified_party.dart';
import 'package:mobile/features/udhar/presentation/providers/udhar_provider.dart';
import 'package:mobile/features/inventory/presentation/providers/vendor_ledger_provider.dart';
import 'package:mobile/features/udhar/presentation/providers/udhar_search_provider.dart';

// Track loading state for unified parties
final unifiedPartiesLoadingProvider = Provider<bool>((ref) {
  final udharState = ref.watch(udharProvider);
  final vendorState = ref.watch(vendorLedgerProvider);
  
  return (udharState.isLoading || vendorState.isLoading) && 
         (udharState.ledgers.isEmpty && vendorState.ledgers.isEmpty);
});

// Enum for filtering on Home page
enum HomePartyFilter { all, pending, customers, suppliers }

class HomePartyFilterNotifier extends Notifier<HomePartyFilter> {
  @override
  HomePartyFilter build() => HomePartyFilter.pending;

  void setFilter(HomePartyFilter filter) {
    state = filter;
  }
}

final homePartyFilterProvider = NotifierProvider<HomePartyFilterNotifier, HomePartyFilter>(HomePartyFilterNotifier.new);

final unifiedPartiesProvider = Provider<List<UnifiedParty>>((ref) {
  final udharState = ref.watch(udharProvider);
  final vendorState = ref.watch(vendorLedgerProvider);
  final filter = ref.watch(homePartyFilterProvider);
  final searchQuery = ref.watch(udharSearchQueryProvider).toLowerCase();

  List<UnifiedParty> unifiedList = [];

  // Add Customers
  if (filter == HomePartyFilter.all || filter == HomePartyFilter.customers || filter == HomePartyFilter.pending) {
    for (var ledger in udharState.ledgers) {
      if (searchQuery.isNotEmpty && !ledger.customerName.toLowerCase().contains(searchQuery)) continue;
      
      // Filter for pending: balanceDue > 0
      if (filter == HomePartyFilter.pending && ledger.balanceDue.abs() < 0.01) continue;

      unifiedList.add(UnifiedParty.fromCustomer(ledger));
    }
  }

  // Add Suppliers
  if (filter == HomePartyFilter.all || filter == HomePartyFilter.suppliers || filter == HomePartyFilter.pending) {
    for (var ledger in vendorState.ledgers) {
      if (searchQuery.isNotEmpty && !ledger.vendorName.toLowerCase().contains(searchQuery)) continue;

      // Filter for pending: balanceDue > 0 (vendor balanceDue is positive for what we owe)
      if (filter == HomePartyFilter.pending && ledger.balanceDue.abs() < 0.01) continue;

      unifiedList.add(UnifiedParty.fromVendor(ledger));
    }
  }

  // Sort by latest upload date descending
  unifiedList.sort((a, b) {
    final dateA = a.latestUploadDate ?? a.lastTransactionDate ?? DateTime(0);
    final dateB = b.latestUploadDate ?? b.lastTransactionDate ?? DateTime(0);
    return dateB.compareTo(dateA);
  });

  return unifiedList;
});
