import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/widgets/editable_qty_stepper.dart';
import 'package:mobile/features/udhar/domain/models/udhar_models.dart';
import 'package:mobile/features/udhar/presentation/providers/item_catalogue_provider.dart';
import 'package:mobile/shared/widgets/app_toast.dart';
import 'package:mobile/shared/widgets/qty_numpad_sheet.dart';

// ── Cart result model — returned to caller in selection mode ──────────────────
class CatalogueCartItem {
  final String name;
  final double rate;
  final String unit;
  final int qty;

  const CatalogueCartItem({
    required this.name,
    required this.rate,
    required this.unit,
    required this.qty,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'rate': rate,
        'unit': unit,
        'qty': qty,
      };
}

class ItemCataloguePage extends ConsumerStatefulWidget {
  /// When [selectionMode] is true the page acts as a cart picker.
  /// When false (default) it's the standard add/edit/delete catalogue manager.
  final bool selectionMode;

  const ItemCataloguePage({
    super.key,
    this.selectionMode = false,
  });

  @override
  ConsumerState<ItemCataloguePage> createState() => _ItemCataloguePageState();
}

class _ItemCataloguePageState extends ConsumerState<ItemCataloguePage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSyncing = false;
  late AnimationController _fabAnimController;
  int? _highlightedItemId;

  // ── Cart state (selection mode only) ─────────────────────────────────────
  final Map<int, int> _cartQty = {};

  // ── Multi-select delete state ─────────────────────────────────────────────
  bool _isMultiSelectMode = false;
  final Set<int> _selectedItemIds = {};


  int get _totalCartItems => _cartQty.values.fold(0, (sum, q) => sum + q);

  double _cartTotal(List<CatalogueItem> allItems) {
    double total = 0;
    for (final item in allItems) {
      final qty = _cartQty[item.id] ?? 0;
      if (qty > 0) total += item.lastPrice * qty;
    }
    return total;
  }

  void _incrementCart(int itemId) {
    HapticFeedback.lightImpact();
    setState(() => _cartQty[itemId] = (_cartQty[itemId] ?? 0) + 1);
  }

  void _decrementCart(int itemId) {
    HapticFeedback.lightImpact();
    setState(() {
      final current = _cartQty[itemId] ?? 0;
      if (current <= 1) {
        _cartQty.remove(itemId);
      } else {
        _cartQty[itemId] = current - 1;
      }
    });
  }

  void _addToCartWithQty(int itemId, int qty) {
    setState(() => _cartQty[itemId] = qty);
  }

  /// Opens the qty numpad directly — bypasses the inline +1 stepper.
  Future<void> _openQtyNumpad(CatalogueItem item) async {
    HapticFeedback.mediumImpact();
    final current = _cartQty[item.id] ?? 0;
    final isDecimal =
        item.unit == 'KG' || item.unit == 'LITRE' || item.unit == 'L';
    final result = await showModalBottomSheet<num>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QtyNumpadSheet(
        initial: current.toDouble(),
        itemName: item.itemName,
        rate: item.lastPrice,
        unit: item.unit,
        isDecimal: isDecimal,
      ),
    );
    if (result != null) {
      if (result > 0) {
        _addToCartWithQty(item.id, result.toInt());
      } else {
        setState(() => _cartQty.remove(item.id));
      }
    }
  }

  void _enterMultiSelectMode(int firstItemId) {
    HapticFeedback.heavyImpact();
    setState(() {
      _isMultiSelectMode = true;
      _selectedItemIds.add(firstItemId);
    });
  }

  void _exitMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = false;
      _selectedItemIds.clear();
    });
  }

  void _toggleItemSelection(int itemId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedItemIds.contains(itemId)) {
        _selectedItemIds.remove(itemId);
        if (_selectedItemIds.isEmpty) _isMultiSelectMode = false;
      } else {
        _selectedItemIds.add(itemId);
      }
    });
  }

  Future<void> _bulkDeleteSelected() async {
    if (_selectedItemIds.isEmpty) return;
    final count = _selectedItemIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: context.borderColor, width: 0.5),
        ),
        title: Text(
          'Remove $count item${count == 1 ? '' : 's'}?',
          style: TextStyle(
              color: context.textColor, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'These items will be permanently removed from your catalogue.',
          style: TextStyle(color: context.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: context.textSecondaryColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.errorColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Remove $count'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final ids = List<int>.from(_selectedItemIds);
      int removed = 0;
      for (final id in ids) {
        final ok =
            await ref.read(itemCatalogueProvider.notifier).deleteItem(id);
        if (ok) {
          removed++;
          _cartQty.remove(id);
        }
      }
      if (!mounted) return;
      _exitMultiSelectMode();
      AppToast.showSuccess(
          context, '$removed item${removed == 1 ? '' : 's'} removed');
    }
  }

  /// Pops the page and returns the selected items to the caller.
  void _confirmCart(List<CatalogueItem> allItems) {
    if (_cartQty.isEmpty) {
      AppToast.showError(context, 'Add at least one item');
      return;
    }
    final result = <CatalogueCartItem>[];
    for (final item in allItems) {
      final qty = _cartQty[item.id] ?? 0;
      if (qty > 0) {
        result.add(CatalogueCartItem(
          name: item.itemName,
          rate: item.lastPrice,
          unit: item.unit,
          qty: qty,
        ));
      }
    }
    Navigator.pop(context, result);
  }

  @override
  void initState() {
    super.initState();
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fabAnimController.dispose();
    super.dispose();
  }

  void _triggerHighlight(int targetId, String name) {
    if (!mounted) return;
    setState(() {
      _searchController.text = name;
      _highlightedItemId = targetId;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _highlightedItemId = null;
        });
      }
    });
  }

  // ── Quick Add/Edit Bottom Sheet ──────────────────────────────────────────
  void _showQuickAddSheet({
    CatalogueItem? item,
    bool autoAddToCart = false,
    int initialQty = 1,
  }) {
    final nameController = TextEditingController(text: item?.itemName ?? '');
    final priceController = TextEditingController(
      text: item != null ? item.lastPrice.toStringAsFixed(0) : '',
    );
    String selectedUnit = item?.unit ?? 'NOS';
    int qty = initialQty;
    final nameFocus = FocusNode();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: context.backgroundColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 30,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 4),
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: context.borderColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: context.primaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              item == null
                                  ? LucideIcons.packagePlus
                                  : LucideIcons.packageCheck,
                              size: 20,
                              color: context.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            item == null ? 'New Custom Item' : 'Edit Item',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: context.textColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(LucideIcons.x,
                                color: context.textSecondaryColor),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Item Name
                          TextField(
                            controller: nameController,
                            focusNode: nameFocus,
                            autofocus: true,
                            textCapitalization: TextCapitalization.words,
                            style: TextStyle(
                              color: context.textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Item Name',
                              hintText: 'e.g. Sugar, Rice, Engine Oil...',
                              labelStyle: TextStyle(
                                  color: context.textSecondaryColor),
                              hintStyle:
                                  TextStyle(color: context.textSecondaryColor),
                              prefixIcon: Icon(LucideIcons.tag,
                                  size: 18, color: context.primaryColor),
                              filled: true,
                              fillColor: context.surfaceColor,
                              enabledBorder: OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: context.borderColor),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: context.primaryColor, width: 1.5),
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Price + Unit row
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: priceController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d*\.?\d{0,2}')),
                                  ],
                                  style: TextStyle(
                                    color: context.textColor,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Price (₹)',
                                    hintText: '0',
                                    labelStyle: TextStyle(
                                        color: context.textSecondaryColor),
                                    hintStyle: TextStyle(
                                        color: context.textSecondaryColor),
                                    prefixIcon: Icon(LucideIcons.indianRupee,
                                        size: 18,
                                        color: context.primaryColor),
                                    filled: true,
                                    fillColor: context.surfaceColor,
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                          color: context.borderColor),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                          color: context.primaryColor,
                                          width: 1.5),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Unit picker
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: context.surfaceColor,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: context.borderColor),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedUnit,
                                    dropdownColor: context.surfaceColor,
                                    style: TextStyle(
                                      color: context.textColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    items: [
                                      'NOS',
                                      'KG',
                                      'LITRE',
                                      'BOX',
                                      'PACKET',
                                      'BAG'
                                    ]
                                        .map((u) => DropdownMenuItem(
                                              value: u,
                                              child: Text(u),
                                            ))
                                        .toList(),
                                    onChanged: (u) {
                                      if (u != null) {
                                        setSheetState(
                                            () => selectedUnit = u);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Qty stepper (in selection mode or when autoAddToCart)
                          if (widget.selectionMode || autoAddToCart) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Text(
                                  'Quantity',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: context.textSecondaryColor,
                                  ),
                                ),
                                const Spacer(),
                                EditableQtyStepper(
                                  qty: qty,
                                  itemName: nameController.text.trim().isEmpty ? 'Custom Item' : nameController.text.trim(),
                                  rate: double.tryParse(priceController.text.trim()) ?? 0.0,
                                  unit: selectedUnit,
                                  onChanged: (newQty) {
                                    setSheetState(() {
                                      qty = newQty.toInt();
                                    });
                                  },
                                  onDecrement: () {
                                    if (qty > 1) {
                                      setSheetState(() {
                                        qty--;
                                      });
                                    }
                                  },
                                  onIncrement: () {
                                    setSheetState(() {
                                      qty++;
                                    });
                                  },
                                  showTrashAtOne: false,
                                  isDecimal: false,
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 20),

                          // ── Action Buttons ──────────────────────────────
                          if (widget.selectionMode) ...[
                            // NEW item → Save & Add to Bill
                            // EDIT existing → Save Changes (no cart add)
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final name =
                                      nameController.text.trim();
                                  if (name.isEmpty) {
                                    AppToast.showError(
                                        ctx, 'Enter item name');
                                    return;
                                  }
                                  final price = double.tryParse(
                                          priceController.text.trim()) ??
                                      0.0;

                                  bool success;
                                  int targetId = -1;
                                  if (item == null) {
                                    // Creating NEW item → add to cart
                                    success = await ref
                                        .read(
                                            itemCatalogueProvider.notifier)
                                        .addItem(name, price, selectedUnit);
                                    if (success) {
                                      final items = ref
                                          .read(itemCatalogueProvider)
                                          .items;
                                      final match = items.where((i) =>
                                          i.itemName.toLowerCase() ==
                                          name.toLowerCase());
                                      if (match.isNotEmpty) {
                                        targetId = match.first.id;
                                      }
                                    }
                                    if (!ctx.mounted) return;
                                    if (success && targetId != -1) {
                                      _addToCartWithQty(targetId, qty);
                                      Navigator.pop(ctx);
                                      _triggerHighlight(targetId, name);
                                      AppToast.showSuccess(
                                          context,
                                          '✅ "$name" added to bill (qty $qty)');
                                    } else {
                                      AppToast.showError(
                                          context, 'Failed to save item');
                                    }
                                  } else {
                                    // Editing EXISTING item → just save, stay in list
                                    success = await ref
                                        .read(
                                            itemCatalogueProvider.notifier)
                                        .updateItem(
                                            item.id, name, price, selectedUnit);
                                    targetId = item.id;
                                    if (!ctx.mounted) return;
                                    Navigator.pop(ctx);
                                    if (success) {
                                      _triggerHighlight(targetId, name);
                                      AppToast.showSuccess(
                                          context, '✅ "$name" updated');
                                    } else {
                                      AppToast.showError(
                                          context, 'Failed to update item');
                                    }
                                  }
                                },
                                icon: Icon(
                                  item == null
                                      ? LucideIcons.shoppingCart
                                      : LucideIcons.check,
                                  size: 18,
                                ),
                                label: Text(
                                  item == null
                                      ? 'Save & Add to Bill'
                                      : 'Save Changes',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: context.primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          ] else ...[
                            // Management mode: just save
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final name =
                                      nameController.text.trim();
                                  if (name.isEmpty) {
                                    AppToast.showError(
                                        ctx, 'Enter item name');
                                    return;
                                  }
                                  final price = double.tryParse(
                                          priceController.text.trim()) ??
                                      0.0;

                                  bool success;
                                  int targetId = -1;
                                  if (item == null) {
                                    success = await ref
                                        .read(
                                            itemCatalogueProvider.notifier)
                                        .addItem(
                                            name, price, selectedUnit);
                                    if (success) {
                                      final items = ref
                                          .read(itemCatalogueProvider)
                                          .items;
                                      final match = items.where((i) =>
                                          i.itemName.toLowerCase() ==
                                          name.toLowerCase());
                                      if (match.isNotEmpty) {
                                        targetId = match.first.id;
                                      }
                                    }
                                  } else {
                                    success = await ref
                                        .read(
                                            itemCatalogueProvider.notifier)
                                        .updateItem(item.id, name, price,
                                            selectedUnit);
                                    targetId = item.id;
                                  }

                                  if (!ctx.mounted) return;
                                  Navigator.pop(ctx);
                                  if (success && targetId != -1) {
                                    _triggerHighlight(targetId, name);
                                    AppToast.showSuccess(
                                      context,
                                      item == null
                                          ? '✅ "$name" added'
                                          : '✅ Item updated',
                                    );
                                  } else {
                                    AppToast.showError(
                                        context, 'Failed to save item');
                                  }
                                },
                                icon: Icon(
                                  item == null
                                      ? LucideIcons.plus
                                      : LucideIcons.check,
                                  size: 18,
                                ),
                                label: Text(
                                  item == null
                                      ? 'Add to My Items'
                                      : 'Save Changes',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: context.primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleSync() async {
    setState(() => _isSyncing = true);
    try {
      final res =
          await ref.read(itemCatalogueProvider.notifier).syncFromBills();
      if (!mounted) return;
      if (res['success'] == true) {
        AppToast.showSuccess(
          context,
          '✅ Synced ${res['synced_count']} items from your bills!',
        );
      } else {
        AppToast.showError(context, res['message'] ?? 'Failed to sync');
      }
    } catch (e) {
      if (mounted) AppToast.showError(context, 'Sync failed: $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _deleteItem(CatalogueItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: context.borderColor, width: 0.5),
        ),
        title: Text(
          'Remove "${item.itemName}"?',
          style: TextStyle(
              color: context.textColor, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'It will no longer appear in your quick items.',
          style: TextStyle(color: context.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: context.textSecondaryColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.errorColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ref
          .read(itemCatalogueProvider.notifier)
          .deleteItem(item.id);
      if (!mounted) return;
      if (success) {
        AppToast.showSuccess(context, 'Item removed');
        _cartQty.remove(item.id);
      } else {
        AppToast.showError(context, 'Failed to remove item');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(itemCatalogueProvider);

    final filteredItems = state.items.where((item) {
      if (_searchQuery.isEmpty) return true;
      return item.itemName
          .toLowerCase()
          .contains(_searchQuery.toLowerCase());
    }).toList();

    final hasItems = state.items.isNotEmpty;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: _buildAppBar(context, state, hasItems),
      body: Column(
        children: [
          // ── Search + Add button strip ─────────────────────────────────
          _buildTopStrip(context),

          // ── Main content ─────────────────────────────────────────────
          Expanded(
            child: Builder(builder: (ctx) {
              if (state.isLoading && state.items.isEmpty) {
                return Center(
                    child: CircularProgressIndicator(
                        color: context.primaryColor));
              }
              if (state.items.isEmpty) return _buildEmptyState();
              if (filteredItems.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.searchX,
                          size: 40,
                          color: context.textSecondaryColor
                              .withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Text(
                        'No items match "$_searchQuery"',
                        style:
                            TextStyle(color: context.textSecondaryColor),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () => _showQuickAddSheet(),
                        icon: const Icon(LucideIcons.plus, size: 16),
                        label: Text(
                            'Add "${_searchController.text.trim()}"'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  if (widget.selectionMode) {
                    return _SelectionItemCard(
                      item: item,
                      qty: _cartQty[item.id] ?? 0,
                      onOpenNumpad: () => _openQtyNumpad(item),
                      onIncrement: () => _incrementCart(item.id),
                      onDecrement: () => _decrementCart(item.id),
                      onQtyChanged: (newQty) => _addToCartWithQty(item.id, newQty.toInt()),
                      onEdit: () => _showQuickAddSheet(item: item),
                      highlighted: _highlightedItemId == item.id,
                      isMultiSelectMode: _isMultiSelectMode,
                      isSelected: _selectedItemIds.contains(item.id),
                      onLongPress: () => _enterMultiSelectMode(item.id),
                      onToggleSelect: () => _toggleItemSelection(item.id),
                    );
                  }
                  return _ManageItemCard(
                    item: item,
                    onEdit: () => _showQuickAddSheet(item: item),
                    onDelete: () => _deleteItem(item),
                    highlighted: _highlightedItemId == item.id,
                    isMultiSelectMode: _isMultiSelectMode,
                    isSelected: _selectedItemIds.contains(item.id),
                    onLongPress: () => _enterMultiSelectMode(item.id),
                    onToggleSelect: () => _toggleItemSelection(item.id),
                  );
                },
              );
            }),
          ),
        ],
      ),

      // ── Bottom CTA ────────────────────────────────────────────────────
      bottomNavigationBar: widget.selectionMode
          ? _buildSelectionBottomBar(state.items)
          : hasItems
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SizedBox(
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(LucideIcons.checkCircle, size: 18),
                        label: const Text('Done',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ),
                )
              : null,

      floatingActionButton: !hasItems
          ? ScaleTransition(
              scale: CurvedAnimation(
                parent: _fabAnimController,
                curve: Curves.elasticOut,
              ),
              child: FloatingActionButton.extended(
                onPressed: () => _showQuickAddSheet(),
                backgroundColor: context.primaryColor,
                foregroundColor: Colors.white,
                icon: const Icon(LucideIcons.plus),
                label: const Text('Add First Item',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          : null,
    );
  }

  // ── App bar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(
      BuildContext context, ItemCatalogueState state, bool hasItems) {
    final cartCount = _totalCartItems;

    // Multi-select mode — show count + bulk delete
    if (_isMultiSelectMode) {
      final selCount = _selectedItemIds.length;
      return AppBar(
        backgroundColor: context.errorColor.withValues(alpha: 0.08),
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.x, color: context.textColor),
          onPressed: _exitMultiSelectMode,
          tooltip: 'Cancel selection',
        ),
        title: Text(
          '$selCount item${selCount == 1 ? '' : 's'} selected',
          style: TextStyle(
            color: context.textColor,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        actions: [
          if (selCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                onPressed: _bulkDeleteSelected,
                icon: const Icon(LucideIcons.trash2, size: 16),
                label: Text('Delete $selCount'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.errorColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ],
      );
    }

    return AppBar(
      backgroundColor: context.backgroundColor,
      elevation: 0,
      leading: IconButton(
        icon: Icon(LucideIcons.arrowLeft, color: context.textColor),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.selectionMode ? 'Select Items' : 'My Items',
            style: TextStyle(
              color: context.textColor,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: -0.5,
            ),
          ),
          if (hasItems)
            Text(
              widget.selectionMode
                  ? '${state.items.length} items · tap to add to bill'
                  : '${state.items.length} items · tap to edit',
              style: TextStyle(
                color: context.textSecondaryColor,
                fontSize: 11,
              ),
            ),
        ],
      ),
      actions: [
        if (widget.selectionMode && cartCount > 0)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: context.primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.shoppingCart,
                        size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      '$cartCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (!widget.selectionMode)
          IconButton(
            icon: _isSyncing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                          context.textSecondaryColor),
                    ),
                  )
                : Icon(LucideIcons.refreshCw,
                    color: context.textSecondaryColor, size: 20),
            tooltip: 'Sync from bills',
            onPressed: _isSyncing ? null : _handleSync,
          ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Top strip: search + add button ─────────────────────────────────────────
  Widget _buildTopStrip(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: context.borderColor, width: 0.5),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: context.textColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search items...',
                  hintStyle: TextStyle(
                    color: context.textSecondaryColor,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(LucideIcons.search,
                      color: context.textSecondaryColor, size: 16),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(LucideIcons.x, size: 14),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _showQuickAddSheet(),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    context.primaryColor,
                    context.primaryColor.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color:
                        context.primaryColor.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(LucideIcons.plus, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Add Item',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty state ─────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    context.primaryColor.withValues(alpha: 0.15),
                    context.primaryColor.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.shoppingBag,
                  size: 52, color: context.primaryColor),
            ),
            const SizedBox(height: 24),
            Text(
              widget.selectionMode
                  ? 'No Items Yet'
                  : 'Set Your Products & Prices',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: context.textColor,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              widget.selectionMode
                  ? 'Add your first item below to include it in this bill.'
                  : 'Add your items once.\nThey\'ll auto-fill every time you make a bill.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.textSecondaryColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _showQuickAddSheet(),
                icon: const Icon(LucideIcons.plus, size: 18),
                label: const Text('Add First Item',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _isSyncing ? null : _handleSync,
                icon: _isSyncing
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.primaryColor),
                      )
                    : const Icon(LucideIcons.sparkles, size: 16),
                label: Text(
                  _isSyncing ? 'Syncing...' : 'Auto-Import from My Bills',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.primaryColor,
                  side: BorderSide(color: context.primaryColor),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Selection mode bottom bar ───────────────────────────────────────────────
  Widget _buildSelectionBottomBar(List<CatalogueItem> allItems) {
    final count = _totalCartItems;
    final total = _cartTotal(allItems);
    final hasCart = count > 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          height: 62,
          child: ElevatedButton(
            onPressed: hasCart ? () => _confirmCart(allItems) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  hasCart ? context.primaryColor : context.borderColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  hasCart
                      ? LucideIcons.arrowRight
                      : LucideIcons.shoppingBag,
                  size: 18,
                ),
                const SizedBox(width: 10),
                if (hasCart) ...[
                  Text(
                    'Proceed to Billing',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$count item${count == 1 ? '' : 's'} · ₹${total.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ] else
                  const Text(
                    'Tap items to add to bill',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ── Selection Mode Item Card ──────────────────────────────────────────────────
// ══════════════════════════════════════════════════════════════════════════════
class _SelectionItemCard extends StatelessWidget {
  const _SelectionItemCard({
    required this.item,
    required this.qty,
    required this.onOpenNumpad,
    required this.onIncrement,
    required this.onDecrement,
    required this.onQtyChanged,
    required this.onEdit,
    this.highlighted = false,
    this.isMultiSelectMode = false,
    this.isSelected = false,
    this.onLongPress,
    this.onToggleSelect,
  });

  final CatalogueItem item;
  final int qty;
  final VoidCallback onOpenNumpad;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final ValueChanged<int> onQtyChanged;
  final VoidCallback onEdit;
  final bool highlighted;
  final bool isMultiSelectMode;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onToggleSelect;

  bool get _inCart => qty > 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: isMultiSelectMode ? null : onLongPress,
      onTap: isMultiSelectMode ? onToggleSelect : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? context.errorColor.withValues(alpha: 0.07)
              : highlighted
                  ? context.successColor.withValues(alpha: 0.08)
                  : (_inCart
                      ? context.primaryColor.withValues(alpha: 0.06)
                      : context.surfaceColor),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? context.errorColor.withValues(alpha: 0.6)
                : highlighted
                    ? context.successColor
                    : (_inCart
                        ? context.primaryColor.withValues(alpha: 0.45)
                        : context.borderColor),
            width:
                isSelected ? 1.5 : (highlighted ? 2.0 : (_inCart ? 1.5 : 0.5)),
          ),
          boxShadow: highlighted
              ? [
                  BoxShadow(
                    color: context.successColor.withValues(alpha: 0.25),
                    blurRadius: 12,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  )
                ]
              : context.premiumShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Row(
            children: [
              // ── Checkbox (multi-select mode) ──────────────────────────
              if (isMultiSelectMode)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => onToggleSelect?.call(),
                    activeColor: context.errorColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                ),

              // ── LEFT HALF: tap = Edit ─────────────────────────────────
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: isMultiSelectMode ? null : onEdit,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (_inCart) ...[
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: context.primaryColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(
                                item.itemName,
                                style: TextStyle(
                                  color: context.textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Pencil badge — 28×28, clearly visible
                            if (!isMultiSelectMode) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: context.borderColor
                                      .withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  LucideIcons.pencil,
                                  size: 14,
                                  color: context.textSecondaryColor,
                                ),
                              ),
                            ],
                            if (highlighted) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: context.successColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(LucideIcons.check,
                                        size: 10, color: Colors.white),
                                    SizedBox(width: 2),
                                    Text(
                                      'Saved',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '₹${item.lastPrice.toStringAsFixed(0)} per ${item.unit}',
                          style: TextStyle(
                            color: context.primaryColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── RIGHT HALF: Add (→ direct numpad) or stepper ──────────
              if (!isMultiSelectMode)
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
                  child: !_inCart
                      ? GestureDetector(
                          onTap: onOpenNumpad,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              color: context.primaryColor,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: context.primaryColor
                                      .withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.plus,
                                    color: Colors.white, size: 15),
                                SizedBox(width: 4),
                                Text(
                                  'Add',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : EditableQtyStepper(
                          qty: qty,
                          itemName: item.itemName,
                          rate: item.lastPrice,
                          unit: item.unit,
                          isDecimal: item.unit == 'KG' ||
                              item.unit == 'LITRE' ||
                              item.unit == 'L',
                          onChanged: (newQty) => onQtyChanged(newQty.toInt()),
                          onDecrement: onDecrement,
                          onIncrement: onIncrement,
                          showTrashAtOne: true,
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ── Management Mode Item Card ─────────────────────────────────────────────────
// ══════════════════════════════════════════════════════════════════════════════
class _ManageItemCard extends StatelessWidget {
  const _ManageItemCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    this.highlighted = false,
    this.isMultiSelectMode = false,
    this.isSelected = false,
    this.onLongPress,
    this.onToggleSelect,
  });

  final CatalogueItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool highlighted;
  final bool isMultiSelectMode;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onToggleSelect;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isMultiSelectMode ? onToggleSelect : onEdit,
      onLongPress: isMultiSelectMode ? null : onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? context.errorColor.withValues(alpha: 0.07)
              : highlighted
                  ? context.successColor.withValues(alpha: 0.08)
                  : context.surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? context.errorColor.withValues(alpha: 0.6)
                : highlighted
                    ? context.successColor
                    : context.borderColor,
            width: isSelected ? 1.5 : (highlighted ? 2.0 : 0.5),
          ),
          boxShadow: highlighted
              ? [
                  BoxShadow(
                    color: context.successColor.withValues(alpha: 0.25),
                    blurRadius: 12,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  )
                ]
              : context.premiumShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // ── Checkbox (multi-select) ───────────────────────────────
              if (isMultiSelectMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => onToggleSelect?.call(),
                    activeColor: context.errorColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                ),

              // ── Left: name + usage ────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.itemName,
                            style: TextStyle(
                              color: context.textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (highlighted) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: context.successColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.check,
                                    size: 10, color: Colors.white),
                                SizedBox(width: 2),
                                Text(
                                  'Saved',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(LucideIcons.repeat,
                            size: 11,
                            color: context.textSecondaryColor
                                .withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Text(
                          'Used ${item.useCount}×${item.lastUsedAt != null ? ' · last used ${_timeAgo(item.lastUsedAt!)}' : ''}',
                          style: TextStyle(
                            color: context.textSecondaryColor,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // ── Right: price + menu ───────────────────────────────────
              if (!isMultiSelectMode) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${item.lastPrice.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: context.primaryColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      'per ${item.unit}',
                      style: TextStyle(
                          color: context.textSecondaryColor, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: Icon(LucideIcons.moreVertical,
                      color: context.textSecondaryColor, size: 18),
                  onSelected: (val) {
                    if (val == 'edit') onEdit();
                    if (val == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(LucideIcons.edit, size: 14),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(LucideIcons.trash2,
                            size: 14, color: Colors.red),
                        const SizedBox(width: 8),
                        const Text('Remove',
                            style: TextStyle(color: Colors.red)),
                      ]),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}
