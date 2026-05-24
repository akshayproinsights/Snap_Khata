import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/udhar/domain/models/udhar_models.dart';
import 'package:mobile/features/udhar/presentation/providers/item_catalogue_provider.dart';
import 'package:mobile/shared/widgets/app_toast.dart';

class ItemCataloguePage extends ConsumerStatefulWidget {
  const ItemCataloguePage({super.key});

  @override
  ConsumerState<ItemCataloguePage> createState() => _ItemCataloguePageState();
}

class _ItemCataloguePageState extends ConsumerState<ItemCataloguePage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleSync() async {
    setState(() {
      _isSyncing = true;
    });
    try {
      final res = await ref.read(itemCatalogueProvider.notifier).syncFromBills();
      if (!mounted) return;
      if (res['success'] == true) {
        AppToast.showSuccess(
          context,
          'Synced ${res['synced_count']} items from your bills!',
        );
      } else {
        AppToast.showError(context, res['message'] ?? 'Failed to sync');
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Sync failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  void _showAddEditItemDialog({CatalogueItem? item}) {
    final nameController = TextEditingController(text: item?.itemName ?? '');
    final priceController = TextEditingController(
      text: item != null ? item.lastPrice.toStringAsFixed(0) : '',
    );
    String selectedUnit = item?.unit ?? 'NOS';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: context.surfaceColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: context.borderColor, width: 0.5),
              ),
              title: Text(
                item == null ? 'Add New Item' : 'Edit Item',
                style: TextStyle(
                  color: context.textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: context.textColor),
                    decoration: InputDecoration(
                      labelText: 'Item Name',
                      labelStyle: TextStyle(color: context.textSecondaryColor),
                      hintText: 'e.g. Sugar',
                      hintStyle: TextStyle(color: context.textSecondaryColor),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: context.borderColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: context.primaryColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(color: context.textColor),
                    decoration: InputDecoration(
                      labelText: 'Price (₹)',
                      labelStyle: TextStyle(color: context.textSecondaryColor),
                      hintText: 'e.g. 52',
                      hintStyle: TextStyle(color: context.textSecondaryColor),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: context.borderColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: context.primaryColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Unit',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['NOS', 'KG', 'LITRE', 'BOX', 'PACKET'].map((u) {
                      final isSelected = selectedUnit == u;
                      return ChoiceChip(
                        label: Text(u),
                        selected: isSelected,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : context.textColor,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        selectedColor: context.primaryColor,
                        backgroundColor: context.surfaceColor,
                        side: BorderSide(
                          color: isSelected
                              ? context.primaryColor
                              : context.borderColor,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setStateDialog(() {
                              selectedUnit = u;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: context.textSecondaryColor),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final priceStr = priceController.text.trim();
                    if (name.isEmpty) {
                      AppToast.showError(ctx, 'Item name cannot be empty');
                      return;
                    }
                    final price = double.tryParse(priceStr) ?? 0.0;

                    bool success;
                    if (item == null) {
                      success = await ref
                          .read(itemCatalogueProvider.notifier)
                          .addItem(name, price, selectedUnit);
                    } else {
                      success = await ref
                          .read(itemCatalogueProvider.notifier)
                          .updateItem(item.id, name, price, selectedUnit);
                    }

                    if (!context.mounted) return;
                    if (success) {
                      Navigator.pop(ctx);
                      AppToast.showSuccess(
                        context,
                        item == null
                            ? 'Item added to catalogue'
                            : 'Item details updated',
                      );
                    } else {
                      if (!ctx.mounted) return;
                      AppToast.showError(ctx, 'Failed to save item');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteItem(CatalogueItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: context.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: context.borderColor, width: 0.5),
          ),
          title: Text(
            'Delete Item?',
            style: TextStyle(
              color: context.textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to remove "${item.itemName}" from your catalogue?',
            style: TextStyle(color: context.textSecondaryColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: context.textSecondaryColor),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.errorColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final success = await ref
          .read(itemCatalogueProvider.notifier)
          .deleteItem(item.id);
      if (!mounted) return;
      if (success) {
        AppToast.showSuccess(context, 'Item deleted');
      } else {
        AppToast.showError(context, 'Failed to delete item');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(itemCatalogueProvider);

    // Apply filtering client-side
    final filteredItems = state.items.where((item) {
      if (_searchQuery.isEmpty) return true;
      return item.itemName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text(
          'My Item Catalogue',
          style: TextStyle(
            color: context.textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.grey),
                  ),
                )
                : const Icon(LucideIcons.refreshCw),
            tooltip: 'Sync from bills',
            onPressed: _isSyncing ? null : _handleSync,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search & Info Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  style: TextStyle(color: context.textColor),
                  decoration: InputDecoration(
                    hintText: 'Search items...',
                    hintStyle: TextStyle(
                      color: context.textSecondaryColor,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      LucideIcons.search,
                      color: context.textSecondaryColor,
                      size: 20,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(LucideIcons.x, size: 16),
                          onPressed: () => _searchController.clear(),
                        )
                        : null,
                    filled: true,
                    fillColor: context.surfaceColor,
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: context.borderColor,
                        width: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: context.primaryColor),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                // Item count + sort info row
                if (state.items.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${state.items.length} items',
                          style: TextStyle(
                            color: context.primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        LucideIcons.arrowDownUp,
                        size: 12,
                        color: context.textSecondaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Sorted by most used',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Main List or Empty State
          Expanded(
            child: Builder(
              builder: (ctx) {
                if (state.isLoading && state.items.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: context.primaryColor.withValues(
                                alpha: 0.1,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              LucideIcons.shoppingBag,
                              size: 48,
                              color: context.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Add Your Products & Prices',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: context.textColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Set your item name and price once here.\nThey will auto-fill when you create bills — no re-typing needed!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: context.textSecondaryColor,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _handleSync,
                                icon: const Icon(LucideIcons.sparkles, size: 16),
                                label: const Text('Sync From Bills'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: context.primaryColor,
                                  side: BorderSide(color: context.primaryColor),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: () => _showAddEditItemDialog(),
                                icon: const Icon(LucideIcons.plus, size: 16),
                                label: const Text('Add Item'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: context.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (filteredItems.isEmpty) {
                  return Center(
                    child: Text(
                      'No matching items found',
                      style: TextStyle(color: context.textSecondaryColor),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: context.borderColor,
                          width: 0.5,
                        ),
                        boxShadow: context.premiumShadow,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        title: Text(
                          item.itemName,
                          style: TextStyle(
                            color: context.textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Used ${item.useCount} times${item.lastUsedAt != null ? ' · last: ${_timeAgo(item.lastUsedAt!)}' : ''}',
                            style: TextStyle(
                              color: context.textSecondaryColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${item.lastPrice.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: context.primaryColor,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  'per ${item.unit} • Your Price',
                                  style: TextStyle(
                                    color: context.textSecondaryColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 4),
                            PopupMenuButton<String>(
                              icon: Icon(
                                LucideIcons.moreVertical,
                                color: context.textSecondaryColor,
                                size: 20,
                              ),
                              onSelected: (val) {
                                if (val == 'edit') {
                                  _showAddEditItemDialog(item: item);
                                } else if (val == 'delete') {
                                  _deleteItem(item);
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(LucideIcons.edit, size: 16),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        LucideIcons.trash2,
                                        size: 16,
                                        color: context.errorColor,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Delete',
                                        style: TextStyle(
                                          color: context.errorColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () => _showAddEditItemDialog(item: item),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: context.primaryColor,
        foregroundColor: Colors.white,
        child: const Icon(LucideIcons.plus),
        onPressed: () => _showAddEditItemDialog(),
      ),
    );
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 365) {
      return '${(diff.inDays / 365).floor()}y ago';
    } else if (diff.inDays > 30) {
      return '${(diff.inDays / 30).floor()}mo ago';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }
}
