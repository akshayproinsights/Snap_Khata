import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/purchase_orders/presentation/providers/purchase_order_provider.dart';
import 'package:mobile/features/inventory/domain/models/inventory_models.dart';
import 'package:mobile/features/inventory/presentation/providers/inventory_items_provider.dart';
import 'package:mobile/features/inventory/presentation/widgets/item_purchase_history_sheet.dart';

// ─── Grouped invoice bundle ──────────────────────────────────────────────────
class _InvoiceBundle {
  final String invoiceNumber;
  final String date;
  final String vendorName;
  final String receiptLink;
  final List<InventoryItem> items;
  double totalAmount;
  bool hasMismatch;

  _InvoiceBundle({
    required this.invoiceNumber,
    required this.date,
    required this.vendorName,
    required this.receiptLink,
    required this.items,
    required this.totalAmount,
    required this.hasMismatch,
  });
}

// ─── Page ────────────────────────────────────────────────────────────────────
class InventoryMainPage extends ConsumerStatefulWidget {
  const InventoryMainPage({super.key});

  @override
  ConsumerState<InventoryMainPage> createState() => _InventoryMainPageState();
}

class _InventoryMainPageState extends ConsumerState<InventoryMainPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _dateLabel(String rawDate) {
    final dt = DateTime.tryParse(rawDate);
    if (dt == null) return rawDate;
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(dt.year, dt.month, dt.day))
        .inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('d MMM').format(dt);
  }

  List<_InvoiceBundle> _groupItems(List<InventoryItem> items) {
    final Map<String, _InvoiceBundle> groups = {};
    for (final item in items) {
      final key = item.invoiceNumber.isNotEmpty
          ? item.invoiceNumber
          : '${item.invoiceDate}_${item.vendorName ?? ''}';
      final safeKey = key.isNotEmpty ? key : item.id.toString();

      if (!groups.containsKey(safeKey)) {
        groups[safeKey] = _InvoiceBundle(
          invoiceNumber: item.invoiceNumber,
          date: item.invoiceDate,
          vendorName: item.vendorName?.isNotEmpty == true
              ? item.vendorName!
              : 'Unknown Vendor',
          receiptLink: item.receiptLink,
          items: [],
          totalAmount: 0,
          hasMismatch: false,
        );
      }
      final bundle = groups[safeKey]!;
      bundle.items.add(item);
      bundle.totalAmount += item.netBill;
      if (item.amountMismatch > 1.0) bundle.hasMismatch = true;
    }

    return groups.values.toList()
      ..sort((a, b) {
        final dA = DateTime.tryParse(a.date) ?? DateTime(0);
        final dB = DateTime.tryParse(b.date) ?? DateTime(0);
        return dB.compareTo(dA);
      });
  }

  @override
  Widget build(BuildContext context) {
    final poState = ref.watch(purchaseOrderProvider);
    final itemsAsync = ref.watch(inventoryItemsProvider);

    final pendingCount = itemsAsync.maybeWhen(
      data: (items) => items.where((i) => i.verificationStatus != 'Done').length,
      orElse: () => 0,
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        titleSpacing: 16,
        surfaceTintColor: Colors.transparent,
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Inventory',
          style: TextStyle(
              fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
        ),
        actions: [
          _buildPoBadge(context, poState),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(inventoryItemsProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildQuickLinksCard(context, pendingCount),
              const SizedBox(height: 28),
              Row(
                children: [
                  const Text(
                    'Recent Vendor Deliveries',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  if (itemsAsync.isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _buildSearchBox(),
              const SizedBox(height: 12),
              _buildDeliveriesList(context, itemsAsync),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      floatingActionButton: SizedBox(
        height: 54,
        child: FloatingActionButton.extended(
          onPressed: () {
            HapticFeedback.mediumImpact();
            context.push('/inventory-upload');
          },
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.camera_alt_rounded, size: 22),
          label: Text(
            'Add New Items',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: Colors.white,
                ),
          ),
          elevation: 6,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSearchBox() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
        style: const TextStyle(
          fontSize: 14,
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Search by vendor, invoice ID or item…',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13.5),
          prefixIcon:
              Icon(LucideIcons.search, size: 18, color: Colors.grey.shade400),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(LucideIcons.x,
                      size: 16, color: Colors.grey.shade400),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
      ),
    );
  }

  Widget _buildPoBadge(BuildContext context, PurchaseOrderState poState) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(LucideIcons.shoppingCart),
          tooltip: 'Purchase Orders',
          onPressed: () {
            HapticFeedback.lightImpact();
            context.push('/purchase-orders');
          },
        ),
        if (poState.hasDraftItems)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.error,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                poState.draftCount > 99 ? '99+' : '${poState.draftCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuickLinksCard(BuildContext context, int pendingCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildActionItem(
                context: context,
                icon: LucideIcons.clipboardCheck,
                color: pendingCount > 0
                    ? const Color(0xFFEF4444)
                    : Colors.grey.shade400,
                title: 'Review',
                badgeCount: pendingCount,
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/inventory-review');
                },
              ),
              _buildActionItem(
                context: context,
                icon: LucideIcons.box,
                color: const Color(0xFFF59E0B),
                title: 'Stock',
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/current-stock');
                },
              ),
              _buildActionItem(
                context: context,
                icon: LucideIcons.gitMerge,
                color: const Color(0xFF3B82F6),
                title: 'Link Items',
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/inventory-item-mapping');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    int badgeCount = 0,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        constraints:
                            const BoxConstraints(minWidth: 20, minHeight: 20),
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveriesList(
      BuildContext context, AsyncValue<List<InventoryItem>> itemsAsync) {
    return itemsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(48.0),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(LucideIcons.wifiOff, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text('Could not load deliveries',
                  style: TextStyle(
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Pull down to retry',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
            ],
          ),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(LucideIcons.truck,
                        size: 48, color: Colors.grey.shade300),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No vendor deliveries yet',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap "Add New Items" to snap\na vendor bill or purchase order',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        var bundles = _groupItems(items);

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          bundles = bundles.where((b) {
            final vendorMatch =
                b.vendorName.toLowerCase().contains(_searchQuery);
            final invoiceMatch =
                b.invoiceNumber.toLowerCase().contains(_searchQuery);
            final itemMatch = b.items.any((i) =>
                i.description.toLowerCase().contains(_searchQuery) ||
                i.partNumber.toLowerCase().contains(_searchQuery));
            return vendorMatch || invoiceMatch || itemMatch;
          }).toList();
        }

        if (bundles.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(LucideIcons.searchX,
                      size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    'No results found',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Try searching by vendor, invoice ID or item name',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: bundles.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final bundle = bundles[index];
            return _VendorDeliveryCard(
              bundle: bundle,
              dateLabel: _dateLabel(bundle.date),
              searchQuery: _searchQuery,
              allItems: items,
            );
          },
        );
      },
    );
  }
}

// ─── Vendor Delivery Card ─────────────────────────────────────────────────────
class _VendorDeliveryCard extends ConsumerStatefulWidget {
  final _InvoiceBundle bundle;
  final String dateLabel;
  final String searchQuery;
  final List<InventoryItem> allItems;

  const _VendorDeliveryCard({
    required this.bundle,
    required this.dateLabel,
    required this.searchQuery,
    required this.allItems,
  });

  @override
  ConsumerState<_VendorDeliveryCard> createState() =>
      _VendorDeliveryCardState();
}

class _VendorDeliveryCardState extends ConsumerState<_VendorDeliveryCard> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    // Auto-expand when search is active
    _isExpanded = widget.searchQuery.isNotEmpty;
  }

  @override
  void didUpdateWidget(_VendorDeliveryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update expansion state when search query changes
    if (oldWidget.searchQuery != widget.searchQuery) {
      setState(() {
        _isExpanded = widget.searchQuery.isNotEmpty;
      });
    }
  }

  List<InventoryItem> _getVisibleItems() {
    final searchQuery = widget.searchQuery;
    final allItems = widget.bundle.items;
    
    if (searchQuery.isEmpty) {
      return allItems;
    }
    
    // If the search query matches the bundle's vendor or invoice number, show all items
    if (widget.bundle.vendorName.toLowerCase().contains(searchQuery) ||
        widget.bundle.invoiceNumber.toLowerCase().contains(searchQuery)) {
      return allItems;
    }
    
    // When search is active and vendor/invoice don't match, show only matching items
    return allItems.where((item) {
      final descMatch = item.description.toLowerCase().contains(searchQuery);
      final partMatch = item.partNumber.toLowerCase().contains(searchQuery);
      return descMatch || partMatch;
    }).toList();
  }

  void _showItemHistory(InventoryItem item) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ItemPurchaseHistorySheet(
        itemDescription: item.description,
        itemPartNumber: item.partNumber,
        allItems: widget.allItems,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final bundle = widget.bundle;
    final hasMismatch = bundle.hasMismatch;
    final visibleItems = _getVisibleItems();
    final isSearching = widget.searchQuery.isNotEmpty;
    final filteredCount = visibleItems.length;
    final totalCount = bundle.items.length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasMismatch
              ? const Color(0xFFEF4444).withValues(alpha: 0.4)
              : Colors.grey.shade200,
          width: hasMismatch ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: hasMismatch
                ? const Color(0xFFEF4444).withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _isExpanded = !_isExpanded);
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: hasMismatch
                            ? const Color(0xFFEF4444).withValues(alpha: 0.08)
                            : AppTheme.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        hasMismatch
                            ? LucideIcons.alertCircle
                            : LucideIcons.packageCheck,
                        color: hasMismatch
                            ? const Color(0xFFEF4444)
                            : AppTheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Vendor name — always fully shown
                          Text(
                            bundle.vendorName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.visible,
                          ),
                          // Invoice ID on its own line (if present)
                          if (bundle.invoiceNumber.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  Icon(LucideIcons.hash,
                                      size: 11, color: Colors.grey.shade500),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      bundle.invoiceNumber,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                widget.dateLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Text(' · ',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12)),
                              Text(
                                '${bundle.items.length} item${bundle.items.length == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Text(' · ',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12)),
                              Text(
                                currencyFormat.format(bundle.totalAmount),
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (hasMismatch)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color:
                                      const Color(0xFFEF4444).withValues(alpha: 0.3)),
                            ),
                            child: const Text('⚠ Review',
                                style: TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800)),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Verified',
                                    style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(width: 3),
                                Icon(LucideIcons.checkCircle2,
                                    size: 11, color: Colors.green.shade600),
                              ],
                            ),
                          ),
                        const SizedBox(height: 6),
                        AnimatedRotation(
                          turns: _isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 250),
                          child: Icon(
                            LucideIcons.chevronDown,
                            size: 18,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: _isExpanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Column(
                children: [
                  const Divider(height: 1, thickness: 1),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
                    child: Row(
                      children: [
                        Expanded(
                            flex: 4,
                            child: Text('Item',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textSecondary))),
                        SizedBox(
                            width: 48,
                            child: Text('Qty',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textSecondary))),
                        SizedBox(width: 8),
                        SizedBox(
                            width: 60,
                            child: Text('Rate',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textSecondary))),
                        SizedBox(width: 8),
                        SizedBox(
                            width: 64,
                            child: Text('Amount',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textSecondary))),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ...visibleItems.map((item) {
                    final rowMismatch = item.amountMismatch > 1.0;
                    return InkWell(
                      onTap: () => _showItemHistory(item),
                      child: Container(
                        color: rowMismatch
                            ? const Color(0xFFEF4444).withValues(alpha: 0.04)
                            : null,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.description.isNotEmpty
                                        ? item.description
                                        : item.partNumber,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: rowMismatch
                                          ? const Color(0xFFEF4444)
                                          : AppTheme.textPrimary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (isSearching)
                                    Text(
                                      'Tap for history →',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 48,
                              child: Text(
                                item.qty == item.qty.roundToDouble()
                                    ? item.qty.toInt().toString()
                                    : item.qty.toStringAsFixed(2),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 60,
                              child: Text(
                                '₹${item.rate.toStringAsFixed(0)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 64,
                              child: Text(
                                '₹${item.netBill.toStringAsFixed(0)}',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: rowMismatch
                                      ? const Color(0xFFEF4444)
                                      : AppTheme.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  Container(
                    color: Colors.grey.shade50,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              isSearching && filteredCount != totalCount
                                  ? 'Showing $filteredCount of $totalCount items'
                                  : '$totalCount item${totalCount == 1 ? '' : 's'}',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: isSearching && filteredCount != totalCount
                                      ? AppTheme.primary
                                      : Colors.grey.shade500,
                                  fontWeight: isSearching && filteredCount != totalCount
                                      ? FontWeight.w600
                                      : FontWeight.w500),
                            ),
                            if (isSearching && filteredCount != totalCount)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'filtered',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Text(
                          'Total: ${currencyFormat.format(bundle.totalAmount)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
