import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:mobile/features/udhar/presentation/providers/udhar_provider.dart';
import 'package:mobile/features/inventory/presentation/providers/vendor_ledger_provider.dart';
import 'package:mobile/features/udhar/domain/models/unified_party.dart';
import 'package:mobile/features/udhar/presentation/providers/paginated_khata_provider.dart';
import 'package:mobile/core/theme/context_extension.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:mobile/models/pagination_state.dart';
import 'package:go_router/go_router.dart';

class PartiesListPagePaginated extends ConsumerStatefulWidget {
  const PartiesListPagePaginated({super.key});

  @override
  ConsumerState<PartiesListPagePaginated> createState() =>
      _PartiesListPagePaginatedState();
}

class _PartiesListPagePaginatedState
    extends ConsumerState<PartiesListPagePaginated> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      // Load next page when user is near the bottom
      ref.read(paginatedKhataProvider.notifier).loadNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final paginationState = ref.watch(paginatedKhataProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Parties (Khata)'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                // Trigger search with debounce
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) {
                    ref
                        .read(paginatedKhataProvider.notifier)
                        .loadFirstPage(
                          newConfig: KhataPaginationConfig(
                            searchQuery: value.isNotEmpty ? value : null,
                          ),
                        );
                  }
                });
              },
              decoration: InputDecoration(
                hintText: 'Search parties...',
                prefixIcon: const Icon(LucideIcons.search),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // Parties list or skeleton
          Expanded(
            child: paginationState.when(
              initial: () => const _SkeletonLoader(),
              loadingFirstPage: () => const _SkeletonLoader(),
              loadingNextPage: (previousItems) => _buildPartiesList(
                context,
                previousItems,
                true,
                isDark,
              ),
              loaded: (items, hasNext, nextCursor, isLoadingMore) =>
                  _buildPartiesList(context, items, isLoadingMore, isDark),
              error: (message, previousItems) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.alertCircle,
                        size: 48, color: Colors.red.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading parties',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        ref
                            .read(paginatedKhataProvider.notifier)
                            .loadFirstPage();
                      },
                      icon: Icon(LucideIcons.refreshCw),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              empty: () => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.users,
                        size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No parties found',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartiesList(
    BuildContext context,
    List<UnifiedParty> parties,
    bool isLoadingMore,
    bool isDark,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(paginatedKhataProvider.notifier).refresh();
      },
      child: ListView.builder(
        controller: _scrollController,
        itemCount: parties.length + (isLoadingMore ? 1 : 0),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          if (index == parties.length) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(
                      isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
            );
          }

          final party = parties[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildPartyCard(context, party),
          );
        },
      ),
    );
  }

  Widget _buildPartyCard(BuildContext context, UnifiedParty party) {
    final isDebit = party.balanceDue > 0;
    final balanceColor = isDebit ? Colors.red : Colors.green;

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.heavyImpact();
        _showDeleteConfirmation(context, party);
      },
      onTap: () {
        context.push('/udhar/party/${party.partyName}');
      },
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          party.partyName,
                          style: context.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          party.type.name.toUpperCase(),
                          style: context.textTheme.labelSmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.format(party.balanceDue),
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: balanceColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isDebit ? 'BALANCE DUE' : 'CREDIT',
                        style: context.textTheme.labelSmall?.copyWith(
                          color: balanceColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (party.lastTransactionDate != null)
                Text(
                  'Last updated: ${party.lastTransactionDate}',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: Colors.grey.shade500,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    UnifiedParty party,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 32,
                left: 24,
                right: 24,
                top: 24,
              ),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Danger icon circle
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.errorColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.trash2,
                      color: context.errorColor,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Delete Party?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: context.textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Party name badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: context.textSecondaryColor.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color:
                                context.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              party.partyName.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                color: context.primaryColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          party.partyName,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: context.textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'This will permanently delete all transactions\nand payment history for this party.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.textSecondaryColor,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Delete CTA
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isDeleting
                          ? null
                          : () async {
                              setSheetState(() => isDeleting = true);
                              HapticFeedback.heavyImpact();
                              bool success;
                              if (party.type == PartyType.customer) {
                                success = await ref
                                    .read(udharProvider.notifier)
                                    .deleteLedger(party.id);
                              } else {
                                success = await ref
                                    .read(vendorLedgerProvider.notifier)
                                    .deleteLedger(party.id);
                              }
                              if (!sheetCtx.mounted) return;
                              Navigator.pop(sheetCtx);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success
                                          ? '${party.partyName} deleted'
                                          : 'Failed to delete. Try again.',
                                    ),
                                    backgroundColor: success
                                        ? context.errorColor
                                        : Colors.orange,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                                if (success) {
                                  ref.read(paginatedKhataProvider.notifier).refresh();
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.errorColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: isDeleting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.trash2, size: 18),
                                SizedBox(width: 10),
                                Text(
                                  'Yes, Delete Party',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Cancel
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: TextButton(
                      onPressed:
                          isDeleting ? null : () => Navigator.pop(sheetCtx),
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.textSecondaryColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SkeletonLoader extends StatelessWidget {
  const _SkeletonLoader();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        itemCount: 6,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
      ),
    );
  }
}
