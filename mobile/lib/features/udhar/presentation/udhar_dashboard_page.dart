import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/udhar/presentation/unified_ledger_list_page.dart' as mobile;
import 'package:mobile/features/udhar/presentation/providers/udhar_dashboard_provider.dart';
import 'package:mobile/features/udhar/presentation/providers/udhar_search_provider.dart';
import 'package:mobile/features/udhar/presentation/widgets/add_udhar_entry_sheet.dart';

class UdharDashboardPage extends ConsumerWidget {
  const UdharDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(udharDashboardProvider);
    final filterMode = ref.watch(udharFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Parties',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: context.colorScheme.primaryContainer,
              child: const Icon(Icons.person),
            ),
          ),
        ],
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
                    _buildSummaryCard(context, dashboardState.summary?.totalReceivable ?? 0.0,
                        dashboardState.summary?.totalPayable ?? 0.0),
                    
                    const SizedBox(height: 12),
                    
                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Search Party Name...',
                                prefixIcon: Icon(Icons.search, color: context.textSecondaryColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: context.borderColor),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: context.borderColor),
                                ),
                                filled: true,
                                fillColor: context.backgroundColor,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              onChanged: (value) {
                                ref.read(udharSearchQueryProvider.notifier).setQuery(value);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: context.surfaceColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: context.borderColor, width: 0.5),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.filter_list),
                              onPressed: () {
                                // Optional: Add filter bottom sheet logic later
                              },
                              color: context.textSecondaryColor,
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
                            activeColor: context.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            context, 
                            ref, 
                            label: 'Customers', 
                            mode: UdharFilterMode.customers, 
                            currentMode: filterMode,
                            activeColor: context.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            context, 
                            ref, 
                            label: 'Suppliers', 
                            mode: UdharFilterMode.suppliers, 
                            currentMode: filterMode,
                            activeColor: context.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            context, 
                            ref, 
                            label: 'Pending', 
                            mode: UdharFilterMode.pending, 
                            currentMode: filterMode,
                            activeColor: context.warningColor,
                          ),
                        ],
                      ),
                    ),
                    
                    // Unified List View
                    const Expanded(
                      child: mobile.UnifiedLedgerListPage(), // Use prefix mobile to avoid conflict
                    ),
                  ],
                ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: FloatingActionButton(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (context) => const AddUdharEntrySheet(),
            );
          },
          backgroundColor: context.primaryColor,
          foregroundColor: context.colorScheme.onPrimary,
          shape: const CircleBorder(),
          child: const Icon(Icons.add),
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
          color: isSelected ? activeColor.withValues(alpha: 0.1) : context.surfaceColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? activeColor.withValues(alpha: 0.3) : context.borderColor,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? activeColor : context.textSecondaryColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, double receivable, double payable) {
    final Color collectColor = context.successColor;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: context.premiumShadow,
        border: Border.all(color: context.borderColor, width: 0.5),
      ),
      child: Row(
        children: [
          // PAYABLE (TO PAY)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: context.errorColor.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.local_shipping, color: context.errorColor, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'TO PAY',
                      style: TextStyle(
                        color: context.errorColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  CurrencyFormatter.format(payable),
                  style: TextStyle(
                    color: context.errorColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          
          Container(
            width: 1,
            height: 48,
            color: context.borderColor.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 20),
          
          // RECEIVABLE (TO COLLECT)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: collectColor.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person, color: collectColor, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'TO COLLECT',
                      style: TextStyle(
                        color: collectColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  CurrencyFormatter.format(receivable),
                  style: TextStyle(
                    color: collectColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    letterSpacing: -0.5,
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
