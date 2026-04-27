import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/features/udhar/domain/models/udhar_models.dart';
import 'package:mobile/features/udhar/presentation/providers/paginated_transactions_provider.dart';
import 'package:mobile/core/theme/context_extension.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import 'package:mobile/models/pagination_state.dart';

class PartyDetailPagePaginated extends ConsumerStatefulWidget {
  final int ledgerId;
  final String customerName;

  const PartyDetailPagePaginated({
    required this.ledgerId,
    required this.customerName,
    super.key,
  });

  @override
  ConsumerState<PartyDetailPagePaginated> createState() =>
      _PartyDetailPagePaginatedState();
}

class _PartyDetailPagePaginatedState
    extends ConsumerState<PartyDetailPagePaginated> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      // Load next page when user is near the bottom
      ref
          .read(
            paginatedTransactionsProvider(widget.ledgerId).notifier,
          )
          .loadNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final paginationState = ref.watch(
      paginatedTransactionsProvider(widget.ledgerId),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(widget.customerName),
        centerTitle: true,
      ),
      body: paginationState.when(
        initial: () => const _SkeletonLoader(),
        loadingFirstPage: () => const _SkeletonLoader(),
        loadingNextPage: (previousItems) =>
            _buildWithHeader(context, previousItems, true, isDark),
        loaded: (items, hasNext, nextCursor, isLoadingMore) =>
            _buildWithHeader(context, items, isLoadingMore, isDark),
        error: (message, previousItems) => Column(
          children: [
            if (previousItems.isNotEmpty)
              _buildPartyHeader(context, previousItems),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.alertCircle,
                        size: 48, color: Colors.red.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading transactions',
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
                            .read(
                              paginatedTransactionsProvider(widget.ledgerId)
                                  .notifier,
                            )
                            .loadFirstPage();
                      },
                      icon: Icon(LucideIcons.refreshCw),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        empty: () => Column(
          children: [
            _buildPartyHeaderEmpty(context),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.receipt,
                        size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No transactions',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWithHeader(
    BuildContext context,
    List<LedgerTransaction> transactions,
    bool isLoadingMore,
    bool isDark,
  ) {
    return Column(
      children: [
        _buildPartyHeader(context, transactions),
        Expanded(
          child: _buildTransactionsList(
            context,
            transactions,
            isLoadingMore,
            isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildPartyHeader(
    BuildContext context,
    List<LedgerTransaction> transactions,
  ) {
    if (transactions.isEmpty) {
      return _buildPartyHeaderEmpty(context);
    }

    // Calculate totals from transactions
    double totalDebit = 0;
    double totalCredit = 0;

    for (final tx in transactions) {
      if (tx.type.toLowerCase() == 'debit' || tx.type.toLowerCase() == 'sale') {
        totalDebit += tx.amount;
      } else {
        totalCredit += tx.amount;
      }
    }

    final netBalance = totalDebit - totalCredit;
    final isDebit = netBalance > 0;

    return Container(
      padding: const EdgeInsets.all(16.0),
      color: context.containerColor,
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
                      'Balance Due',
                      style: context.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(netBalance.abs()),
                      style: context.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDebit ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: (isDebit ? Colors.red : Colors.green)
                      .withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isDebit ? 'YOU OWE' : 'CREDIT',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: isDebit ? Colors.red : Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildHeaderMetric(
                  context,
                  'Total Sales',
                  CurrencyFormatter.format(totalDebit),
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHeaderMetric(
                  context,
                  'Total Payments',
                  CurrencyFormatter.format(totalCredit),
                  Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPartyHeaderEmpty(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: context.containerColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Balance Due',
            style: context.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            CurrencyFormatter.format(0),
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderMetric(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(
    BuildContext context,
    List<LedgerTransaction> transactions,
    bool isLoadingMore,
    bool isDark,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        await ref
            .read(
              paginatedTransactionsProvider(widget.ledgerId).notifier,
            )
            .refresh();
      },
      child: ListView.builder(
        controller: _scrollController,
        itemCount: transactions.length + (isLoadingMore ? 1 : 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemBuilder: (context, index) {
          if (index == transactions.length) {
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

          final tx = transactions[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildTransactionCard(context, tx),
          );
        },
      ),
    );
  }

  Widget _buildTransactionCard(
    BuildContext context,
    LedgerTransaction transaction,
  ) {
    final isDebit = transaction.type.toLowerCase() == 'debit' ||
        transaction.type.toLowerCase() == 'sale';
    final color = isDebit ? Colors.red : Colors.green;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description,
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM dd, yyyy')
                        .format(transaction.date),
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
                  (isDebit ? '+' : '-') +
                      CurrencyFormatter.format(transaction.amount),
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
        itemCount: 8,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                height: 130,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 70,
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
