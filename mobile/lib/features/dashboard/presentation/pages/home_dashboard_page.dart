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
import 'package:visibility_detector/visibility_detector.dart';

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
        toolbarHeight: 0,
      ),
      body: VisibilityDetector(
        key: const Key('home_dashboard_visibility'),
        onVisibilityChanged: (info) {
          if (info.visibleFraction > 0.1) {
            // Silently refresh dashboard totals and recent activity in background
            ref.read(dashboardTotalsProvider.notifier).refreshSilent();
            ref.read(recentActivitiesProvider.notifier).refreshSilent();
          }
        },
        child: SafeArea(
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
                // ── Header with Greeting & Actions ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderRow(context, ref, currentFilter),
                        const SizedBox(height: 20),
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
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildScanBillFab(context),
    );
  }

  Widget _buildHeaderRow(BuildContext context, WidgetRef ref, ActivityFilter currentFilter) {
    final authState = ref.watch(authProvider);
    final username = authState.user?.username ?? 'Merchant';
    final supplierPending = ref.watch(pendingSupplierReviewsProvider);
    final customerPending = ref.watch(pendingCustomerReviewsProvider);

    final hour = DateTime.now().hour;
    String greeting = 'GOOD MORNING';
    if (hour >= 12 && hour < 17) greeting = 'GOOD AFTERNOON';
    if (hour >= 17) greeting = 'GOOD EVENING';

    int pendingCount = 0;
    if (currentFilter == ActivityFilter.suppliers) {
      pendingCount = supplierPending;
    } else if (currentFilter == ActivityFilter.customers) {
      pendingCount = customerPending;
    } else {
      pendingCount = supplierPending + customerPending;
    }

    return Row(
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/settings?shop=details');
          },
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: context.primaryColor.withValues(alpha: 0.2), width: 2),
            ),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: context.isDark ? context.borderColor : const Color(0xFF2B3A4A),
              child: const Icon(LucideIcons.user, color: Colors.white, size: 20),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/settings?shop=details');
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting.toUpperCase(),
                  style: TextStyle(
                    color: context.textSecondaryColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  username,
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: context.surfaceColor,
            shape: BoxShape.circle,
            boxShadow: context.premiumShadow,
            border: Border.all(color: context.borderColor, width: 1),
          ),
          child: IconButton(
            icon: Badge(
              isLabelVisible: pendingCount > 0,
              label: Text(pendingCount > 99 ? '99+' : pendingCount.toString()),
              backgroundColor: context.errorColor,
              child: const Icon(LucideIcons.bell, size: 20),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              if (currentFilter == ActivityFilter.suppliers) {
                context.push('/inventory-review');
              } else if (currentFilter == ActivityFilter.customers) {
                context.push('/review');
              } else {
                _showReviewSelectionDialog(context);
              }
            },
            color: context.textColor,
            tooltip: 'Review pending invoices',
          ),
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
            child: GestureDetector(
              onTap: () => ref.read(dashboardTotalsProvider.notifier).refresh(),
              child: _SummaryCard(
                label: 'YOU WILL GET',
                amount: 'Tap to retry',
                color: context.errorColor,
                isDark: isDark,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => ref.read(dashboardTotalsProvider.notifier).refresh(),
              child: _SummaryCard(
                label: 'YOU WILL GIVE',
                amount: 'Tap to retry',
                color: context.errorColor,
                isDark: isDark,
              ),
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
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            isSelected: currentFilter == ActivityFilter.all,
            onTap: () => ref.read(activeFilterProvider.notifier).setFilter(ActivityFilter.all),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Customers',
            isSelected: currentFilter == ActivityFilter.customers,
            onTap: () => ref.read(activeFilterProvider.notifier).setFilter(ActivityFilter.customers),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Suppliers',
            isSelected: currentFilter == ActivityFilter.suppliers,
            onTap: () => ref.read(activeFilterProvider.notifier).setFilter(ActivityFilter.suppliers),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: context.premiumShadow,
        border: Border.all(
          color: context.borderColor,
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: Icon(
              label.contains('GET') ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight,
              color: color.withValues(alpha: 0.05),
              size: 64,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: context.textSecondaryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (isLoading)
                SizedBox(
                  height: 32,
                  child: Center(
                    child: LinearProgressIndicator(
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                )
              else
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    amount,
                    style: TextStyle(
                      color: color,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.0,
                    ),
                  ),
                ),
            ],
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

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
              ? context.primaryColor
              : context.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? context.primaryColor
                : context.borderColor,
            width: 1.5,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: context.primaryColor.withValues(alpha: 0.2),
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
