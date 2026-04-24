import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/activities/presentation/providers/activity_provider.dart';
import 'package:mobile/features/activities/presentation/widgets/customer_activity_card.dart';
import 'package:mobile/features/activities/presentation/widgets/vendor_activity_card.dart';
import 'package:mobile/features/activities/domain/models/activity_item.dart';
import 'package:mobile/features/dashboard/presentation/widgets/bill_type_selection_sheet.dart';
import 'package:mobile/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

class HomeDashboardPage extends ConsumerWidget {
  const HomeDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredActivitiesAsync = ref.watch(filteredActivitiesProvider);
    final currentFilter = ref.watch(activeFilterProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: const Text(
          'SNAPKHATA',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
            color: AppTheme.primary,
          ),
        ),
        actions: [
          _buildReviewButton(context, ref, currentFilter),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.refresh(recentActivitiesProvider.future),
              ref.refresh(dashboardTotalsProvider.future),
            ]);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Header & Summary Cards ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildGreeting(),
                      const SizedBox(height: 24),
                      _buildSummaryCards(ref, isDark),
                      const SizedBox(height: 28),
                      _buildSearchBar(ref, isDark),
                      const SizedBox(height: 16),
                      _buildFilterChips(ref, currentFilter, isDark),
                      const SizedBox(height: 24),
                      Text(
                        currentFilter == ActivityFilter.all 
                            ? 'RECENT ACTIVITY' 
                            : currentFilter == ActivityFilter.customers 
                                ? 'RECENT SALES' 
                                : 'RECENT PURCHASES',
                        style: TextStyle(
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // ── Activity List ──
              filteredActivitiesAsync.when(
                loading: () => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stack) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.alertCircle, color: AppTheme.error, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load activities',
                            style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 8),
                          Text(error.toString(), textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary)),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => ref.read(recentActivitiesProvider.notifier).refreshData(),
                            child: const Text('RETRY'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                data: (activities) {
                  if (activities.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                LucideIcons.scan,
                                size: 48,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'No transactions yet',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start by scanning your first bill.',
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = activities[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: item.map(
                              customer: (c) => CustomerActivityCard(item: c),
                              vendor: (v) => VendorActivityCard(item: v),
                            ),
                          );
                        },
                        childCount: activities.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildScanBillFab(context),
      bottomNavigationBar: _buildBottomNav(context, ref, isDark),
    );
  }

  Widget _buildBottomNav(BuildContext context, WidgetRef ref, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.border,
            width: 1,
          ),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: 0, // Home is active
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/');
              break;
            case 1:
              context.go('/udhar-dashboard');
              break;
            case 2:
              context.go('/bills');
              break;
            case 3:
              context.go('/settings');
              break;
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.home),
            label: 'HOME',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.users),
            label: 'PARTIES',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.fileText),
            label: 'BILLS',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.settings),
            label: 'SETTINGS',
          ),
        ],
      ),
    );
  }

  Widget _buildGreeting() {
    final hour = DateTime.now().hour;
    String greeting = 'GOOD MORNING';
    if (hour >= 12 && hour < 17) greeting = 'GOOD AFTERNOON';
    if (hour >= 17) greeting = 'GOOD EVENING';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: const TextStyle(
            color: AppTheme.primary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Welcome back, Merchant',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.0,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(WidgetRef ref, bool isDark) {
    final totalsAsync = ref.watch(dashboardTotalsProvider);

    return totalsAsync.when(
      data: (totals) => Row(
        children: [
          Expanded(
            child: _SummaryCard(
              label: 'YOU WILL GET',
              amount: CurrencyFormatter.format(totals.totalReceivable),
              color: AppTheme.success,
              icon: LucideIcons.arrowUpRight,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryCard(
              label: 'YOU WILL GIVE',
              amount: CurrencyFormatter.format(totals.totalPayable),
              color: AppTheme.error,
              icon: LucideIcons.arrowDownLeft,
              isDark: isDark,
            ),
          ),
        ],
      ),
      loading: () => Row(
        children: [
          Expanded(
            child: _SummaryCard(
              label: 'YOU WILL GET',
              amount: '...',
              isLoading: true,
              color: AppTheme.success,
              icon: LucideIcons.arrowUpRight,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryCard(
              label: 'YOU WILL GIVE',
              amount: '...',
              isLoading: true,
              color: AppTheme.error,
              icon: LucideIcons.arrowDownLeft,
              isDark: isDark,
            ),
          ),
        ],
      ),
      error: (error, stack) => Row(
        children: [
          Expanded(
            child: _SummaryCard(
              label: 'ERROR',
              amount: '₹ 0',
              color: AppTheme.error,
              icon: LucideIcons.alertCircle,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryCard(
              label: 'ERROR',
              amount: '₹ 0',
              color: AppTheme.error,
              icon: LucideIcons.alertCircle,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(WidgetRef ref, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? [] : AppTheme.premiumShadow,
      ),
      child: TextField(
        onChanged: (value) => ref.read(activitiesSearchQueryProvider.notifier).updateQuery(value),
        style: const TextStyle(fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'Search orders, names...',
          hintStyle: TextStyle(
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            LucideIcons.search, 
            size: 20, 
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary
          ),
          filled: true,
          fillColor: isDark ? AppTheme.darkSurface : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: isDark ? const BorderSide(color: AppTheme.darkBorder) : BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: isDark ? const BorderSide(color: AppTheme.darkBorder) : BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppTheme.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildFilterChips(WidgetRef ref, ActivityFilter currentFilter, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            isSelected: currentFilter == ActivityFilter.all,
            onTap: () => ref.read(activeFilterProvider.notifier).setFilter(ActivityFilter.all),
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Customers',
            isSelected: currentFilter == ActivityFilter.customers,
            onTap: () => ref.read(activeFilterProvider.notifier).setFilter(ActivityFilter.customers),
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Suppliers',
            isSelected: currentFilter == ActivityFilter.suppliers,
            onTap: () => ref.read(activeFilterProvider.notifier).setFilter(ActivityFilter.suppliers),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildScanBillFab(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const BillTypeSelectionSheet(),
          );
        },
        borderRadius: BorderRadius.circular(28),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.scan, color: Colors.white, size: 22),
            SizedBox(width: 12),
            Text(
              'SCAN BILL',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewButton(BuildContext context, WidgetRef ref, ActivityFilter filter) {
    final supplierPending = ref.watch(pendingSupplierReviewsProvider);
    final customerPending = ref.watch(pendingCustomerReviewsProvider);
    
    int count = 0;
    if (filter == ActivityFilter.suppliers) {
      count = supplierPending;
    } else if (filter == ActivityFilter.customers) {
      count = customerPending;
    } else {
      count = supplierPending + customerPending;
    }

    return IconButton(
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : count.toString()),
        backgroundColor: AppTheme.error,
        child: const Icon(LucideIcons.clipboardCheck),
      ),
      onPressed: () {
        HapticFeedback.lightImpact();
        if (filter == ActivityFilter.suppliers) {
          context.push('/inventory-review');
        } else if (filter == ActivityFilter.customers) {
          context.push('/review');
        } else {
          _showReviewSelectionDialog(context);
        }
      },
      tooltip: 'Review pending invoices',
    );
  }

  void _showReviewSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Review Invoices', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('Which invoices would you like to review?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/inventory-review');
            },
            child: const Text('PURCHASES', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w900)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/review');
            },
            child: const Text('SALES', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}


class _SummaryCard extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;
  final IconData icon;
  final bool isDark;
  final bool isLoading;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    required this.isDark,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.border,
          width: 1.5,
        ),
        boxShadow: isDark ? [] : AppTheme.premiumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: TextStyle(
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          if (isLoading)
            SizedBox(
              height: 26,
              child: Center(
                child: LinearProgressIndicator(
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.1),
                ),
              ),
            )
          else
            Text(
              amount,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary
              : (isDark ? AppTheme.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : (isDark ? AppTheme.darkBorder : AppTheme.border),
            width: 1.5,
          ),
          boxShadow: isSelected && !isDark
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
