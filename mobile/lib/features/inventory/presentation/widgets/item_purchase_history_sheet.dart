import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/inventory/domain/models/inventory_models.dart';
import 'package:mobile/features/inventory/presentation/inventory_review_page.dart';

class ItemPurchaseHistorySheet extends ConsumerStatefulWidget {
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
  ConsumerState<ItemPurchaseHistorySheet> createState() =>
      _ItemPurchaseHistorySheetState();
}

class _ItemPurchaseHistorySheetState extends ConsumerState<ItemPurchaseHistorySheet> {
  DateTime? _startDate;
  DateTime? _endDate;
  double? _minPrice;
  double? _maxPrice;


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
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: context.primaryColor,
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
          backgroundColor: Theme.of(context).colorScheme.surface,
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
              style: ElevatedButton.styleFrom(backgroundColor: context.primaryColor),
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
    final totalQty = history.fold<double>(0, (sum, item) => sum + item.quantity);
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
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                color: context.borderColor,
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
                    color: context.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(LucideIcons.package,
                      color: context.primaryColor, size: 24),
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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: context.textColor,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.itemDescription.isNotEmpty &&
                          widget.itemPartNumber.isNotEmpty)
                        Text(
                          widget.itemPartNumber,
                          style: TextStyle(
                            fontSize: 14,
                            color: context.textSecondaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(LucideIcons.x, color: context.textSecondaryColor),
                ),
              ],
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                _buildStatCard(context, 'Purchases', '${history.length}',
                    valueColor: context.primaryColor),
                _buildStatCard(context, 'Total Qty',
                    totalQty == totalQty.toInt() ? '${totalQty.toInt()}' : totalQty.toStringAsFixed(2)),
                _buildStatCard(context, 'Vendor', '$uniqueVendors'),
                _buildStatCard(context, 'Avg Price', CurrencyFormatter.format(avgRate)),
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
                      color: context.primaryColor.withValues(alpha: 0.1),
                      border: Border.all(color: context.primaryColor.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.barChart2,
                            size: 14, color: context.primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          _minPrice != null || _maxPrice != null
                              ? 'Filtered Price'
                              : 'Price range: ${CurrencyFormatter.format(overallMinRate)} - ${CurrencyFormatter.format(overallMaxRate)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.primaryColor,
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
                          ? context.primaryColor.withValues(alpha: 0.1)
                          : context.borderColor.withValues(alpha: 0.1),
                      border: Border.all(
                          color: _startDate != null
                              ? context.primaryColor.withValues(alpha: 0.2)
                              : context.borderColor),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.calendar,
                            size: 14,
                            color: _startDate != null
                                ? context.primaryColor
                                : context.textSecondaryColor),
                        const SizedBox(width: 4),
                        Text(
                          _startDate != null
                              ? '${DateFormat('dd MMM').format(_startDate!)} - ${DateFormat('dd MMM').format(_endDate!)}'
                              : 'Date Range',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _startDate != null
                                ? context.primaryColor
                                : context.textSecondaryColor,
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
                            child: Icon(LucideIcons.x, size: 14, color: context.primaryColor),
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
                Text(
                  'Purchase History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.textColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.textColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${history.length} records',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // History List
          history.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                    itemCount: history.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = history[index];

                      return Container(
                        decoration: BoxDecoration(
                          color: context.surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.borderColor),
                          boxShadow: context.premiumShadow,
                        ),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _navigateToBillDetails(item);
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
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: context.textColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${_formatDate(item.invoiceDate)} • #${item.invoiceNumber.isNotEmpty ? item.invoiceNumber : 'N/A'}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: context.textSecondaryColor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(LucideIcons.chevronRight,
                                        size: 16, color: context.textSecondaryColor),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: context.surfaceColor,
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
                                              Text(
                                                'QTY',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: context.textSecondaryColor,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${item.quantity == item.quantity.toInt() ? item.quantity.toInt() : item.quantity.toStringAsFixed(2)} Units',
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
                                              Text(
                                                'RATE',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: context.textSecondaryColor,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${CurrencyFormatter.format(item.rate)}/unit',
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
                                          Text(
                                            'TOTAL',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              letterSpacing: 0.5,
                                            ),
                                        ),
                                          const SizedBox(height: 2),
                                          Text(
                                            CurrencyFormatter.format(item.netBill),
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
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
        boxShadow: context.premiumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: context.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: valueColor ?? context.textColor,
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
            Icon(LucideIcons.inbox, size: 48, color: context.borderColor),
            const SizedBox(height: 12),
            Text(
              'No matching purchase history found',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToBillDetails(InventoryItem item) {
    if (item.invoiceNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No invoice number available for this item.')),
      );
      return;
    }

    HapticFeedback.lightImpact();

    // Group all items from allItems belonging to the same invoice
    final invoiceItems = widget.allItems
        .where((i) => i.invoiceNumber == item.invoiceNumber)
        .toList();

    if (invoiceItems.isEmpty) {
      invoiceItems.add(item);
    }

    final totalAmount = invoiceItems.fold<double>(0, (sum, i) => sum + i.netBill);

    final bundle = InventoryInvoiceBundle(
      invoiceNumber: item.invoiceNumber,
      date: item.invoiceDate,
      vendorName: item.vendorName?.isNotEmpty == true ? item.vendorName! : 'Unknown Vendor',
      receiptLink: item.receiptLink,
      items: invoiceItems,
      totalAmount: totalAmount,
      hasMismatch: invoiceItems.any((i) => i.amountMismatch.abs() > 1.0),
      isVerified: invoiceItems.every((i) => i.verificationStatus == 'Done'),
      createdAt: item.createdAt ?? '',
      headerAdjustments: item.headerAdjustments ?? [],
      paymentMode: item.paymentMode ?? 'Credit',
    );

    context.push('/inventory-invoice-review', extra: bundle);
  }
}
