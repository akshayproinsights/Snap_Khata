import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _ItemCataloguePageState extends ConsumerState<ItemCataloguePage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSyncing = false;
  late AnimationController _fabAnimController;

  @override
  void initState() {
    super.initState();
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fabAnimController.dispose();
    super.dispose();
  }

  // ── Quick Add Bottom Sheet ──────────────────────────────────────────────────
  void _showQuickAddSheet({CatalogueItem? item}) {
    final nameController = TextEditingController(text: item?.itemName ?? '');
    final priceController = TextEditingController(
      text: item != null ? item.lastPrice.toStringAsFixed(0) : '',
    );
    String selectedUnit = item?.unit ?? 'NOS';
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
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
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
                              color:
                                  context.primaryColor.withValues(alpha: 0.12),
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
                            item == null ? 'Add New Item' : 'Edit Item',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: context.textColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(LucideIcons.x, color: context.textSecondaryColor),
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
                              hintText: 'e.g. Sugar, Rice, Engine Oil…',
                              labelStyle:
                                  TextStyle(color: context.textSecondaryColor),
                              hintStyle:
                                  TextStyle(color: context.textSecondaryColor),
                              prefixIcon: Icon(
                                LucideIcons.tag,
                                size: 18,
                                color: context.primaryColor,
                              ),
                              filled: true,
                              fillColor: context.surfaceColor,
                              enabledBorder: OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: context.borderColor),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: context.primaryColor, width: 1.5),
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Price
                          TextField(
                            controller: priceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}'),
                              ),
                            ],
                            style: TextStyle(
                              color: context.textColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Your Price (₹)',
                              hintText: '0',
                              labelStyle:
                                  TextStyle(color: context.textSecondaryColor),
                              hintStyle:
                                  TextStyle(color: context.textSecondaryColor),
                              prefixIcon: Icon(
                                LucideIcons.indianRupee,
                                size: 18,
                                color: context.primaryColor,
                              ),
                              filled: true,
                              fillColor: context.surfaceColor,
                              enabledBorder: OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: context.borderColor),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: context.primaryColor, width: 1.5),
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Unit chips
                          Text(
                            'Unit',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: context.textSecondaryColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children:
                                ['NOS', 'KG', 'LITRE', 'BOX', 'PACKET', 'BAG']
                                    .map((u) {
                              final isSelected = selectedUnit == u;
                              return GestureDetector(
                                onTap: () =>
                                    setSheetState(() => selectedUnit = u),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? context.primaryColor
                                        : context.surfaceColor,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? context.primaryColor
                                          : context.borderColor,
                                    ),
                                  ),
                                  child: Text(
                                    u,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : context.textColor,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),
                          // Save button — full width, bold
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final name = nameController.text.trim();
                                if (name.isEmpty) {
                                  AppToast.showError(
                                      ctx, 'Please enter an item name');
                                  return;
                                }
                                final price =
                                    double.tryParse(priceController.text.trim()) ??
                                        0.0;

                                bool success;
                                if (item == null) {
                                  success = await ref
                                      .read(itemCatalogueProvider.notifier)
                                      .addItem(name, price, selectedUnit);
                                } else {
                                  success = await ref
                                      .read(itemCatalogueProvider.notifier)
                                      .updateItem(
                                          item.id, name, price, selectedUnit);
                                }

                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                                if (success) {
                                  AppToast.showSuccess(
                                    context,
                                    item == null
                                        ? '✅ "$name" added to catalogue'
                                        : '✅ Item updated',
                                  );
                                } else {
                                  AppToast.showError(context, 'Failed to save item');
                                }
                              },
                              icon: Icon(
                                item == null
                                    ? LucideIcons.plus
                                    : LucideIcons.check,
                                size: 18,
                              ),
                              label: Text(
                                item == null ? 'Add to My Items' : 'Save Changes',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
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
      return item.itemName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final hasItems = state.items.isNotEmpty;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
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
              'My Item Catalogue',
              style: TextStyle(
                color: context.textColor,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: -0.5,
              ),
            ),
            if (hasItems)
              Text(
                '${state.items.length} items · tap any to edit',
                style: TextStyle(
                  color: context.textSecondaryColor,
                  fontSize: 11,
                ),
              ),
          ],
        ),
        actions: [
          // Sync button
          IconButton(
            icon: _isSyncing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation(context.textSecondaryColor),
                    ),
                  )
                : Icon(LucideIcons.refreshCw,
                    color: context.textSecondaryColor, size: 20),
            tooltip: 'Sync from bills',
            onPressed: _isSyncing ? null : _handleSync,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // ── Top action strip ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                // Search field
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: context.borderColor, width: 0.5),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: context.textColor, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search items…',
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
                // ── ADD ITEM BUTTON ─────────────────────────────────────
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
                          color: context.primaryColor.withValues(alpha: 0.35),
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
          ),

          // ── Item count bar ───────────────────────────────────────────────
          if (hasItems)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          context.primaryColor.withValues(alpha: 0.1),
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
                  Icon(LucideIcons.arrowDownUp,
                      size: 12, color: context.textSecondaryColor),
                  const SizedBox(width: 4),
                  Text(
                    'Sorted by most used',
                    style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondaryColor),
                  ),
                  const Spacer(),
                  if (_searchQuery.isNotEmpty && filteredItems.length != state.items.length)
                    Text(
                      '${filteredItems.length} found',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),

          // ── List / Empty state ────────────────────────────────────────────
          Expanded(
            child: Builder(builder: (ctx) {
              if (state.isLoading && state.items.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state.items.isEmpty) {
                return _buildEmptyState();
              }

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
                        style: TextStyle(color: context.textSecondaryColor),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 120),
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  return _ItemCard(
                    item: item,
                    onEdit: () => _showQuickAddSheet(item: item),
                    onDelete: () => _deleteItem(item),
                  );
                },
              );
            }),
          ),
        ],
      ),

      // ── Sticky bottom CTA: Done – back to bill entry ──────────────────────
      bottomNavigationBar: hasItems
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.checkCircle, size: 18),
                    label: Text(
                      'Done — Use These Items',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
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
              ),
            )
          : null,

      // ── FAB (visible when scrolled, as backup) ────────────────────────────
      floatingActionButton: hasItems
          ? null
          : ScaleTransition(
              scale: CurvedAnimation(
                parent: _fabAnimController,
                curve: Curves.elasticOut,
              ),
              child: FloatingActionButton.extended(
                onPressed: () => _showQuickAddSheet(),
                backgroundColor: context.primaryColor,
                foregroundColor: Colors.white,
                icon: const Icon(LucideIcons.plus),
                label: const Text(
                  'Add First Item',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
    );
  }

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
              child: Icon(
                LucideIcons.shoppingBag,
                size: 52,
                color: context.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Set Your Products & Prices',
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
              'Add your items once.\nThey\'ll auto-fill every time you make a bill.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.textSecondaryColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            // Primary: Add manually
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _showQuickAddSheet(),
                icon: const Icon(LucideIcons.plus, size: 18),
                label: const Text(
                  'Add My First Item',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
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
            // Secondary: Sync from bills
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
                  _isSyncing ? 'Syncing…' : 'Auto-Import from My Bills',
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


}

// ── Extracted Item Card ───────────────────────────────────────────────────────
class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final CatalogueItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onEdit,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor, width: 0.5),
          boxShadow: context.premiumShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Left: item info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemName,
                      style: TextStyle(
                        color: context.textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
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
              // Right: price + unit + menu
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
                      color: context.textSecondaryColor,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: Icon(
                  LucideIcons.moreVertical,
                  color: context.textSecondaryColor,
                  size: 18,
                ),
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
