import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/inventory/domain/models/inventory_models.dart';

class ItemPurchaseHistorySheet extends StatefulWidget {
  final String itemDescription;
  final String itemPartNumber;
  final List<InventoryItem> allItems;

  const ItemPurchaseHistorySheet({
    super.key,
    required this.itemDescription,
    required this.itemPartNumber,
    required this.allItems,
  });

  @override
  State<ItemPurchaseHistorySheet> createState() =>
      _ItemPurchaseHistorySheetState();
}

class _ItemPurchaseHistorySheetState extends State<ItemPurchaseHistorySheet> {
  DateTime? _startDate;
  DateTime? _endDate;
  double? _minPrice;
  double? _maxPrice;

  final currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  List<InventoryItem> _getItemHistory() {
    return widget.allItems.where((item) {
      bool isMatch = false;
      if (widget.itemPartNumber.isNotEmpty) {
        // Exact match for part number
        isMatch = item.partNumber.trim().toLowerCase() ==
            widget.itemPartNumber.trim().toLowerCase();
      } else {
        // Fallback to exact match for description if no part number
        isMatch = item.description.trim().toLowerCase() ==
            widget.itemDescription.trim().toLowerCase();
      }

      if (!isMatch) return false;

      // Filter by Date
      final itemDate = DateTime.tryParse(item.invoiceDate);
      if (itemDate != null) {
        if (_startDate != null && itemDate.isBefore(_startDate!)) return false;
        if (_endDate != null &&
            itemDate.isAfter(_endDate!.add(const Duration(days: 1)))) {
          return false;
        }
      }

      // Filter by Price
      if (_minPrice != null && item.rate < _minPrice!) return false;
      if (_maxPrice != null && item.rate > _maxPrice!) return false;

      return true;
    }).toList()
      ..sort((a, b) {
        final dateA = DateTime.tryParse(a.invoiceDate) ?? DateTime(0);
        final dateB = DateTime.tryParse(b.invoiceDate) ?? DateTime(0);
        return dateB.compareTo(dateA); // Descending order
      });
  }

  String _formatDate(String rawDate) {
    final dt = DateTime.tryParse(rawDate);
    if (dt == null) return rawDate;
    return DateFormat('dd MMM yyyy').format(dt);
  }

  void _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _showPriceFilterDialog() {
    final minController =
        TextEditingController(text: _minPrice?.toStringAsFixed(0) ?? '');
    final maxController =
        TextEditingController(text: _maxPrice?.toStringAsFixed(0) ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Filter by Price', style: TextStyle(fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: minController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Min Price (₹)',
                  prefixIcon: Icon(LucideIcons.indianRupee, size: 16),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: maxController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Max Price (₹)',
                  prefixIcon: Icon(LucideIcons.indianRupee, size: 16),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _minPrice = null;
                  _maxPrice = null;
                });
                Navigator.pop(context);
              },
              child: const Text('Clear', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _minPrice = double.tryParse(minController.text);
                  _maxPrice = double.tryParse(maxController.text);
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = _getItemHistory();

    // Stats calculation
    final totalQty = history.fold<double>(0, (sum, item) => sum + item.qty);
    final rates = history.map((e) => e.rate).where((r) => r > 0).toList();
    final avgRate = rates.isNotEmpty
        ? rates.reduce((a, b) => a + b) / rates.length
        : 0.0;
    final uniqueVendors =
        history.map((e) => e.vendorName).where((v) => v != null).toSet().length;

    // We can show overall min/max if no filter is applied
    final allMatchHistory = widget.allItems.where((item) {
      if (widget.itemPartNumber.isNotEmpty) {
        return item.partNumber.trim().toLowerCase() ==
            widget.itemPartNumber.trim().toLowerCase();
      }
      return item.description.trim().toLowerCase() ==
          widget.itemDescription.trim().toLowerCase();
    }).toList();
    
    final allRates = allMatchHistory.map((e) => e.rate).where((r) => r > 0).toList();
    final overallMinRate =
        allRates.isNotEmpty ? allRates.reduce((a, b) => a < b ? a : b) : 0.0;
    final overallMaxRate =
        allRates.isNotEmpty ? allRates.reduce((a, b) => a > b ? a : b) : 0.0;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header (Similar to Stitch AI Design)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(LucideIcons.package,
                      color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.itemDescription.isNotEmpty
                            ? widget.itemDescription
                            : widget.itemPartNumber,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.itemDescription.isNotEmpty &&
                          widget.itemPartNumber.isNotEmpty)
                        Text(
                          widget.itemPartNumber,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),

          // Stats Grid (2x2)
          Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              childAspectRatio: 2.2,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStatCard('Purchases', '${history.length}',
                    valueColor: AppTheme.primary),
                _buildStatCard('Total Qty',
                    totalQty == totalQty.toInt() ? '${totalQty.toInt()}' : totalQty.toStringAsFixed(2)),
                _buildStatCard('Vendor', '$uniqueVendors'),
                _buildStatCard('Avg Price', '₹${avgRate.toStringAsFixed(0)}'),
              ],
            ),
          ),

          // Filters section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Price Range Display / Filter
                InkWell(
                  onTap: _showPriceFilterDialog,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.barChart2,
                            size: 14, color: AppTheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          _minPrice != null || _maxPrice != null
                              ? 'Filtered Price'
                              : 'Price range: ₹${overallMinRate.toStringAsFixed(0)} - ₹${overallMaxRate.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Date Range Filter
                InkWell(
                  onTap: _showDateRangePicker,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _startDate != null
                          ? AppTheme.primary.withValues(alpha: 0.1)
                          : Colors.grey.shade100,
                      border: Border.all(
                          color: _startDate != null
                              ? AppTheme.primary.withValues(alpha: 0.2)
                              : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.calendar,
                            size: 14,
                            color: _startDate != null
                                ? AppTheme.primary
                                : AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          _startDate != null
                              ? '${DateFormat('dd MMM').format(_startDate!)} - ${DateFormat('dd MMM').format(_endDate!)}'
                              : 'Date Range',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _startDate != null
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                          ),
                        ),
                        if (_startDate != null) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _startDate = null;
                                _endDate = null;
                              });
                            },
                            child: Icon(LucideIcons.x, size: 14, color: AppTheme.primary),
                          )
                        ]
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),

          // Purchase History List Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Text(
                  'Purchase History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${history.length} records',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // History List
          Flexible(
            child: history.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: history.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = history[index];

                      return Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                          },
                          borderRadius: BorderRadius.circular(16),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.vendorName ?? 'Unknown Vendor',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${_formatDate(item.invoiceDate)} • #${item.invoiceNumber.isNotEmpty ? item.invoiceNumber : 'N/A'}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textSecondary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(LucideIcons.chevronRight,
                                        size: 16, color: AppTheme.textSecondary),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.background,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'QTY',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.textSecondary,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${item.qty == item.qty.toInt() ? item.qty.toInt() : item.qty.toStringAsFixed(2)} Units',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 24),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'RATE',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.textSecondary,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '₹${item.rate.toStringAsFixed(0)}/unit',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          const Text(
                                            'TOTAL',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.textSecondary,
                                              letterSpacing: 0.5,
                                            ),
                                        ),
                                          const SizedBox(height: 2),
                                          Text(
                                            currencyFormat.format(item.netBill),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primary,
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
                    },
                  ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: valueColor ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.inbox, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No matching purchase history found',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
