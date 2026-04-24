import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/inventory/domain/models/inventory_models.dart';
import 'package:mobile/features/inventory/presentation/inventory_review_page.dart';
import 'package:mobile/features/inventory/presentation/providers/inventory_items_provider.dart';
import 'package:mobile/features/inventory/presentation/providers/item_price_history_provider.dart';

class ItemPriceHistorySheet extends ConsumerWidget {
  final String description;
  final String partNumber;

  const ItemPriceHistorySheet({
    super.key,
    required this.description,
    required this.partNumber,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(itemPriceHistoryProvider(description));

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    if (partNumber.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        partNumber,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Content
              Expanded(
                child: historyAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(
                    child: Text('Error: $err', style: const TextStyle(color: AppTheme.error)),
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return const Center(child: Text('No history available'));
                    }
                    return _buildContent(context, ref, items, scrollController);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, List<InventoryItem> items, ScrollController scrollController) {
    final latestItem = items.last; // Since it's sorted ASC chronologically

    // Trend badge
    Color trendColor = Colors.grey.shade600;
    Color trendBgColor = Colors.grey.shade100;
    IconData trendIcon = LucideIcons.minus;
    String trendText = 'Price varies / Stable';
    
    if ((latestItem.priceHikeAmount ?? 0) > 0) {
      trendColor = const Color(0xFFDC2626); // red
      trendBgColor = const Color(0xFFFEE2E2);
      trendIcon = LucideIcons.trendingUp;
      trendText = 'Price is Going Up';
    } else if ((latestItem.priceHikeAmount ?? 0) < 0) {
      trendColor = const Color(0xFF16A34A); // green
      trendBgColor = const Color(0xFFDCFCE7);
      trendIcon = LucideIcons.trendingDown;
      trendText = 'Price Dropped';
    }

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              children: [
                // Trend Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: trendBgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(trendIcon, size: 16, color: trendColor),
                      const SizedBox(width: 8),
                      Text(
                        trendText,
                        style: TextStyle(
                          color: trendColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Sparkline
                if (items.length > 1)
                  SizedBox(
                    height: 120, // Increased height for labels
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _SparklinePainter(items: items),
                    ),
                  ),
                
                const SizedBox(height: 32),
                
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Purchase History',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        
        // History List (Reversed to show newest first in the list)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8).copyWith(bottom: 40),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                // Read from end to beginning
                final reversedIndex = items.length - 1 - index;
                final item = items[reversedIndex];
                return _buildHistoryCard(context, ref, item, reversedIndex > 0 ? items[reversedIndex - 1] : null, items);
              },
              childCount: items.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(BuildContext context, WidgetRef ref, InventoryItem item, InventoryItem? previousItem, List<InventoryItem> historyItems) {
    
    // Parse date
    final dt = DateTime.tryParse(item.invoiceDate);
    final dateStr = dt != null ? DateFormat('d MMM yyyy').format(dt) : item.invoiceDate;

    // Check delta
    double delta = 0;
    if (previousItem != null) {
      delta = item.rate - previousItem.rate;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _navigateToBillDetails(context, ref, item, historyItems),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (delta != 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          delta > 0 ? LucideIcons.trendingUp : LucideIcons.trendingDown,
                          size: 14,
                          color: delta > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${delta > 0 ? '+' : ''}${CurrencyFormatter.format(delta)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: delta > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                item.vendorName ?? 'Unknown Supplier',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '×${item.qty.toInt()} units',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Text(' @ ', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  Text(
                    CurrencyFormatter.format(item.rate),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    CurrencyFormatter.format(item.netBill),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
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

  void _navigateToBillDetails(BuildContext context, WidgetRef ref, InventoryItem item, List<InventoryItem> historyItems) {
    if (item.invoiceNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No invoice number available for this item.')),
      );
      return;
    }

    HapticFeedback.lightImpact();

    // Use all items from inventoryItemsProvider to get the full invoice
    final allInventoryItems = ref.read(inventoryItemsProvider).value ?? historyItems;

    // Group all items belonging to the same invoice
    final invoiceItems = allInventoryItems
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

class _SparklinePainter extends CustomPainter {
  final List<InventoryItem> items;

  _SparklinePainter({required this.items});

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty) return;

    final rates = items.map((i) => i.rate).toList();
    final minRate = rates.reduce((a, b) => a < b ? a : b);
    final maxRate = rates.reduce((a, b) => a > b ? a : b);
    
    // Add padding to range to accommodate labels above and below
    final range = (maxRate - minRate) == 0 ? 1.0 : (maxRate - minRate);
    final paddedMin = minRate - (range * 0.4); // Space for month labels
    final paddedMax = maxRate + (range * 0.4); // Space for price labels
    final paddedRange = paddedMax - paddedMin;

    final linePaint = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final pointPaint = Paint()
      ..color = AppTheme.primary
      ..style = PaintingStyle.fill;

    final latestPointPaint = Paint()
      ..color = _getTrendColor(items.last)
      ..style = PaintingStyle.fill;

    final path = Path();
    
    // Calculate points
    final dx = size.width / (items.length > 1 ? items.length - 1 : 1);
    final points = <Offset>[];

    for (int i = 0; i < items.length; i++) {
      final x = i * dx;
      final normalizedY = 1 - ((rates[i] - paddedMin) / paddedRange);
      final y = normalizedY * size.height;
      points.add(Offset(x, y));
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Draw line
    canvas.drawPath(path, linePaint);

    // Draw solid points and labels
    for (int i = 0; i < points.length; i++) {
      // 1. Draw point
      if (i == points.length - 1) {
        // Draw bigger latest point with a glow
        final glowPaint = Paint()
          ..color = latestPointPaint.color.withValues(alpha: 0.2)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(points[i], 8, glowPaint);
        canvas.drawCircle(points[i], 4, latestPointPaint);
      } else {
        canvas.drawCircle(points[i], 3, pointPaint);
      }

      // 2. Draw Data Label (Price) - Above point
      final priceLabel = CurrencyFormatter.formatPlain(rates[i]);
      _drawText(
        canvas,
        priceLabel,
        points[i] + const Offset(0, -22), // Offset above
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimary.withValues(alpha: 0.9),
      );

      // 3. Draw Month Label - Below point
      // Only show month if it's the first point, the last point, or different from previous
      bool shouldShowMonth = i == 0 || i == points.length - 1;
      if (i > 0) {
        final currentDt = DateTime.tryParse(items[i].invoiceDate);
        final prevDt = DateTime.tryParse(items[i - 1].invoiceDate);
        if (currentDt != null && prevDt != null && currentDt.month != prevDt.month) {
          shouldShowMonth = true;
        }
      }

      if (shouldShowMonth) {
        final dt = DateTime.tryParse(items[i].invoiceDate);
        if (dt != null) {
          final monthLabel = DateFormat('MMM').format(dt);
          _drawText(
            canvas,
            monthLabel,
            points[i] + const Offset(0, 18), // Offset below
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary.withValues(alpha: 0.6),
          );
        }
      }
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset center, {
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  Color _getTrendColor(InventoryItem item) {
    if ((item.priceHikeAmount ?? 0) > 0) return const Color(0xFFDC2626); // red
    if ((item.priceHikeAmount ?? 0) < 0) return const Color(0xFF16A34A); // green
    return AppTheme.primary;
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    // In a real app we'd compare the lists properly
    return true;
  }
}
