import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/inventory/domain/models/inventory_models.dart';
import 'package:mobile/features/inventory/presentation/providers/inventory_items_provider.dart';
import 'package:mobile/features/inventory/presentation/widgets/item_price_history_sheet.dart';

class ItemsPage extends ConsumerStatefulWidget {
  const ItemsPage({super.key});

  @override
  ConsumerState<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends ConsumerState<ItemsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildSearchBox() {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.1 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
        style: TextStyle(
          fontSize: 14,
          color: context.textColor,
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

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(inventoryItemsProvider);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        titleSpacing: 16,
        surfaceTintColor: Colors.transparent,
        backgroundColor: context.surfaceColor,
        title: Text(
          'Track Items',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: context.textColor,
          ),
        ),
        centerTitle: false,
      ),
      body: _buildBody(context, itemsAsync),
    );
  }

  Widget _buildBody(BuildContext context, AsyncValue<List<InventoryItem>> itemsAsync) {
    if (itemsAsync.isLoading && !itemsAsync.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }

    if (itemsAsync.hasError) {
      return Center(
        child: Text('Error: ${itemsAsync.error}',
            style: const TextStyle(color: AppTheme.error)),
      );
    }

    final allItems = itemsAsync.value ?? [];
    
    // Filter to verified only
    final verifiedItems = allItems.where((i) => i.verificationStatus == 'Done').toList();
    
    // Deduplicate by description
    final Map<String, InventoryItem> latestItemMap = {};
    final Map<String, int> orderCountMap = {};
    
    for (var item in verifiedItems) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesDesc = item.description.toLowerCase().contains(query);
        final matchesPart = item.partNumber.toLowerCase().contains(query);
        final matchesVendor = (item.vendorName ?? '').toLowerCase().contains(query);
        if (!matchesDesc && !matchesPart && !matchesVendor) continue;
      }
      
      final key = item.description.trim().toLowerCase();
      if (key.isEmpty) continue;
      
      orderCountMap[key] = (orderCountMap[key] ?? 0) + 1;
      
      if (!latestItemMap.containsKey(key)) {
        latestItemMap[key] = item;
      } else {
        // Compare dates, keep most recent
        final currentLatest = latestItemMap[key]!;
        final currentDate = DateTime.tryParse(currentLatest.invoiceDate) ?? DateTime(0);
        final newDate = DateTime.tryParse(item.invoiceDate) ?? DateTime(0);
        
        if (newDate.isAfter(currentDate)) {
          latestItemMap[key] = item;
        } else if (newDate.isAtSameMomentAs(currentDate)) {
          // Tie-breaker: use created_at to pick the truly latest item
          final currentCreated = DateTime.tryParse(currentLatest.createdAt ?? '') ?? DateTime(0);
          final newCreated = DateTime.tryParse(item.createdAt ?? '') ?? DateTime(0);
          if (newCreated.isAfter(currentCreated)) {
            latestItemMap[key] = item;
          }
        }
      }
    }

    final uniqueItems = latestItemMap.values.toList()
      ..sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate)); // sort by most recently ordered

    return Column(
      children: [
        if (verifiedItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: _buildSearchBox(),
          ),
        Expanded(
          child: uniqueItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.box,
                          size: 48, color: context.isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No items found matching "$_searchQuery"'
                            : 'No verified items logged yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.textSecondaryColor),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async => ref.invalidate(inventoryItemsProvider),
                  child: ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: uniqueItems.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = uniqueItems[index];
                      final orderCount = orderCountMap[item.description.trim().toLowerCase()] ?? 1;
                      return _buildItemCatalogCard(context, item, orderCount);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildItemCatalogCard(BuildContext context, InventoryItem item, int orderCount) {

    // Determine price trend
    Color trendColor = Colors.grey.shade500;
    IconData trendIcon = LucideIcons.minus; // stable
    String trendText = 'Stable';

    double delta = item.priceHikeAmount ?? 0;

    // Fallback: calculate from previousRate if priceHikeAmount is missing or zero
    if (delta == 0 && item.previousRate != null && item.previousRate! > 0) {
      delta = item.rate - item.previousRate!;
    }
    
    if (delta > 0) {
      trendColor = const Color(0xFFEF4444); // red
      trendIcon = LucideIcons.trendingUp;
      trendText = 'Going Up ${CurrencyFormatter.format(delta)}';
    } else if (delta < 0) {
      trendColor = const Color(0xFF22C55E); // green
      trendIcon = LucideIcons.trendingDown;
      trendText = 'Going Down ${CurrencyFormatter.format(delta)}';
    } else if (orderCount > 1) {
      // Multiple orders but no detectable direction → show "Price varies"
      trendText = 'Price varies';
    }

    String dateLabel = '';
    try {
      final dt = DateTime.parse(item.invoiceDate);
      dateLabel = DateFormat('dd MMM yy').format(dt);
    } catch (_) {
      dateLabel = item.invoiceDate.split('T').first;
    }

    return Material(
      color: context.surfaceColor,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.borderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => ItemPriceHistorySheet(
              description: item.description,
              partNumber: item.partNumber,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.description,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: context.textColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.vendorName != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            item.vendorName!,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.primary.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (item.partNumber.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.partNumber,
                            style: TextStyle(
                              fontSize: 13,
                              color: context.textSecondaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Price block
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.format(item.rate),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: context.textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(trendIcon, size: 14, color: trendColor),
                          const SizedBox(width: 4),
                          Text(
                            trendText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: trendColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(LucideIcons.history, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    'Ordered $orderCount time${orderCount == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textSecondaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Last: $dateLabel',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textSecondaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
