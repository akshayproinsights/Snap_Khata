import "package:mobile/core/theme/context_extension.dart";
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/activities/presentation/providers/activity_provider.dart';
import 'package:mobile/features/activities/presentation/widgets/customer_activity_card.dart';
import 'package:mobile/features/activities/presentation/widgets/vendor_activity_card.dart';
import 'package:mobile/features/activities/domain/models/activity_item.dart';
import 'package:mobile/features/dashboard/presentation/widgets/bill_type_selection_sheet.dart';
import 'package:mobile/features/dashboard/presentation/widgets/review_center_sheet.dart';
import 'package:mobile/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';

class HomeDashboardPage extends ConsumerWidget {
  const HomeDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredActivitiesAsync = ref.watch(filteredActivitiesProvider);
    final currentFilter = ref.watch(activeFilterProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text(
          'SNAPKHATA',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
            color: context.primaryColor,
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
                      _buildGreeting(context, ref),
                      const SizedBox(height: 24),
                      _buildSummaryCards(context, ref, isDark),
                      const SizedBox(height: 28),
                      _buildSearchBar(context, ref, isDark),
                      const SizedBox(height: 16),
                      _buildFilterChips(context, ref, currentFilter, isDark),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            currentFilter == ActivityFilter.all 
                                ? 'RECENT ACTIVITY' 
                                : currentFilter == ActivityFilter.customers 
                                    ? 'RECENT SALES' 
                                    : currentFilter == ActivityFilter.suppliers
                                        ? 'RECENT PURCHASES'
                                        : 'RECENT ITEMS',
                            style: TextStyle(
                              color: context.textColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                          TextButton(
                            onPressed: () {},
                            style: TextButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'View All',
                              style: TextStyle(
                                color: context.primaryColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
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
                          Icon(LucideIcons.alertCircle, color: context.errorColor, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load activities',
                            style: TextStyle(fontWeight: FontWeight.w600, color: context.textColor),
                          ),
                          const SizedBox(height: 8),
                          Text(error.toString(), textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: context.textSecondaryColor)),
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
                                color: context.primaryColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                LucideIcons.scan,
                                size: 48,
                                color: context.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'No transactions yet',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: context.textColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start by scanning your first bill.',
                              style: TextStyle(
                                fontSize: 16,
                                color: context.textSecondaryColor,
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
    );
  }

  Widget _buildGreeting(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final username = authState.user?.username ?? 'Merchant';

    final hour = DateTime.now().hour;
    String greeting = 'GOOD MORNING,';
    if (hour >= 12 && hour < 17) greeting = 'GOOD AFTERNOON,';
    if (hour >= 17) greeting = 'GOOD EVENING,';

    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: context.isDark ? context.borderColor : const Color(0xFF2B3A4A),
          child: const Icon(LucideIcons.user, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              greeting,
              style: TextStyle(
                color: context.textSecondaryColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              username.toUpperCase(),
              style: TextStyle(
                color: context.primaryColor,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCards(BuildContext context, WidgetRef ref, bool isDark) {
    final totalsAsync = ref.watch(dashboardTotalsProvider);

    return totalsAsync.when(
      data: (totals) => Row(
        children: [
          Expanded(
            child: _SummaryCard(
              label: 'YOU WILL GET',
              amount: CurrencyFormatter.format(totals.totalReceivable),
              color: context.successColor,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryCard(
              label: 'YOU WILL GIVE',
              amount: CurrencyFormatter.format(totals.totalPayable),
              color: context.errorColor,
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
              color: context.successColor,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryCard(
              label: 'YOU WILL GIVE',
              amount: '...',
              isLoading: true,
              color: context.errorColor,
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
              color: context.errorColor,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryCard(
              label: 'ERROR',
              amount: '₹ 0',
              color: context.errorColor,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, WidgetRef ref, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: context.premiumShadow,
      ),
      child: TextField(
        onChanged: (value) => ref.read(activitiesSearchQueryProvider.notifier).updateQuery(value),
        style: const TextStyle(fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'Search Customers, vendors...',
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
    );
  }

  Widget _buildFilterChips(BuildContext context, WidgetRef ref, ActivityFilter currentFilter, bool isDark) {
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
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: context.primaryColor,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: context.primaryColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
        borderRadius: BorderRadius.circular(26),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.camera, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Scan Bill',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
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
        backgroundColor: context.errorColor,
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ReviewCenterSheet(),
    );
  }
}


class _SummaryCard extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;
  final bool isDark;
  final bool isLoading;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.isDark,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: context.premiumShadow,
        border: Border.all(
          color: context.borderColor,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.textSecondaryColor,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          if (isLoading)
            SizedBox(
              height: 32,
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
                fontSize: 24,
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
              ? context.primaryColor
              : context.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? context.primaryColor
                : context.borderColor,
            width: 1.5,
          ),
          boxShadow: isSelected ? context.premiumShadow : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : context.textColor,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
