import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/inventory/domain/models/inventory_mapped_models.dart';
import 'package:mobile/features/inventory/presentation/providers/inventory_mapped_provider.dart';

class InventoryMappedPage extends ConsumerWidget {
  const InventoryMappedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inventoryMappedProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Linked Items',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(inventoryMappedProvider.notifier).fetchEntries(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Header Stats
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                        'View all linked vendor items. Unlink to return items to Link Items.',
                        style: TextStyle(color: AppTheme.textSecondary),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                            child: _buildSummaryCard(
                                'Total',
                                state.totalMapped.toString(),
                                LucideIcons.calendar,
                                Colors.blue)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _buildSummaryCard(
                                'Added',
                                state.addedCount.toString(),
                                LucideIcons.checkCircle,
                                Colors.green)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _buildSummaryCard(
                                'Skipped',
                                state.skippedCount.toString(),
                                LucideIcons.clock,
                                Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // List / Loading / Empty State
            if (state.isLoading && state.entries.isEmpty)
              const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()))
            else if (state.entries.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.calendar,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('No linked items yet.',
                          style: TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final entry = state.entries[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildEntryCard(context, ref, entry),
                      );
                    },
                    childCount: state.entries.length,
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.bold)),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color.shade700)),
        ],
      ),
    );
  }

  Widget _buildEntryCard(
      BuildContext context, WidgetRef ref, VendorMappingEntry entry) {
    final isSkipped = entry.status == 'Skip' || entry.status == 'Skipped';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.vendorDescription,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      if (entry.partNumber != null &&
                          entry.partNumber!.isNotEmpty)
                        Text('Part #: ${entry.partNumber}',
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        isSkipped ? Colors.grey.shade100 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isSkipped ? 'Skipped' : 'Added',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSkipped
                            ? Colors.grey.shade700
                            : Colors.green.shade700),
                  ),
                )
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(LucideIcons.arrowRight,
                    size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Customer Item',
                          style: TextStyle(
                              fontSize: 10, color: AppTheme.textSecondary)),
                      Text(entry.customerItemName ?? '-',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _handleUnmap(context, ref, entry),
                  icon: const Icon(LucideIcons.trash2,
                      color: AppTheme.error, size: 20),
                  tooltip: 'Unmap item',
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Future<void> _handleUnmap(
      BuildContext context, WidgetRef ref, VendorMappingEntry entry) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Unlink Item'),
              content: Text(
                  'Are you sure you want to unlink "${entry.vendorDescription}"?\n\nThis action cannot be undone. The item will be returned to Link Items.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error,
                      foregroundColor: Colors.white),
                  child: const Text('Unlink'),
                ),
              ],
            ));

    if (confirm == true) {
      ref.read(inventoryMappedProvider.notifier).unmapEntry(entry.id);
    }
  }
}
