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

    // 1. Only show verified items for the catalog
    final verifiedItems = allItems.where((i) => i.verificationStatus == 'Done').toList();

    // 2. Group by description (case-insensitive) to find unique catalog items
    final Map<String, List<InventoryItem>> grouped = {};
    for (var item in verifiedItems) {
      final desc = item.description.trim().toUpperCase();
      if (desc.isEmpty) continue;
      grouped.putIfAbsent(desc, () => []).add(item);
    }

    // 3. Create a list of deduplicated items with calculated stats
    final List<Map<String, dynamic>> catalogItems = [];
    grouped.forEach((desc, groupItems) {
      // Sort items by date (newest first) and then by ID (highest first) to get the absolute latest entry
      groupItems.sort((a, b) {
        int dateCmp = b.invoiceDate.compareTo(a.invoiceDate);
        if (dateCmp != 0) return dateCmp;
        return b.id.compareTo(a.id); // Tie-breaker for same-day invoices
      });
      
      final latestItem = groupItems.first;
      final lastPrice = latestItem.rate;
      
      // Find the previous different price for trend calculation
      double prevPrice = lastPrice;
      for (var i = 1; i < groupItems.length; i++) {
        if (groupItems[i].rate != lastPrice) {
          prevPrice = groupItems[i].rate;
          break;
        }
      }
      
      final priceChange = lastPrice - prevPrice;
      final orderCount = groupItems.length;

      catalogItems.add({
        'item': latestItem,
        'lastPrice': lastPrice,
        'priceChange': priceChange,
        'orderCount': orderCount,
      });
    });

    // 4. Apply search filtering on the deduplicated catalog
    final filteredCatalog = catalogItems.where((entry) {
      final item = entry['item'] as InventoryItem;
      final query = _searchQuery.toLowerCase();
      return item.description.toLowerCase().contains(query) ||
             item.partNumber.toLowerCase().contains(query) ||
             (item.vendorName ?? '').toLowerCase().contains(query);
    }).toList();

    return Column(
      children: [
        if (allItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: _buildSearchBox(),
          ),
        Expanded(
          child: verifiedItems.isEmpty
              ? _buildEmptyState(
                  context,
                  LucideIcons.packageSearch,
                  'No verified items logged yet.',
                  'Verified items from your supplier purchases\nwill appear here automatically.',
                )
              : filteredCatalog.isEmpty
                  ? _buildEmptyState(
                      context,
                      LucideIcons.searchX,
                      'No items found matching "$_searchQuery"',
                      'Try searching with a different name\nor part number.',
                    )
                  : RefreshIndicator(
                      onRefresh: () async => ref.invalidate(inventoryItemsProvider),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: filteredCatalog.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final entry = filteredCatalog[index];
                          final item = entry['item'] as InventoryItem;
                          final orderCount = entry['orderCount'] as int;
                          
                          return _buildItemCatalogCard(context, item, orderCount);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              shape: BoxShape.circle,
              border: Border.all(color: context.borderColor.withValues(alpha: 0.5)),
            ),
            child: Icon(icon, size: 48, color: context.borderColor),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: context.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondaryColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildItemCatalogCard(BuildContext context, InventoryItem item, int orderCount) {
    // Determine price trend
    Color trendColor = Colors.grey.shade500;
    Color trendBg = context.borderColor.withValues(alpha: 0.1);
    IconData trendIcon = LucideIcons.minus;
    String trendText = 'Stable';

    double delta = item.priceHikeAmount ?? 0;
    if (delta == 0 && item.previousRate != null && item.previousRate! > 0) {
      delta = item.rate - item.previousRate!;
    }
    
    if (delta > 0) {
      trendColor = const Color(0xFFEF4444); // Red-500
      trendBg = trendColor.withValues(alpha: 0.1);
      trendIcon = LucideIcons.trendingUp;
      trendText = '+${CurrencyFormatter.format(delta)}';
    } else if (delta < 0) {
      trendColor = const Color(0xFF22C55E); // Green-500
      trendBg = trendColor.withValues(alpha: 0.1);
      trendIcon = LucideIcons.trendingDown;
      trendText = CurrencyFormatter.format(delta);
    }

    String dateLabel = '';
    try {
      final dt = DateTime.parse(item.invoiceDate);
      dateLabel = DateFormat('d MMM yyyy').format(dt);
    } catch (_) {
      dateLabel = item.invoiceDate.split('T').first;
    }

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor, width: 1.2),
        boxShadow: context.premiumShadow,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.mediumImpact();
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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Item Name & Latest Price
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
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: context.textColor,
                            letterSpacing: -0.4,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.partNumber.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: context.borderColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.partNumber,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.textSecondaryColor,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.format(item.rate),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: context.textColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (delta != 0) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: trendBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(trendIcon, size: 14, color: trendColor),
                              const SizedBox(width: 4),
                              Text(
                                trendText,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: trendColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Bottom Section: Vendor & History Meta
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.backgroundColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(LucideIcons.store, size: 14, color: context.primaryColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.vendorName ?? 'Unknown Vendor',
                            style: TextStyle(
                              fontSize: 14,
                              color: context.primaryColor,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(LucideIcons.calendar, size: 14, color: context.textSecondaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Last bought $dateLabel',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textSecondaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: context.borderColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$orderCount orders',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textSecondaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
