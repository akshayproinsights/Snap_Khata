import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/upload/domain/models/upload_models.dart';

class RecentTasksList extends StatelessWidget {
  final String title;
  final UploadHistoryResponse? historyData;
  final bool isLoading;
  final String? error;

  const RecentTasksList({
    super.key,
    required this.title,
    this.historyData,
    this.isLoading = false,
    this.error,
  });

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final targetDate = DateTime(date.year, date.month, date.day);

      if (targetDate == today) {
        return 'Today';
      } else if (targetDate == yesterday) {
        return 'Yesterday';
      }

      return DateFormat('E, d MMM').format(date); // e.g., Wed, 21 Jan
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (isLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (isLoading && (historyData == null || historyData!.history.isEmpty)) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.primary,
          ),
        ),
      );
    }

    if (error != null &&
        (historyData == null || historyData!.history.isEmpty)) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.alertCircle,
                  color: AppTheme.error, size: 28),
              const SizedBox(height: 12),
              Text(
                'Failed to load history:\n$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.error, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (historyData == null || historyData!.history.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
        child: Center(
          child: Text(
            'No upload history yet. Upload your first sales bill to get started!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Header Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Date',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary)),
              Text('Receipts',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary)),
            ],
          ),
        ),
        // List of items
        ClipRRect(
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(16)),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: historyData!.history.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppTheme.border),
            itemBuilder: (context, index) {
              final item = historyData!.history[index];
              return Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  iconColor: AppTheme.primary,
                  collapsedIconColor: AppTheme.textSecondary,
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  childrenPadding: EdgeInsets.zero,
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDate(item.date),
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary),
                      ),
                      Text(
                        item.count.toString(),
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Receipt IDs:',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: item.receiptIds.map((id) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  id,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primary),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
