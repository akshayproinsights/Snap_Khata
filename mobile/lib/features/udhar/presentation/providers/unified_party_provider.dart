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
enum HomePartyFilter { all, pending, customers, suppliers, counter }

class HomePartyFilterNotifier extends Notifier<HomePartyFilter> {
  @override
  HomePartyFilter build() => HomePartyFilter.all;

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

  // Add Counter
  if (filter == HomePartyFilter.counter) {
    for (var ledger in udharState.ledgers) {
      if (ledger.customerName == 'Counter') {
        unifiedList.add(UnifiedParty.fromCustomer(ledger));
      }
    }
  }

  // Sort by latest activity (updatedAt) falling back to upload/transaction dates
  unifiedList.sort((a, b) {
    final dateA = a.updatedAt ?? a.latestUploadDate ?? a.lastTransactionDate ?? DateTime(0);
    final dateB = b.updatedAt ?? b.latestUploadDate ?? b.lastTransactionDate ?? DateTime(0);
    return dateB.compareTo(dateA);
  });

  return unifiedList;
});

// ─────────────────────────────────────────────────────────────
// Virtual-scroll windowing — Phase 1 performance fix
// The full unifiedPartiesProvider list stays in memory so that
// autocomplete, search, navigation and mutations are unaffected.
// Only the home screen *renders* a limited slice at a time.
// ─────────────────────────────────────────────────────────────

/// How many party cards are built at a time on the home screen.
const int kPartiesPageSize = 30;

/// Controls how many party cards are currently rendered.
/// Starts at [kPartiesPageSize], grows when the user scrolls to the bottom.
class DisplayedPartiesCountNotifier extends Notifier<int> {
  @override
  int build() => kPartiesPageSize;

  void increment(int by, int max) {
    state = (state + by).clamp(0, max);
  }

  void reset() {
    state = kPartiesPageSize;
  }
}

final displayedPartiesCountProvider = NotifierProvider<DisplayedPartiesCountNotifier, int>(DisplayedPartiesCountNotifier.new);

/// The visible slice of [unifiedPartiesProvider] for home-screen rendering.
/// All parties remain in memory — search, autocomplete and mutations are unaffected.
final displayedUnifiedPartiesProvider = Provider<List<UnifiedParty>>((ref) {
  final all = ref.watch(unifiedPartiesProvider);
  final count = ref.watch(displayedPartiesCountProvider);
  if (count >= all.length) return all;
  return all.sublist(0, count);
});
