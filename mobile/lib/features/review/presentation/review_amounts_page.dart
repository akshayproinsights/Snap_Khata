import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/review/domain/models/review_models.dart';
import 'package:mobile/features/review/presentation/providers/review_provider.dart';
import 'package:mobile/shared/widgets/receipt_card.dart';

class ReviewAmountsPage extends ConsumerStatefulWidget {
  const ReviewAmountsPage({super.key});

  @override
  ConsumerState<ReviewAmountsPage> createState() => _ReviewAmountsPageState();
}

class _ReviewAmountsPageState extends ConsumerState<ReviewAmountsPage> {
  bool _showCompleted = false;
  final Map<String, bool> _showSuccessFor = {};

  void _syncAndFinish() {
    ref.read(reviewProvider.notifier).syncAndFinish();
  }

  void _handleDeleteRow(ReviewRecord record) async {
    final act = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete line item?'),
        content: const Text(
            'Are you sure you want to delete this line item? This will remove it permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: context.errorColor),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (act == true) {
      ref
          .read(reviewProvider.notifier)
          .deleteRecord(record.rowId, record.receiptNumber);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reviewProvider);

    int pending = 0;
    int completed = 0;
    int duplicates = 0;
    int total = 0;

    final records = <ReviewRecord>[];

    for (var group in state.groups) {
      for (var item in group.lineItems) {
        records.add(item);
        total++;
        final status = item.verificationStatus.toLowerCase();
        if (status == 'pending') {
          pending++;
        } else if (status == 'done') {
          completed++;
        } else if (status == 'duplicate receipt number') {
          duplicates++;
        }
      }
    }

    final filteredRecords = records.where((r) {
      final status = r.verificationStatus.toLowerCase();
      if (status == 'pending' || status == 'duplicate receipt number') {
        return true;
      }
      if (status == 'done' && _showCompleted) {
        return true;
      }
      return false;
    }).toList();

    filteredRecords.sort((a, b) {
      // 1. Primary sort: Receipt Number (keep items of same receipt together)
      if (a.receiptNumber != b.receiptNumber) {
        return a.receiptNumber.compareTo(b.receiptNumber);
      }

      // 2. Secondary sort: BBox Y Coordinate (if available)
      final yA = (a.lineItemBbox != null && a.lineItemBbox!.length > 1)
          ? a.lineItemBbox![1]
          : null;
      final yB = (b.lineItemBbox != null && b.lineItemBbox!.length > 1)
          ? b.lineItemBbox![1]
          : null;

      if (yA != null && yB != null && (yA - yB).abs() > 0.001) {
        return yA.compareTo(yB);
      }

      // 3. Tertiary sort: Original extraction index (parsed from rowId)
      return a.sortIndex.compareTo(b.sortIndex);
    });

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: const Text('Review Amounts'),
        actions: [
          TextButton.icon(
            onPressed: () {
              setState(() => _showCompleted = !_showCompleted);
            },
            icon: Icon(
              _showCompleted ? LucideIcons.checkSquare : LucideIcons.square,
              size: 20,
            ),
            label:
                Text(_showCompleted ? 'Showing Completed' : 'Show Completed'),
            style: TextButton.styleFrom(
              foregroundColor:
                  _showCompleted ? context.primaryColor : context.textSecondaryColor,
            ),
          )
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(reviewProvider.notifier).fetchReviewData(),
              child: Column(
                children: [
                  _buildStatsHeader(pending, completed, duplicates, total),
                  if (state.isSyncing)
                    LinearProgressIndicator(
                      value: state.syncProgress?.percentage != null
                          ? state.syncProgress!.percentage / 100
                          : null,
                    ),
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(state.error!,
                          style: TextStyle(color: context.errorColor)),
                    ),
                  Expanded(
                    child: filteredRecords.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 100),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(LucideIcons.checkCircle2,
                                        size: 60, color: context.successColor),
                                    const SizedBox(height: 16),
                                    Text('All caught up! 🎉',
                                        style: TextStyle(
                                            color: context.textSecondaryColor,
                                            fontSize: 18)),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredRecords.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              return _buildAmountCard(filteredRecords[index]);
                            },
                          ),
                  )
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: (state.isSyncing ||
                    (completed == 0 && pending == 0 && duplicates == 0))
                ? null
                : _syncAndFinish,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 4,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (state.isSyncing)
                  const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                else
                  const Icon(LucideIcons.refreshCw, size: 18),
                const SizedBox(width: 8),
                Text(
                  state.isSyncing
                      ? 'Syncing... ${state.syncProgress?.percentage ?? 0}%'
                      : 'Sync & Finish',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (completed > 0 && !state.isSyncing)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12)),
                    child: Text('$completed',
                        style: TextStyle(
                            color: context.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsHeader(
      int pending, int completed, int duplicates, int total) {
    if (total == 0) return const SizedBox.shrink();
    final double completePercent = total > 0 ? (completed / total) : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.primaryColor.withValues(alpha: 0.05),
        border: Border(bottom: BorderSide(color: context.borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (pending > 0)
                _buildStatIndicator('$pending Pending', context.warningColor,
                    context.warningColor.withValues(alpha: 0.1)),
              if (completed > 0)
                _buildStatIndicator('$completed Completed',
                    context.successColor, context.successColor.withValues(alpha: 0.1)),
              if (duplicates > 0)
                _buildStatIndicator('$duplicates Duplicates',
                    context.errorColor, context.errorColor.withValues(alpha: 0.1)),
              if (pending == 0 && completed == 0 && duplicates == 0)
                Text('All caught up! 🎉',
                    style:
                        TextStyle(color: context.textSecondaryColor, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Review Progress',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondaryColor)),
              Text('${(completePercent * 100).round()}% Complete',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: context.textColor)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: completePercent,
            backgroundColor: context.borderColor.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(context.successColor),
            borderRadius: BorderRadius.circular(4),
            minHeight: 8,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$completed of $total completed',
                  style: TextStyle(
                      fontSize: 11, color: context.textSecondaryColor)),
              if (pending > 0)
                Text('$pending remaining',
                    style:
                        TextStyle(fontSize: 11, color: context.warningColor)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatIndicator(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Text(text,
          style: TextStyle(
              color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildAmountCard(ReviewRecord record) {
    Map<String, BBox?> bboxes = {};
    if (record.lineItemBbox != null && record.lineItemBbox!.length >= 4) {
      bboxes['lineItem'] = BBox(
        x: record.lineItemBbox![0],
        y: record.lineItemBbox![1],
        width: record.lineItemBbox![2],
        height: record.lineItemBbox![3],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
        boxShadow: context.premiumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header (Receipt Info)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Receipt #${record.receiptNumber}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: context.textSecondaryColor,
                          fontSize: 12),
                    ),
                    if (record.receiptLink.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          // Future enhancement: Open full image viewer
                        },
                        child: Text('View Full Receipt',
                            style: TextStyle(
                                color: context.primaryColor,
                                fontSize: 12,
                                decoration: TextDecoration.underline)),
                      )
                  ],
                ),
                const SizedBox(height: 12),

                // Image Slice if available
                if (record.receiptLink.isNotEmpty &&
                    bboxes.containsKey('lineItem'))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: SizedBox(
                      height: 60, // Wide slice for line item
                      child: ReceiptCard(
                        imageUrl: record.receiptLink,
                        bboxes: bboxes,
                        highlightFields: const ['lineItem'],
                        width: double.infinity,
                      ),
                    ),
                  ),

                // Form Fields
                _buildFormField(
                  record: record,
                  label: 'Description',
                  fieldKey: 'description',
                  initialValue: record.description,
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildFormField(
                        record: record,
                        label: 'Qty',
                        fieldKey: 'quantity',
                        initialValue: record.quantity?.toString() ?? '',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: _buildFormField(
                        record: record,
                        label: 'Rate',
                        fieldKey: 'rate',
                        initialValue: record.rate?.toString() ?? '',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: _buildFormField(
                        record: record,
                        label: 'Amount',
                        fieldKey: 'amount',
                        initialValue: record.amount.toString(),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                  ],
                ),

                // Mismatch Alert
                if (record.amountMismatch != null && record.amountMismatch! > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.errorColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.errorColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.alertCircle,
                              color: context.errorColor, size: 16),
                          const SizedBox(width: 8),
                          Text(
                              'Calculation Mismatch: ₹${record.amountMismatch}',
                              style: TextStyle(
                                  color: context.errorColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: context.isDark ? context.surfaceColor.withValues(alpha: 0.5) : Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16)),
              border: Border(top: BorderSide(color: context.borderColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatusDropdown(record),
                IconButton(
                  icon: Icon(LucideIcons.trash2,
                      color: context.errorColor, size: 20),
                  onPressed: () => _handleDeleteRow(record),
                  tooltip: 'Delete Item',
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFormField({
    required ReviewRecord record,
    required String label,
    required String fieldKey,
    required String initialValue,
    required TextInputType keyboardType,
  }) {
    final isSuccess = _showSuccessFor['${record.rowId}-$fieldKey'] ?? false;

    return TextFormField(
      initialValue: initialValue,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: isSuccess
              ? BorderSide(color: context.successColor)
              : BorderSide(color: context.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: isSuccess
              ? BorderSide(color: context.successColor, width: 2)
              : BorderSide(color: context.primaryColor, width: 2),
        ),
        isDense: true,
        filled: isSuccess,
        fillColor: context.successColor.withValues(alpha: 0.05),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      onFieldSubmitted: (val) {
        if (val != initialValue) {
          final newRecord =
              _updateRecordWithRebuiltFields(record, fieldKey, val);
          ref.read(reviewProvider.notifier).updateAmountRecord(newRecord);
          _triggerSuccess('${record.rowId}-$fieldKey');
        }
      },
    );
  }

  void _triggerSuccess(String key) {
    setState(() => _showSuccessFor[key] = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showSuccessFor[key] = false);
    });
  }

  ReviewRecord _updateRecordWithRebuiltFields(
      ReviewRecord record, String fieldKey, String value) {
    return ReviewRecord(
      rowId: record.rowId,
      receiptNumber: record.receiptNumber,
      date: record.date,
      description: fieldKey == 'description' ? value : record.description,
      amount: fieldKey == 'amount'
          ? (double.tryParse(value) ?? record.amount)
          : record.amount,
      quantity:
          fieldKey == 'quantity' ? double.tryParse(value) : record.quantity,
      rate: fieldKey == 'rate' ? double.tryParse(value) : record.rate,
      amountMismatch: record.amountMismatch,
      verificationStatus:
          fieldKey == 'verificationStatus' ? value : record.verificationStatus,
      receiptLink: record.receiptLink,
      dateBbox: record.dateBbox,
      receiptNumberBbox: record.receiptNumberBbox,
      combinedBbox: record.combinedBbox,
      lineItemBbox: record.lineItemBbox,
      isHeader: record.isHeader,
    );
  }

  Widget _buildStatusDropdown(ReviewRecord record) {
    final statusColor = record.verificationStatus.toLowerCase() == 'done'
        ? context.successColor
        : record.verificationStatus.toLowerCase() == 'duplicate receipt number'
            ? context.warningColor
            : context.primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: record.verificationStatus,
          isDense: true,
          icon: Icon(LucideIcons.chevronDown, size: 16, color: statusColor),
          style: TextStyle(
              color: statusColor, fontSize: 13, fontWeight: FontWeight.bold),
          items: ['Pending', 'Done', 'Duplicate Receipt Number'].map((s) {
            return DropdownMenuItem(value: s, child: Text(s));
          }).toList(),
          onChanged: (newStatus) {
            if (newStatus != null && newStatus != record.verificationStatus) {
              final newRecord = _updateRecordWithRebuiltFields(
                  record, 'verificationStatus', newStatus);
              ref.read(reviewProvider.notifier).updateAmountRecord(newRecord);
            }
          },
        ),
      ),
    );
  }
}
