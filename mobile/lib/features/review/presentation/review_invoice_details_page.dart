import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/review/domain/models/review_models.dart';
import 'package:mobile/features/review/presentation/providers/review_provider.dart';
import 'package:mobile/shared/widgets/app_toast.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ReviewInvoiceDetailsPage extends ConsumerStatefulWidget {
  const ReviewInvoiceDetailsPage({super.key});

  @override
  ConsumerState<ReviewInvoiceDetailsPage> createState() =>
      _ReviewInvoiceDetailsPageState();
}

class _ReviewInvoiceDetailsPageState
    extends ConsumerState<ReviewInvoiceDetailsPage> {
  bool _showCompleted = false;

  void _syncAndFinish() async {
    await ref.read(reviewProvider.notifier).syncAndFinish();

    // Check if mounted before navigating or showing toasts
    if (!mounted) return;

    final state = ref.read(reviewProvider);
    if (state.error == null) {
      AppToast.showSuccess(context, 'Invoices synced successfully!',
          title: 'Sync Complete');
      context.go('/dashboard');
    } else {
      AppToast.showError(context, state.error!, title: 'Sync Failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reviewProvider);

    // Filter list
    final filteredGroups = state.groups.where((group) {
      if (_showCompleted) return true;
      return !group.isComplete;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Review Invoice Details'),
        actions: [
          TextButton.icon(
            onPressed: () {
              setState(() => _showCompleted = !_showCompleted);
            },
            icon: Icon(
                _showCompleted ? LucideIcons.checkSquare : LucideIcons.square,
                size: 20),
            label:
                Text(_showCompleted ? 'Showing Completed' : 'Show Completed'),
            style: TextButton.styleFrom(
                foregroundColor:
                    _showCompleted ? AppTheme.primary : AppTheme.textSecondary),
          )
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Stats
                _buildStatsHeader(state.groups),

                // Sync Progress bar overlay
                if (state.isSyncing)
                  LinearProgressIndicator(
                      value: state.syncProgress?.percentage != null
                          ? state.syncProgress!.percentage / 100
                          : null),

                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(state.error!,
                        style: const TextStyle(color: AppTheme.error)),
                  ),

                // List
                Expanded(
                  child: filteredGroups.isEmpty
                      ? const Center(child: Text('All caught up! 🎉'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredGroups.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            return _buildInvoiceGroupCard(filteredGroups[index])
                                .animate()
                                .fadeIn(
                                    duration: 400.ms, delay: (50 * index).ms)
                                .slideY(
                                    begin: 0.1,
                                    duration: 400.ms,
                                    curve: Curves.easeOutQuad);
                          },
                        ),
                )
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: state.isSyncing ? null : _syncAndFinish,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(state.isSyncing
                ? 'Syncing... ${state.syncProgress?.percentage ?? 0}%'
                : 'Sync & Finish'),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsHeader(List<InvoiceReviewGroup> groups) {
    int pending = 0;
    int completed = 0;

    for (var group in groups) {
      if (group.isComplete) {
        completed++;
      } else {
        pending++;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.05),
        border: const Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatIndicator('$pending Pending', Colors.orange),
          _buildStatIndicator('$completed Completed', Colors.green),
        ],
      ),
    );
  }

  Widget _buildStatIndicator(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildInvoiceGroupCard(InvoiceReviewGroup group) {
    final header = group.header;
    if (header == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Image (Full width, small height, top aligned)
          if (header.receiptLink.isNotEmpty)
            Stack(
              children: [
                SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: CachedNetworkImage(
                    imageUrl: header.receiptLink,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    placeholder: (context, url) => Container(
                      color: Colors.grey.shade100,
                      child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey.shade100,
                      child: const Center(
                          child: Icon(LucideIcons.imageOff,
                              color: AppTheme.textSecondary)),
                    ),
                  ),
                ),
                // Overlay Gradient
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Status Badge overlay
                Positioned(
                  top: 12,
                  right: 12,
                  child: _buildStatusBanner(header),
                ),
              ],
            ),

          // Header Form Fields
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top controls without image
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: header.receiptNumber,
                        decoration: InputDecoration(
                          labelText: 'Receipt No.',
                          filled: true,
                          fillColor: AppTheme.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          isDense: true,
                        ),
                        onFieldSubmitted: (val) {
                          if (val != header.receiptNumber) {
                            final newRecord = ReviewRecord(
                                rowId: header.rowId,
                                receiptNumber: val,
                                date: header.date,
                                description: header.description,
                                amount: header.amount,
                                verificationStatus: header.verificationStatus,
                                receiptLink: header.receiptLink,
                                dateBbox: header.dateBbox,
                                receiptNumberBbox: header.receiptNumberBbox,
                                combinedBbox: header.combinedBbox,
                                lineItemBbox: header.lineItemBbox,
                                isHeader: header.isHeader);
                            ref
                                .read(reviewProvider.notifier)
                                .updateDateRecord(newRecord);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: header.date,
                        decoration: InputDecoration(
                          labelText: 'Date',
                          filled: true,
                          fillColor: AppTheme.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          isDense: true,
                        ),
                        onFieldSubmitted: (val) {
                          if (val != header.date) {
                            final newRecord = ReviewRecord(
                                rowId: header.rowId,
                                receiptNumber: header.receiptNumber,
                                date: val,
                                description: header.description,
                                amount: header.amount,
                                verificationStatus: header.verificationStatus,
                                receiptLink: header.receiptLink,
                                dateBbox: header.dateBbox,
                                receiptNumberBbox: header.receiptNumberBbox,
                                combinedBbox: header.combinedBbox,
                                lineItemBbox: header.lineItemBbox,
                                isHeader: header.isHeader);
                            ref
                                .read(reviewProvider.notifier)
                                .updateDateRecord(newRecord);
                          }
                        },
                      ),
                    ),
                  ],
                ),

                // If there's no banner image, show the status dropdown here
                if (header.receiptLink.isEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Status',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      _buildStatusDropdown(header),
                    ],
                  ),
                ] else ...[
                  // If we have banner, we might still want to allow changing status
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _buildStatusDropdown(header),
                  ),
                ]
              ],
            ),
          ),

          // Line Items
          if (group.lineItems.isNotEmpty) ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              color: AppTheme.background.withOpacity(0.5),
              child: Row(
                children: [
                  const Icon(LucideIcons.list,
                      size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Text('${group.lineItems.length} Line Items',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTheme.textSecondary)),
                ],
              ),
            ),
            ...group.lineItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Container(
                color: index.isEven
                    ? Colors.white
                    : AppTheme.background.withOpacity(0.3),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppTheme.border.withOpacity(0.5)),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        child: TextFormField(
                          initialValue: item.description,
                          maxLines: null,
                          decoration: const InputDecoration(
                            hintText: 'Description',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500),
                          onFieldSubmitted: (val) {
                            if (val != item.description) {
                              final newRecord = ReviewRecord(
                                  rowId: item.rowId,
                                  receiptNumber: item.receiptNumber,
                                  date: item.date,
                                  description: val,
                                  amount: item.amount,
                                  verificationStatus: item.verificationStatus,
                                  receiptLink: item.receiptLink,
                                  dateBbox: item.dateBbox,
                                  receiptNumberBbox: item.receiptNumberBbox,
                                  combinedBbox: item.combinedBbox,
                                  lineItemBbox: item.lineItemBbox,
                                  isHeader: item.isHeader);
                              ref
                                  .read(reviewProvider.notifier)
                                  .updateAmountRecord(newRecord);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text('₹',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppTheme.primary)),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: AppTheme.border.withOpacity(0.5)),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              child: TextFormField(
                                initialValue: item.amount.toStringAsFixed(2),
                                textAlign: TextAlign.right,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                  hintText: '0.00',
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppTheme.primary),
                                onFieldSubmitted: (val) {
                                  final newAmount = double.tryParse(val);
                                  if (newAmount != null &&
                                      newAmount != item.amount) {
                                    final newRecord = ReviewRecord(
                                        rowId: item.rowId,
                                        receiptNumber: item.receiptNumber,
                                        date: item.date,
                                        description: item.description,
                                        amount: newAmount,
                                        verificationStatus:
                                            item.verificationStatus,
                                        receiptLink: item.receiptLink,
                                        dateBbox: item.dateBbox,
                                        receiptNumberBbox:
                                            item.receiptNumberBbox,
                                        combinedBbox: item.combinedBbox,
                                        lineItemBbox: item.lineItemBbox,
                                        isHeader: item.isHeader);
                                    ref
                                        .read(reviewProvider.notifier)
                                        .updateAmountRecord(newRecord);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ]
        ],
      ),
    );
  }

  Widget _buildStatusBanner(ReviewRecord header) {
    final statusColor = header.verificationStatus.toLowerCase() == 'done'
        ? Colors.green
        : AppTheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        header.verificationStatus.toUpperCase(),
        style: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatusDropdown(ReviewRecord header) {
    final statusColor = header.verificationStatus.toLowerCase() == 'done'
        ? Colors.green
        : header.verificationStatus.toLowerCase() == 'duplicate receipt number'
            ? Colors.orange
            : AppTheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: header.verificationStatus,
          isDense: true,
          icon: Icon(LucideIcons.chevronDown, size: 16, color: statusColor),
          style: TextStyle(
              color: statusColor, fontSize: 13, fontWeight: FontWeight.bold),
          items: ['Pending', 'Done', 'Duplicate Receipt Number'].map((s) {
            return DropdownMenuItem(value: s, child: Text(s));
          }).toList(),
          onChanged: (newStatus) {
            if (newStatus != null && newStatus != header.verificationStatus) {
              final newRecord = ReviewRecord(
                  rowId: header.rowId,
                  receiptNumber: header.receiptNumber,
                  date: header.date,
                  description: header.description,
                  amount: header.amount,
                  verificationStatus: newStatus,
                  receiptLink: header.receiptLink,
                  dateBbox: header.dateBbox,
                  receiptNumberBbox: header.receiptNumberBbox,
                  combinedBbox: header.combinedBbox,
                  lineItemBbox: header.lineItemBbox,
                  isHeader: header.isHeader);
              ref.read(reviewProvider.notifier).updateDateRecord(newRecord);
            }
          },
        ),
      ),
    );
  }
}
