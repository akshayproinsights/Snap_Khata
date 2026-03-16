import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/inventory/domain/models/inventory_models.dart';

class ItemPurchaseHistorySheet extends StatelessWidget {
  final String itemDescription;
  final String itemPartNumber;
  final List<InventoryItem> allItems;

  const ItemPurchaseHistorySheet({
    super.key,
    required this.itemDescription,
    required this.itemPartNumber,
    required this.allItems,
  });

  List<InventoryItem> _getItemHistory() {
    final searchTerm = itemDescription.toLowerCase();
    final partSearch = itemPartNumber.toLowerCase();
    
    return allItems.where((item) {
      final descMatch = item.description.toLowerCase() == searchTerm ||
                        item.description.toLowerCase().contains(searchTerm);
      final partMatch = item.partNumber.toLowerCase() == partSearch ||
                        item.partNumber.toLowerCase().contains(partSearch);
      return descMatch || partMatch;
    }).toList()
      ..sort((a, b) {
        final dateA = DateTime.tryParse(a.invoiceDate) ?? DateTime(0);
        final dateB = DateTime.tryParse(b.invoiceDate) ?? DateTime(0);
        return dateB.compareTo(dateA);
      });
  }

  String _formatDate(String rawDate) {
    final dt = DateTime.tryParse(rawDate);
    if (dt == null) return rawDate;
    return DateFormat('dd MMM yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final history = _getItemHistory();
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    
    // Calculate stats
    final totalQty = history.fold<double>(0, (sum, item) => sum + item.qty);
    final rates = history.map((e) => e.rate).where((r) => r > 0).toList();
    final avgRate = rates.isNotEmpty ? rates.reduce((a, b) => a + b) / rates.length : 0.0;
    final minRate = rates.isNotEmpty ? rates.reduce((a, b) => a < b ? a : b) : 0.0;
    final maxRate = rates.isNotEmpty ? rates.reduce((a, b) => a > b ? a : b) : 0.0;
    final uniqueVendors = history.map((e) => e.vendorName).where((v) => v != null).toSet().length;
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(LucideIcons.package, color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        itemDescription.isNotEmpty ? itemDescription : itemPartNumber,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (itemDescription.isNotEmpty && itemPartNumber.isNotEmpty)
                        Text(
                          itemPartNumber,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(LucideIcons.x, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          
          // Stats Row
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                _buildStat(
                  icon: LucideIcons.shoppingCart,
                  label: 'Purchases',
                  value: '${history.length}',
                  color: AppTheme.primary,
                ),
                _buildDivider(),
                _buildStat(
                  icon: LucideIcons.layers,
                  label: 'Total Qty',
                  value: totalQty == totalQty.toInt() 
                      ? '${totalQty.toInt()}' 
                      : totalQty.toStringAsFixed(2),
                  color: const Color(0xFFF59E0B),
                ),
                _buildDivider(),
                _buildStat(
                  icon: LucideIcons.store,
                  label: 'Vendors',
                  value: '$uniqueVendors',
                  color: const Color(0xFF10B981),
                ),
                _buildDivider(),
                _buildStat(
                  icon: LucideIcons.trendingUp,
                  label: 'Avg Price',
                  value: '₹${avgRate.toStringAsFixed(0)}',
                  color: const Color(0xFF8B5CF6),
                ),
              ],
            ),
          ),
          
          // Price Range
          if (rates.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.tag, size: 14, color: Colors.blue.shade600),
                    const SizedBox(width: 6),
                    Text(
                      'Price range: ₹${minRate.toStringAsFixed(0)} - ₹${maxRate.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          const SizedBox(height: 16),
          
          // History Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  'Purchase History',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${history.length} records',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // History List
          Flexible(
            child: history.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final item = history[index];
                      final isRecent = index < 3;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isRecent ? Colors.green.shade50 : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isRecent ? Colors.green.shade200 : Colors.grey.shade200,
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.vendorName ?? 'Unknown Vendor',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isRecent)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'RECENT',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(LucideIcons.calendar, size: 12, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatDate(item.invoiceDate),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(LucideIcons.hash, size: 12, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text(
                                      item.invoiceNumber.isNotEmpty 
                                          ? item.invoiceNumber 
                                          : 'N/A',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    _buildDetailChip(
                                      icon: LucideIcons.layers,
                                      label: '${item.qty == item.qty.toInt() ? item.qty.toInt() : item.qty.toStringAsFixed(2)} units',
                                    ),
                                    const SizedBox(width: 8),
                                    _buildDetailChip(
                                      icon: LucideIcons.indianRupee,
                                      label: '${item.rate.toStringAsFixed(0)}/unit',
                                    ),
                                    const Spacer(),
                                    Text(
                                      currencyFormat.format(item.netBill),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          const SizedBox(height: 20),
          
          // Bottom Safe Area
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _buildStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey.shade200,
    );
  }

  Widget _buildDetailChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.inbox, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'No purchase history found',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
