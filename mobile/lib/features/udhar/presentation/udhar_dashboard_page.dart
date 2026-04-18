import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/udhar/presentation/udhar_list_page.dart';
import 'package:mobile/features/inventory/presentation/vendor_ledger/vendor_ledger_list_page.dart';
import 'package:mobile/features/udhar/presentation/providers/udhar_dashboard_provider.dart';
import 'package:mobile/features/udhar/presentation/providers/udhar_search_provider.dart';
import 'package:mobile/features/udhar/presentation/widgets/add_udhar_entry_sheet.dart';

class UdharDashboardPage extends ConsumerWidget {
  const UdharDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(udharDashboardProvider);
    final filterMode = ref.watch(udharFilterProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Credit / Ledger Dashboard'),
        ),
        body: dashboardState.isLoading && dashboardState.summary == null
            ? const Center(child: CircularProgressIndicator())
            : dashboardState.error != null && dashboardState.summary == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(dashboardState.error!),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref
                              .read(udharDashboardProvider.notifier)
                              .fetchSummary(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Net Outstanding Dues Card
                      _buildSummaryCard(dashboardState.summary?.totalReceivable ?? 0.0,
                          dashboardState.summary?.totalPayable ?? 0.0),
                      
                      const SizedBox(height: 12),

                      // Tabs
                      const TabBar(
                        tabs: [
                          Tab(icon: Icon(Icons.person), text: 'Customers'),
                          Tab(icon: Icon(Icons.local_shipping), text: 'Suppliers'),
                        ],
                        labelColor: AppTheme.primary,
                        unselectedLabelColor: AppTheme.textSecondary,
                        indicatorColor: AppTheme.primary,
                      ),
                      
                      // Search Bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Search Party Name...',
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                                ),
                                onChanged: (value) {
                                  ref.read(udharSearchQueryProvider.notifier).setQuery(value);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.filter_list),
                                onPressed: () {
                                  // Optional: Add filter bottom sheet logic later
                                },
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Filter Pills
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Row(
                          children: [
                            _buildFilterChip(
                              context, 
                              ref, 
                              label: 'All', 
                              mode: UdharFilterMode.all, 
                              currentMode: filterMode,
                              activeColor: AppTheme.primary,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              context, 
                              ref, 
                              label: 'Pending', 
                              mode: UdharFilterMode.pending, 
                              currentMode: filterMode,
                              activeColor: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              context, 
                              ref, 
                              label: 'Settled', 
                              mode: UdharFilterMode.settled, 
                              currentMode: filterMode,
                              activeColor: AppTheme.success,
                            ),
                          ],
                        ),
                      ),
                      
                      // Tab Views
                      const Expanded(
                        child: TabBarView(
                          children: [
                            UdharListPage(),
                            VendorLedgerListPage(),
                          ],
                        ),
                      ),
                    ],
                  ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: FloatingActionButton.extended(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (context) => const AddUdharEntrySheet(),
              );
            },
            label: const Text('New Credit Entry'),
            icon: const Icon(Icons.add),
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required UdharFilterMode mode,
    required UdharFilterMode currentMode,
    required Color activeColor,
  }) {
    final isSelected = currentMode == mode;
    return GestureDetector(
      onTap: () {
        ref.read(udharFilterProvider.notifier).setFilter(mode);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? activeColor.withValues(alpha: 0.5) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? activeColor : AppTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(double receivable, double payable) {
    final currencyFormatter =
        NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.person, color: Colors.green, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'YOU WILL GET',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  currencyFormatter.format(receivable),
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: Colors.grey.shade300,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.local_shipping, color: Colors.red, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'YOU WILL GIVE',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  currencyFormatter.format(payable),
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
