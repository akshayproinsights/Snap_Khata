import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/context_extension.dart';
import 'package:mobile/features/inventory/domain/models/inventory_models.dart';
import 'package:mobile/features/inventory/presentation/providers/inventory_provider.dart';

class VerifyPartsPage extends ConsumerStatefulWidget {
  const VerifyPartsPage({super.key});

  @override
  ConsumerState<VerifyPartsPage> createState() => _VerifyPartsPageState();
}

class _VerifyPartsPageState extends ConsumerState<VerifyPartsPage> {
  final Set<int> _selectedIds = {};
  String _searchQuery = '';
  String _statusFilter = ''; // '' for all, 'Pending', 'Done'
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(inventoryProvider.notifier).fetchItems(showAll: true));
  }

  void _handleToggleSelect(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _handleSelectAll(List<InventoryItem> items) {
    setState(() {
      if (_selectedIds.length == items.length && items.isNotEmpty) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(items.map((i) => i.id));
      }
    });
  }

  void _handleBulkDelete() async {
    if (_selectedIds.isEmpty) return;

    final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Delete Selected?'),
              content: Text(
                  'Are you sure you want to delete ${_selectedIds.length} items?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: context.errorColor),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ));

    if (confirm == true) {
      ref
          .read(inventoryProvider.notifier)
          .bulkDeleteItems(_selectedIds.toList());
      setState(() => _selectedIds.clear());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryProvider);

    // Apply filtering
    var filteredItems = state.items;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filteredItems = filteredItems
          .where((i) =>
              i.partNumber.toLowerCase().contains(q) ||
              i.description.toLowerCase().contains(q) ||
              i.invoiceNumber.toLowerCase().contains(q) ||
              (i.vendorName?.toLowerCase().contains(q) ?? false))
          .toList();
    }

    if (_statusFilter.isNotEmpty) {
      filteredItems = filteredItems.where((i) {
        final status = i.amountMismatch == 0
            ? 'Done'
            : (i.verificationStatus ?? 'Pending');
        return status.toLowerCase() == _statusFilter.toLowerCase();
      }).toList();
    }

    // Sort: Pending first
    filteredItems.sort((a, b) {
      final statusA =
          a.amountMismatch == 0 ? 'Done' : (a.verificationStatus ?? 'Pending');
      final statusB =
          b.amountMismatch == 0 ? 'Done' : (b.verificationStatus ?? 'Pending');
      if (statusA != statusB) {
        return statusA == 'Pending' ? -1 : 1;
      }
      return (b.uploadDate ?? '').compareTo(a.uploadDate ?? '');
    });

    final isAllSelected =
        _selectedIds.length == filteredItems.length && filteredItems.isNotEmpty;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: const Text('Verify Parts'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.filter),
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
          IconButton(
            icon: const Icon(LucideIcons.download),
            onPressed: () {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Exporting...')));
              // Export logic later
            },
          )
        ],
      ),
      body: Column(
        children: [
          if (_showFilters) _buildFiltersRow(),
          if (_selectedIds.isNotEmpty)
            Container(
              color: context.primaryColor.withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_selectedIds.length} Selected',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: context.primaryColor)),
                  TextButton.icon(
                      onPressed: _handleBulkDelete,
                      icon: Icon(LucideIcons.trash2,
                          size: 18, color: context.errorColor),
                      label: Text('Delete',
                          style: TextStyle(color: context.errorColor)))
                ],
              ),
            ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Checkbox(
                    value: isAllSelected,
                    onChanged: (_) => _handleSelectAll(filteredItems)),
                Text('Select All',
                    style: TextStyle(
                        color: context.textSecondaryColor,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${filteredItems.length} items',
                    style: TextStyle(color: context.textSecondaryColor)),
              ],
            ),
          ),
          Expanded(
            child: state.isLoading && state.items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => ref
                        .read(inventoryProvider.notifier)
                        .fetchItems(showAll: true),
                    child: filteredItems.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: 100),
                              Center(
                                  child: Text('No items found',
                                      style: TextStyle(
                                          color: context.textSecondaryColor))),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredItems.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              return _buildInventoryCard(filteredItems[index]);
                            },
                          ),
                  ),
          )
        ],
      ),
    );
  }

  Widget _buildFiltersRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(bottom: BorderSide(color: context.borderColor)),
      ),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search invoice lines...',
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              isDense: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: '', label: Text('All')),
                    ButtonSegment(value: 'Pending', label: Text('Pending')),
                    ButtonSegment(value: 'Done', label: Text('Done')),
                  ],
                  selected: {_statusFilter},
                  onSelectionChanged: (set) =>
                      setState(() => _statusFilter = set.first),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildInventoryCard(InventoryItem item) {
    final isSelected = _selectedIds.contains(item.id);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isSelected ? context.primaryColor : context.borderColor,
            width: isSelected ? 2 : 1),
        boxShadow: context.premiumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: context.isDark ? context.surfaceColor : context.borderColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15), topRight: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: context.borderColor)),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => _handleToggleSelect(item.id),
                  visualDensity: VisualDensity.compact,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Invoice #${item.invoiceNumber}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(
                          '${item.invoiceDate} • ${item.vendorName ?? "Unknown Vendor"}',
                          style: TextStyle(
                              color: context.textSecondaryColor, fontSize: 11)),
                    ],
                  ),
                ),
                if (item.amountMismatch > 0)
                  Icon(LucideIcons.alertTriangle,
                      color: context.errorColor, size: 16)
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildInlineField(
                        label: 'Part #',
                        initialValue: item.partNumber,
                        onSubmitted: (v) => ref
                            .read(inventoryProvider.notifier)
                            .updateItem(item.id, {'part_number': v}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: _buildInlineField(
                        label: 'Description',
                        initialValue: item.description,
                        onSubmitted: (v) => ref
                            .read(inventoryProvider.notifier)
                            .updateItem(item.id, {'description': v}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInlineField(
                        label: 'Qty',
                        initialValue: item.quantity.toString(),
                        isNumber: true,
                        onSubmitted: (v) => ref
                            .read(inventoryProvider.notifier)
                            .updateItem(
                                item.id, {'quantity': double.tryParse(v) ?? 0}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInlineField(
                        label: 'Rate',
                        initialValue: item.rate.toString(),
                        isNumber: true,
                        onSubmitted: (v) => ref
                            .read(inventoryProvider.notifier)
                            .updateItem(
                                item.id, {'rate': double.tryParse(v) ?? 0}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInlineField(
                        label: 'Net Order',
                        initialValue: item.netBill.toString(),
                        isNumber: true,
                        onSubmitted: (v) => ref
                            .read(inventoryProvider.notifier)
                            .updateItem(
                                item.id, {'net_bill': double.tryParse(v) ?? 0}),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: context.borderColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      item.verificationStatus == 'Done'
                          ? LucideIcons.checkCircle2
                          : LucideIcons.clock,
                      size: 16,
                      color: item.verificationStatus == 'Done'
                          ? context.successColor
                          : context.primaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(item.verificationStatus ?? 'Pending',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: item.verificationStatus == 'Done'
                                ? context.successColor
                                : context.primaryColor)),
                  ],
                ),
                Row(
                  children: [
                    if (item.rowAccuracy != null)
                      Text(
                          'Acc: ${(item.rowAccuracy! * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                              fontSize: 11, color: context.textSecondaryColor)),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: Icon(LucideIcons.trash2,
                          size: 18, color: context.errorColor),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => ref
                          .read(inventoryProvider.notifier)
                          .deleteItem(item.id),
                    )
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInlineField(
      {required String label,
      required String initialValue,
      required Function(String) onSubmitted,
      bool isNumber = false}) {
    return TextFormField(
      initialValue: initialValue,
      style: const TextStyle(fontSize: 13),
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      ),
      onFieldSubmitted: (v) {
        if (v != initialValue) onSubmitted(v);
      },
    );
  }
}
