import "package:mobile/core/theme/context_extension.dart";
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/udhar/presentation/providers/unified_party_provider.dart';
import 'package:mobile/features/udhar/domain/models/unified_party.dart';
import 'package:mobile/features/udhar/presentation/providers/udhar_provider.dart';
import 'package:mobile/features/inventory/presentation/providers/vendor_ledger_provider.dart';
import 'package:mobile/features/udhar/presentation/providers/udhar_search_provider.dart';
import 'package:mobile/features/udhar/presentation/widgets/swipeable_party_card.dart';
import 'package:mobile/features/dashboard/presentation/widgets/bill_type_selection_sheet.dart';
import 'package:mobile/features/dashboard/presentation/widgets/review_center_sheet.dart';

import 'package:mobile/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:visibility_detector/visibility_detector.dart';

class SelectedPartiesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void toggle(String uniqueId) {
    if (state.contains(uniqueId)) {
      state = {...state}..remove(uniqueId);
    } else {
      state = {...state, uniqueId};
    }
  }

  void clear() {
    state = {};
  }
}

final selectedPartiesProvider =
    NotifierProvider<SelectedPartiesNotifier, Set<String>>(
      SelectedPartiesNotifier.new,
    );

class HomeDashboardPage extends ConsumerWidget {
  const HomeDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parties = ref.watch(unifiedPartiesProvider);
    final isLoading = ref.watch(unifiedPartiesLoadingProvider);
    final currentFilter = ref.watch(homePartyFilterProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedParties = ref.watch(selectedPartiesProvider);
    final isSelectionMode = selectedParties.isNotEmpty;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: isSelectionMode
          ? AppBar(
              backgroundColor: context.surfaceColor,
              leading: IconButton(
                icon: const Icon(LucideIcons.x),
                onPressed: () =>
                    ref.read(selectedPartiesProvider.notifier).clear(),
              ),
              title: Text('${selectedParties.length} Selected'),
              actions: [
                IconButton(
                  icon: Icon(LucideIcons.trash2, color: context.errorColor),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Parties'),
                        content: Text(
                          'Are you sure you want to delete ${selectedParties.length} parties?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(
                              'Delete',
                              style: TextStyle(color: context.errorColor),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      for (final uniqueId in selectedParties) {
                        final party = parties.firstWhere(
                          (p) => p.uniqueId == uniqueId,
                        );
                        if (party.type == PartyType.customer) {
                          await ref
                              .read(udharProvider.notifier)
                              .deleteLedger(party.id);
                        } else {
                          await ref
                              .read(vendorLedgerProvider.notifier)
                              .deleteLedger(party.id);
                        }
                      }
                      ref.read(selectedPartiesProvider.notifier).clear();
                    }
                  },
                ),
              ],
            )
          : AppBar(
              backgroundColor: context.backgroundColor,
              elevation: 0,
              scrolledUnderElevation: 0,
              toolbarHeight: 0,
            ),
      body: VisibilityDetector(
        key: const Key('home_dashboard_visibility'),
        onVisibilityChanged: (info) {
          if (info.visibleFraction > 0.1) {
            // Refresh totals and ledgers in background
            ref.read(dashboardTotalsProvider.notifier).refreshSilent();
            ref.read(udharProvider.notifier).fetchLedgersSilent();
            ref.read(vendorLedgerProvider.notifier).fetchLedgersSilent();
          }
        },
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              // Silent refreshes — list stays visible during pull-to-refresh.
              // No spinner takeover, no blank flash.
              await Future.wait([
                ref.read(udharProvider.notifier).fetchLedgersSilent(),
                ref.read(vendorLedgerProvider.notifier).fetchLedgersSilent(),
                ref.read(dashboardTotalsProvider.notifier).refreshSilent(),
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
                        _buildHeaderRow(context, ref),
                        const SizedBox(height: 24),
                        const SizedBox(height: 24),
                        _buildSummaryCards(context, ref, isDark),
                        const SizedBox(height: 32),
                        _buildSearchBar(context, ref),
                        const SizedBox(height: 16),
                        _buildFilterChips(context, ref, currentFilter),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'PARTIES (KHATA)',
                              style: TextStyle(
                                color: context.textColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                            if (parties.isNotEmpty)
                              Text(
                                '${parties.length} TOTAL',
                                style: TextStyle(
                                  color: context.textSecondaryColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // ── Parties List ──
                // When loading for the FIRST TIME (empty list), show skeleton.
                // When refreshing with existing data, keep the list visible.
                if (isLoading && parties.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => const _PartySkeletonCard(),
                        childCount: 5,
                      ),
                    ),
                  )
                else if (!isLoading && parties.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: context.primaryColor.withValues(
                                alpha: 0.1,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              LucideIcons.users,
                              size: 48,
                              color: context.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No parties found',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: context.textColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add customers or suppliers to track Khata.',
                            style: TextStyle(
                              fontSize: 16,
                              color: context.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final party = parties[index];
                        return SwipeablePartyCard(
                          party: party,
                          isSelected: selectedParties.contains(party.uniqueId),
                          isSelectionMode: isSelectionMode,
                          onTap: () {
                            if (isSelectionMode) {
                              HapticFeedback.selectionClick();
                              ref
                                  .read(selectedPartiesProvider.notifier)
                                  .toggle(party.uniqueId);
                            } else {
                              HapticFeedback.lightImpact();
                              if (party.type == PartyType.customer) {
                                context.pushNamed(
                                  'party-detail',
                                  pathParameters: {'id': party.id.toString()},
                                  extra: party.originalLedger,
                                );
                              } else {
                                context.pushNamed(
                                  'vendor-ledger-detail',
                                  pathParameters: {'id': party.id.toString()},
                                  extra: party.originalLedger,
                                );
                              }
                            }
                          },
                          onLongPress: () {
                            HapticFeedback.heavyImpact();
                            ref
                                .read(selectedPartiesProvider.notifier)
                                .toggle(party.uniqueId);
                          },
                        );
                      }, childCount: parties.length),
                    ),
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

  Widget _buildHeaderRow(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final username = authState.user?.username ?? 'Merchant';
    final supplierPending = ref.watch(pendingSupplierReviewsProvider);
    final customerPending = ref.watch(pendingCustomerReviewsProvider);

    final hour = DateTime.now().hour;
    String greeting = 'GOOD MORNING';
    if (hour >= 12 && hour < 17) greeting = 'GOOD AFTERNOON';
    if (hour >= 17) greeting = 'GOOD EVENING';

    int pendingCount = supplierPending + customerPending;

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
              gradient: LinearGradient(
                colors: [
                  context.primaryColor.withValues(alpha: 0.3),
                  context.primaryColor.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: context.isDark
                  ? context.borderColor
                  : const Color(0xFF1E293B),
              child: const Icon(
                LucideIcons.user,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
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
                  '${greeting[0]}${greeting.substring(1).toLowerCase()},',
                  style: TextStyle(
                    color: context.textSecondaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  username,
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: context.borderColor.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: IconButton(
            icon: Badge(
              isLabelVisible: pendingCount > 0,
              label: Text(pendingCount > 99 ? '99+' : pendingCount.toString()),
              backgroundColor: context.errorColor,
              child: const Icon(LucideIcons.bell, size: 22),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              _showReviewSelectionDialog(context);
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
              label: 'TO COLLECT',
              amount: CurrencyFormatter.format(totals.totalReceivable),
              color: context.successColor,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryCard(
              label: 'TO GIVE',
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
              label: 'TO COLLECT',
              amount: '...',
              isLoading: true,
              color: context.successColor,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryCard(
              label: 'TO GIVE',
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
                label: 'TO COLLECT',
                amount: 'Retry',
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
                label: 'TO GIVE',
                amount: 'Retry',
                color: context.errorColor,
                isDark: isDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        onChanged: (value) =>
            ref.read(udharSearchQueryProvider.notifier).setQuery(value),
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Search customers or vendors...',
          hintStyle: TextStyle(
            color: context.textSecondaryColor.withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(
              LucideIcons.search,
              size: 20,
              color: context.primaryColor.withValues(alpha: 0.6),
            ),
          ),
          filled: true,
          fillColor: context.surfaceColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: context.borderColor.withValues(alpha: 0.5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: context.borderColor.withValues(alpha: 0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: context.primaryColor, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(
    BuildContext context,
    WidgetRef ref,
    HomePartyFilter currentFilter,
  ) {
    return Row(
      children: [
        Expanded(
          child: _FilterChip(
            label: 'All',
            isSelected: currentFilter == HomePartyFilter.all,
            onTap: () => ref
                .read(homePartyFilterProvider.notifier)
                .setFilter(HomePartyFilter.all),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: _FilterChip(
            label: 'Pending',
            isSelected: currentFilter == HomePartyFilter.pending,
            onTap: () => ref
                .read(homePartyFilterProvider.notifier)
                .setFilter(HomePartyFilter.pending),
            highlightColor: context.warningColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: _FilterChip(
            label: 'Customers',
            isSelected: currentFilter == HomePartyFilter.customers,
            onTap: () => ref
                .read(homePartyFilterProvider.notifier)
                .setFilter(HomePartyFilter.customers),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: _FilterChip(
            label: 'Suppliers',
            isSelected: currentFilter == HomePartyFilter.suppliers,
            onTap: () => ref
                .read(homePartyFilterProvider.notifier)
                .setFilter(HomePartyFilter.suppliers),
          ),
        ),
      ],
    );
  }

  Widget _buildScanBillFab(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            context.primaryColor,
            context.primaryColor.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: context.primaryColor.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const BillTypeSelectionSheet(),
            );
          },
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.camera, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Scan Bill'.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          ...context.premiumShadow,
        ],
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -12,
            top: -12,
            child: Icon(
              label.contains('COLLECT')
                  ? LucideIcons.arrowDownLeft
                  : LucideIcons.arrowUpRight,
              color: color.withValues(alpha: 0.06),
              size: 72,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      label.contains('COLLECT') ? LucideIcons.trendingDown : LucideIcons.trendingUp,
                      size: 12,
                      color: color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        color: color.withValues(alpha: 0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (isLoading)
                SizedBox(
                  height: 38,
                  child: Center(
                    child: LinearProgressIndicator(
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                )
              else
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    amount,
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
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
  final Color? highlightColor;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = highlightColor ?? context.primaryColor;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? activeColor : context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeColor : context.borderColor.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isSelected ? Colors.white : context.textSecondaryColor,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}

/// Pulsing skeleton card shown during the very first data load.
/// Once data is cached, this never shows again \u2014 refreshes happen in
/// the background while the real list stays visible.
class _PartySkeletonCard extends StatefulWidget {
  const _PartySkeletonCard();

  @override
  State<_PartySkeletonCard> createState() => _PartySkeletonCardState();
}

class _PartySkeletonCardState extends State<_PartySkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final shimmer = context.isDark
            ? Color.lerp(
                const Color(0xFF1E293B),
                const Color(0xFF334155),
                _anim.value,
              )!
            : Color.lerp(
                const Color(0xFFE2E8F0),
                const Color(0xFFF1F5F9),
                _anim.value,
              )!;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(
            children: [
              // Avatar placeholder
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: shimmer,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: shimmer,
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 10,
                      width: 120,
                      decoration: BoxDecoration(
                        color: shimmer,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Amount placeholder
              Container(
                height: 20,
                width: 64,
                decoration: BoxDecoration(
                  color: shimmer,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
