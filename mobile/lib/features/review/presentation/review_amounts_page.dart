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
            'Are you sure you want to delete this line item? This will remove it from the system.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
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

    return Scaffold(
      backgroundColor: AppTheme.background,
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
                  _showCompleted ? AppTheme.primary : AppTheme.textSecondary,
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
                          style: const TextStyle(color: AppTheme.error)),
                    ),
                  Expanded(
                    child: filteredRecords.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 100),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(LucideIcons.checkCircle2,
                                        size: 60, color: AppTheme.success),
                                    SizedBox(height: 16),
                                    Text('All caught up! 🎉',
                                        style: TextStyle(
                                            color: AppTheme.textSecondary,
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
              backgroundColor: AppTheme.primary,
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
                        style: const TextStyle(
                            color: AppTheme.primary,
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
        color: AppTheme.primary.withOpacity(0.05),
        border: const Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (pending > 0)
                _buildStatIndicator('$pending Pending', Colors.amber.shade700,
                    Colors.amber.shade50),
              if (completed > 0)
                _buildStatIndicator('$completed Completed',
                    Colors.green.shade700, Colors.green.shade50),
              if (duplicates > 0)
                _buildStatIndicator('$duplicates Duplicates',
                    Colors.orange.shade700, Colors.orange.shade50),
              if (pending == 0 && completed == 0 && duplicates == 0)
                const Text('All caught up! 🎉',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Review Progress',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary)),
              Text('${(completePercent * 100).round()}% Complete',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: completePercent,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
            borderRadius: BorderRadius.circular(4),
            minHeight: 8,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$completed of $total completed',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
              if (pending > 0)
                Text('$pending remaining',
                    style:
                        TextStyle(fontSize: 11, color: Colors.amber.shade700)),
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
        border: Border.all(color: textColor.withOpacity(0.3)),
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
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
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
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                          fontSize: 12),
                    ),
                    if (record.receiptLink.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          // Future enhancement: Open full image viewer
                        },
                        child: const Text('View Full Receipt',
                            style: TextStyle(
                                color: AppTheme.primary,
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
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(LucideIcons.alertCircle,
                              color: AppTheme.error, size: 16),
                          SizedBox(width: 8),
                          Text(
                              'Calculation Mismatch: ₹\${record.amountMismatch}',
                              style: TextStyle(
                                  color: AppTheme.error,
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
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16)),
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatusDropdown(record),
                IconButton(
                  icon: const Icon(LucideIcons.trash2,
                      color: AppTheme.error, size: 20),
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
    final isSuccess = _showSuccessFor['\${record.rowId}-\$fieldKey'] ?? false;

    return TextFormField(
      initialValue: initialValue,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: isSuccess
              ? const BorderSide(color: AppTheme.success)
              : const BorderSide(),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: isSuccess
              ? const BorderSide(color: AppTheme.success, width: 2)
              : const BorderSide(color: AppTheme.primary, width: 2),
        ),
        isDense: true,
        filled: isSuccess,
        fillColor: AppTheme.success.withOpacity(0.05),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      onFieldSubmitted: (val) {
        if (val != initialValue) {
          final newRecord =
              _updateRecordWithRebuiltFields(record, fieldKey, val);
          ref.read(reviewProvider.notifier).updateAmountRecord(newRecord);
          _triggerSuccess('\${record.rowId}-\$fieldKey');
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
        ? Colors.green
        : record.verificationStatus.toLowerCase() == 'duplicate receipt number'
            ? Colors.orange
            : AppTheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
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
