import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/udhar/presentation/parties_list_page.dart' as mobile;
import 'package:mobile/features/udhar/presentation/providers/udhar_dashboard_provider.dart';
import 'package:mobile/features/udhar/presentation/providers/udhar_search_provider.dart';
import 'package:mobile/features/udhar/presentation/providers/unified_ledger_provider.dart';
import 'package:mobile/features/udhar/presentation/widgets/add_party_entry_sheet.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/services.dart';

class PartiesDashboardPage extends ConsumerWidget {
  const PartiesDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(udharDashboardProvider);
    final filterMode = ref.watch(udharFilterProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ledgersLoading = ref.watch(unifiedLedgerLoadingProvider);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Parties',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.0,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(LucideIcons.user),
              onPressed: () {},
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
                      Icon(LucideIcons.alertCircle, color: context.errorColor, size: 48),
                      const SizedBox(height: 16),
                      Text(dashboardState.error!, style: TextStyle(color: context.textColor)),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => ref
                            .read(udharDashboardProvider.notifier)
                            .fetchSummary(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : ledgersLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                  children: [
                    // Summary Section
                    _buildSummaryCard(
                      context, 
                      dashboardState.summary?.totalReceivable ?? 0.0,
                      dashboardState.summary?.totalPayable ?? 0.0,
                      isDark,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: context.premiumShadow,
                        ),
                        child: TextField(
                          onChanged: (value) => ref.read(udharSearchQueryProvider.notifier).setQuery(value),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Search Customers, Suppliers...',
                            hintStyle: TextStyle(
                              color: context.textSecondaryColor,
                              fontWeight: FontWeight.w400,
                            ),
                            prefixIcon: Icon(
                              LucideIcons.search, 
                              size: 20, 
                              color: context.textSecondaryColor
                            ),
                            filled: true,
                            fillColor: context.surfaceColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: context.borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: context.borderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: context.primaryColor, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Filter Pills
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'All', 
                            isSelected: filterMode == UdharFilterMode.all,
                            onTap: () => ref.read(udharFilterProvider.notifier).setFilter(UdharFilterMode.all),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Customers', 
                            isSelected: filterMode == UdharFilterMode.customers,
                            onTap: () => ref.read(udharFilterProvider.notifier).setFilter(UdharFilterMode.customers),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Suppliers', 
                            isSelected: filterMode == UdharFilterMode.suppliers,
                            onTap: () => ref.read(udharFilterProvider.notifier).setFilter(UdharFilterMode.suppliers),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Pending', 
                            isSelected: filterMode == UdharFilterMode.pending,
                            activeColor: context.warningColor,
                            onTap: () => ref.read(udharFilterProvider.notifier).setFilter(UdharFilterMode.pending),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Unified List View
                    const Expanded(
                      child: mobile.PartiesListPage(),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const AddPartyEntrySheet(),
          );
        },
        backgroundColor: context.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(LucideIcons.plus),
        label: const Text('Add Party', style: TextStyle(fontWeight: FontWeight.w700)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, double receivable, double payable, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: context.premiumShadow,
        border: Border.all(color: context.borderColor, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // PAYABLE
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.errorColor.withValues(alpha: isDark ? 0.05 : 0.02),
                        context.surfaceColor,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(LucideIcons.arrowUpRight, color: context.errorColor, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'TO PAY',
                            style: TextStyle(
                              color: context.errorColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          CurrencyFormatter.format(payable),
                          style: TextStyle(
                            color: context.errorColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: context.borderColor.withValues(alpha: 0.5),
                indent: 20,
                endIndent: 20,
              ),
              
              // RECEIVABLE
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.successColor.withValues(alpha: isDark ? 0.05 : 0.02),
                        context.surfaceColor,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(LucideIcons.arrowDownLeft, color: context.successColor, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'TO COLLECT',
                            style: TextStyle(
                              color: context.successColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          CurrencyFormatter.format(receivable),
                          style: TextStyle(
                            color: context.successColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? activeColor;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = activeColor ?? context.primaryColor;
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? themeColor
              : context.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? themeColor
                : context.borderColor,
            width: 1.5,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: themeColor.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : context.textSecondaryColor,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
