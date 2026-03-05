import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/review/domain/models/review_models.dart';
import 'package:mobile/features/review/presentation/providers/review_provider.dart';
import 'package:mobile/shared/widgets/app_toast.dart';
import 'package:mobile/shared/widgets/receipt_card.dart';
import 'package:intl/intl.dart';

class ReviewDatesPage extends ConsumerStatefulWidget {
  const ReviewDatesPage({super.key});

  @override
  ConsumerState<ReviewDatesPage> createState() => _ReviewDatesPageState();
}

class _ReviewDatesPageState extends ConsumerState<ReviewDatesPage> {
  bool _showCompleted = false;
  final Map<String, bool> _showSuccessFor = {};

  void _syncAndFinish() {
    ref.read(reviewProvider.notifier).syncAndFinish();
  }

  void _handleDeleteRow(String receiptNumber) async {
    final act = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete receipt?'),
        content: Text(
            'Are you sure you want to delete Receipt #$receiptNumber? This will remove ALL records for this receipt.'),
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
      ref.read(reviewProvider.notifier).deleteReceipt(receiptNumber);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ReviewState>(reviewProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        AppToast.showError(context, next.error!, title: 'Update Failed');
      }
    });
    final state = ref.watch(reviewProvider);

    int pending = 0;
    int completed = 0;
    int duplicates = 0;
    int total = 0;

    final records = <ReviewRecord>[];

    for (var group in state.groups) {
      if (group.header != null) {
        records.add(group.header!);
        total++;
        final status = group.header!.verificationStatus.toLowerCase();
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
        title: const Text('Review Dates & Receipts'),
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
                              return _buildDateCard(filteredRecords[index]);
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
        color: AppTheme.primary.withValues(alpha: 0.05),
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
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Text(text,
          style: TextStyle(
              color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildDateCard(ReviewRecord record) {
    Map<String, BBox?> bboxes = {};
    if (record.combinedBbox != null && record.combinedBbox!.length >= 4) {
      bboxes['combined'] = BBox(
        x: record.combinedBbox![0],
        y: record.combinedBbox![1],
        width: record.combinedBbox![2],
        height: record.combinedBbox![3],
      );
    } else {
      if (record.receiptNumberBbox != null &&
          record.receiptNumberBbox!.length >= 4) {
        bboxes['receipt_number'] = BBox(
          x: record.receiptNumberBbox![0],
          y: record.receiptNumberBbox![1],
          width: record.receiptNumberBbox![2],
          height: record.receiptNumberBbox![3],
        );
      }
      if (record.dateBbox != null && record.dateBbox!.length >= 4) {
        bboxes['date'] = BBox(
          x: record.dateBbox![0],
          y: record.dateBbox![1],
          width: record.dateBbox![2],
          height: record.dateBbox![3],
        );
      }
    }

    final isSuccessReceipt =
        _showSuccessFor['\${record.rowId}-receipt'] ?? false;
    final isSuccessDate = _showSuccessFor['\${record.rowId}-date'] ?? false;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Map
                if (record.receiptLink.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: ReceiptCard(
                      imageUrl: record.receiptLink,
                      bboxes: bboxes,
                      highlightFields: record.combinedBbox != null
                          ? const ['combined']
                          : const ['receipt_number', 'date'],
                      width: 100,
                    ),
                  )
                else
                  Container(
                    width: 100,
                    height: 100,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8)),
                    child: const Center(
                        child: Text('No Image',
                            style:
                                TextStyle(color: Colors.grey, fontSize: 10))),
                  ),

                Expanded(
                  child: Column(
                    children: [
                      TextFormField(
                        initialValue: record.receiptNumber,
                        decoration: InputDecoration(
                          labelText: 'Receipt Number',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: isSuccessReceipt
                                ? const BorderSide(color: AppTheme.success)
                                : const BorderSide(),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: isSuccessReceipt
                                ? const BorderSide(
                                    color: AppTheme.success, width: 2)
                                : const BorderSide(
                                    color: AppTheme.primary, width: 2),
                          ),
                          isDense: true,
                          filled: isSuccessReceipt,
                          fillColor: AppTheme.success.withValues(alpha: 0.05),
                        ),
                        onFieldSubmitted: (val) {
                          if (val != record.receiptNumber) {
                            final newRecord = _updateRecordWithRebuiltFields(
                                record,
                                receiptNumber: val);
                            ref
                                .read(reviewProvider.notifier)
                                .updateDateRecord(newRecord);
                            _triggerSuccess('\${record.rowId}-receipt');
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          DateTime? initialDate;
                          try {
                            if (record.date.isNotEmpty) {
                              try {
                                initialDate = DateFormat('dd-MM-yyyy')
                                    .parseStrict(record.date);
                              } catch (e) {
                                initialDate = DateTime.parse(record.date);
                              }
                            }
                          } catch (_) {}

                          final picked = await showDatePicker(
                            context: context,
                            initialDate: initialDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );

                          if (picked != null) {
                            final formattedDate =
                                DateFormat('dd-MM-yyyy').format(picked);
                            if (formattedDate != record.date) {
                              final newRecord = _updateRecordWithRebuiltFields(
                                  record,
                                  date: formattedDate);
                              ref
                                  .read(reviewProvider.notifier)
                                  .updateDateRecord(newRecord);
                              _triggerSuccess('\${record.rowId}-date');
                            }
                          }
                        },
                        child: IgnorePointer(
                          child: TextFormField(
                            // ignore: prefer_const_constructors
                            key: ValueKey('date_\${record.date}'),
                            initialValue: record.date,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'Date (DD-MM-YYYY)',
                              suffixIcon:
                                  const Icon(LucideIcons.calendar, size: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: isSuccessDate
                                    ? const BorderSide(color: AppTheme.success)
                                    : const BorderSide(),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: isSuccessDate
                                    ? const BorderSide(
                                        color: AppTheme.success, width: 2)
                                    : const BorderSide(
                                        color: AppTheme.primary, width: 2),
                              ),
                              isDense: true,
                              filled: isSuccessDate,
                              fillColor: AppTheme.success.withValues(alpha: 0.05),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
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
                  onPressed: () => _handleDeleteRow(record.receiptNumber),
                  tooltip: 'Delete Receipt',
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  void _triggerSuccess(String key) {
    setState(() => _showSuccessFor[key] = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showSuccessFor[key] = false);
    });
  }

  ReviewRecord _updateRecordWithRebuiltFields(ReviewRecord record,
      {String? receiptNumber, String? date, String? verificationStatus}) {
    return ReviewRecord(
      rowId: record.rowId,
      receiptNumber: receiptNumber ?? record.receiptNumber,
      date: date ?? record.date,
      description: record.description,
      amount: record.amount,
      verificationStatus: verificationStatus ?? record.verificationStatus,
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
              final newRecord = _updateRecordWithRebuiltFields(record,
                  verificationStatus: newStatus);
              ref.read(reviewProvider.notifier).updateDateRecord(newRecord);
            }
          },
        ),
      ),
    );
  }
}
