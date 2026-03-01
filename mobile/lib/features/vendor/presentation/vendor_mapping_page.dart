import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/vendor/presentation/providers/vendor_mapping_provider.dart';
import 'package:mobile/features/vendor/domain/models/vendor_mapping_models.dart';
import 'package:image_picker/image_picker.dart';

class VendorMappingPage extends ConsumerStatefulWidget {
  const VendorMappingPage({super.key});

  @override
  ConsumerState<VendorMappingPage> createState() => _VendorMappingPageState();
}

class _VendorMappingPageState extends ConsumerState<VendorMappingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vendorMappingProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Link Items',
            style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: [
            const Tab(icon: Icon(LucideIcons.edit3), text: 'Edit'),
            const Tab(icon: Icon(LucideIcons.uploadCloud), text: 'Upload'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.eye),
                  const SizedBox(width: 8),
                  const Text('Review'),
                  if (state.reviewQueue.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppTheme.error,
                          borderRadius: BorderRadius.circular(10)),
                      child: Text('${state.reviewQueue.length}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    )
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEditTab(context, ref, state),
          _buildUploadTab(context, ref, state),
          _buildReviewTab(context, ref, state),
        ],
      ),
      floatingActionButton:
          state.reviewQueue.isNotEmpty && _tabController.index != 2
              ? FloatingActionButton.extended(
                  onPressed: () => _tabController.animateTo(2),
                  backgroundColor: AppTheme.primary,
                  icon: const Icon(LucideIcons.eye, color: Colors.white),
                  label: Text('Review (${state.reviewQueue.length})',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                )
              : null,
    );
  }

  // --- 1. Edit Tab ---
  Widget _buildEditTab(
      BuildContext context, WidgetRef ref, VendorMappingState state) {
    if (state.isLoadingExport) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.exportItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.checkCircle2, size: 48, color: AppTheme.success),
            SizedBox(height: 16),
            Text('All items have been linked!',
                style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.exportItems.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = state.exportItems[index];
        // Check if item is already in review queue
        final isQueued = state.reviewQueue.any((r) =>
            r.vendorDescription == item.vendorDescription &&
            r.partNumber == item.partNumber);

        return Container(
            decoration: BoxDecoration(
              color: isQueued ? Colors.green.shade50 : AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: isQueued ? Colors.green.shade200 : AppTheme.border),
            ),
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.vendorDescription,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              if (item.partNumber != null)
                Text('Part #: ${item.partNumber}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontFamily: 'monospace')),
              const SizedBox(height: 16),
              if (isQueued)
                const Row(
                  children: [
                    Icon(LucideIcons.checkCircle2,
                        color: AppTheme.success, size: 16),
                    SizedBox(width: 8),
                    Text('Added to Review',
                        style: TextStyle(
                            color: AppTheme.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showEditItemSheet(context, ref, item),
                        icon: const Icon(LucideIcons.edit2, size: 16),
                        label: const Text('Edit / Add'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        ref
                            .read(vendorMappingProvider.notifier)
                            .addToReviewQueue(VendorMappingEntry(
                                rowNumber: item.rowNumber,
                                vendorDescription: item.vendorDescription,
                                partNumber: item.partNumber,
                                status: 'Skip'));
                      },
                      child: const Text('Skip',
                          style: TextStyle(color: AppTheme.textSecondary)),
                    )
                  ],
                )
            ]));
      },
    );
  }

  void _showEditItemSheet(
      BuildContext context, WidgetRef ref, VendorMappingExportItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _VendorMappingEditSheet(item: item),
    );
  }

  // --- 2. Upload Tab ---
  Widget _buildUploadTab(
      BuildContext context, WidgetRef ref, VendorMappingState state) {
    final notifier = ref.read(vendorMappingProvider.notifier);

    return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.info,
                          color: Colors.amber.shade800, size: 20),
                      const SizedBox(width: 8),
                      Text('Upload Scanned Sheets',
                          style: TextStyle(
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload photos of your completed mapping sheets. Our AI will extract the data automatically.',
                    style:
                        TextStyle(color: Colors.amber.shade800, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (state.processingStatus == 'uploading' ||
                state.processingStatus == 'processing')
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 48),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    Text(
                      '${state.processingStatus.toUpperCase()}...',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (state.processingStatus == 'uploading')
                      LinearProgressIndicator(value: state.uploadProgress),
                  ],
                ),
              )
            else ...[
              GestureDetector(
                onTap: () async {
                  final ImagePicker picker = ImagePicker();
                  final List<XFile> images = await picker.pickMultiImage();
                  if (images.isNotEmpty) {
                    notifier.addFiles(images);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.blue.shade200, style: BorderStyle.none),
                  ),
                  child: const Column(
                    children: [
                      Icon(LucideIcons.imagePlus,
                          size: 48, color: AppTheme.primary),
                      SizedBox(height: 16),
                      Text('Tap to select images',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary)),
                    ],
                  ),
                ),
              ),
              if (state.uploadedFiles.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text('Selected Files',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: state.uploadedFiles.asMap().entries.map((entry) {
                    return Chip(
                      label: Text(entry.value.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      onDeleted: () => notifier.removeFile(entry.key),
                      deleteIcon: const Icon(LucideIcons.xCircle, size: 18),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => notifier.uploadAndProcessScans(),
                  icon: const Icon(LucideIcons.cpu, color: Colors.white),
                  label: const Text('Process Images',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16))),
                ),
              ]
            ]
          ],
        ));
  }

  // --- 3. Review Tab ---
  Widget _buildReviewTab(
      BuildContext context, WidgetRef ref, VendorMappingState state) {
    if (state.reviewQueue.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.inbox, size: 48, color: AppTheme.textSecondary),
            SizedBox(height: 16),
            Text('No items to review',
                style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: AppTheme.surface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${state.reviewQueue.length} Items Ready',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              ElevatedButton.icon(
                onPressed: () async {
                  final success = await ref
                      .read(vendorMappingProvider.notifier)
                      .bulkSaveReviewQueue();
                  if (!context.mounted) return;
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Items saved successfully')));
                  }
                },
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                icon:
                    const Icon(LucideIcons.save, color: Colors.white, size: 18),
                label: const Text('Save All',
                    style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: state.reviewQueue.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = state.reviewQueue[index];
              return Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                              child: Text(item.vendorDescription,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis)),
                          IconButton(
                            icon: const Icon(LucideIcons.trash2,
                                color: AppTheme.error, size: 20),
                            onPressed: () => ref
                                .read(vendorMappingProvider.notifier)
                                .removeFromReviewQueue(index),
                          )
                        ],
                      ),
                      if (item.partNumber != null)
                        Text('Part #: ${item.partNumber}',
                            style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                fontFamily: 'monospace')),
                      const Divider(height: 24),
                      _buildReviewRow(
                          'Customer Item', item.customerItemName ?? '-'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                              child: _buildReviewRow('Stock Found',
                                  item.stock?.toString() ?? '-')),
                          Expanded(
                              child: _buildReviewRow('Reorder Pt',
                                  item.reorder?.toString() ?? '-')),
                        ],
                      ),
                      if (item.variance != null) ...[
                        const SizedBox(height: 8),
                        _buildReviewRow(
                            'Variance',
                            (item.variance! > 0
                                ? '+${item.variance}'
                                : item.variance.toString()),
                            valueColor:
                                item.variance! > 0 ? Colors.green : Colors.red),
                      ]
                    ]),
              );
            },
          ),
        )
      ],
    );
  }

  Widget _buildReviewRow(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: valueColor ?? AppTheme.textPrimary)),
      ],
    );
  }
}

// Bottom sheet for inline editing
class _VendorMappingEditSheet extends ConsumerStatefulWidget {
  final VendorMappingExportItem item;

  const _VendorMappingEditSheet({required this.item});

  @override
  ConsumerState<_VendorMappingEditSheet> createState() =>
      _VendorMappingEditSheetState();
}

class _VendorMappingEditSheetState
    extends ConsumerState<_VendorMappingEditSheet> {
  late TextEditingController _customerItemCtrl;
  late TextEditingController _stockCtrl;
  late TextEditingController _reorderCtrl;

  @override
  void initState() {
    super.initState();
    _customerItemCtrl =
        TextEditingController(text: widget.item.customerItemName ?? '');
    _stockCtrl =
        TextEditingController(text: widget.item.stock?.toString() ?? '');
    _reorderCtrl =
        TextEditingController(text: widget.item.reorder?.toString() ?? '');
  }

  @override
  void dispose() {
    _customerItemCtrl.dispose();
    _stockCtrl.dispose();
    _reorderCtrl.dispose();
    super.dispose();
  }

  void _save() {
    ref
        .read(vendorMappingProvider.notifier)
        .addToReviewQueue(VendorMappingEntry(
          rowNumber: widget.item.rowNumber,
          vendorDescription: widget.item.vendorDescription,
          partNumber: widget.item.partNumber,
          customerItemName:
              _customerItemCtrl.text.isNotEmpty ? _customerItemCtrl.text : null,
          stock: int.tryParse(_stockCtrl.text),
          reorder: int.tryParse(_reorderCtrl.text),
          status: 'Pending',
        ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Link Customer Item',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(widget.item.vendorDescription,
              style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 24),
          TextField(
            controller: _customerItemCtrl,
            decoration: InputDecoration(
              labelText: 'Customer Item Name (Optional)',
              filled: true,
              fillColor: AppTheme.surface,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _stockCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Stock (Qty)',
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _reorderCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Reorder Point',
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Add to Review',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}
