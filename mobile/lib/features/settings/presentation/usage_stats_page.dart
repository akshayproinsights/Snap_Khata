import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/settings/presentation/providers/usage_provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

class UsageStatsPage extends ConsumerStatefulWidget {
  const UsageStatsPage({super.key});

  @override
  ConsumerState<UsageStatsPage> createState() => _UsageStatsPageState();
}

class _UsageStatsPageState extends ConsumerState<UsageStatsPage> {
  String _usageFilter = 'Today';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final usageAsyncValue = ref.watch(usageStatsProvider);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: const Text('Orders Processed', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: usageAsyncValue.when(
        data: (data) {
          return _buildUsageContent(context, isDark, data);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Failed to load usage stats: $err')),
      ),
    );
  }

  Widget _buildUsageContent(BuildContext context, bool isDark, Map<String, dynamic> data) {
    // API returns a Map with keys: '1 Week', '1 Month', 'All Time'
    // Each key contains: {'customer_orders': [], 'supplier_orders': [], 'labels': [], 'total_customer': int, 'total_supplier': int}

    final currentData = data[_usageFilter] ?? {
      'customer_orders': [],
      'supplier_orders': [],
      'labels': [],
      'total_customer': 0,
      'total_supplier': 0
    };

    List<int> customerOrders = List<int>.from(currentData['customer_orders'] ?? []);
    List<int> supplierOrders = List<int>.from(currentData['supplier_orders'] ?? []);
    List<String> xLabels = List<String>.from(currentData['labels'] ?? []);
    
    int totalCustomer = currentData['total_customer'] ?? 0;
    int totalSupplier = currentData['total_supplier'] ?? 0;
    int totalProcessed = totalCustomer + totalSupplier;

    // Calculate dynamic maxY
    double currentMaxY = 10;
    for (int i = 0; i < customerOrders.length; i++) {
      if (customerOrders[i] > currentMaxY) currentMaxY = customerOrders[i].toDouble();
      if (i < supplierOrders.length && supplierOrders[i] > currentMaxY) currentMaxY = supplierOrders[i].toDouble();
    }
    double maxY = currentMaxY * 1.2; // 20% margin top

    final customerColor = const Color(0xFF0EA5E9);
    final supplierColor = const Color(0xFF8B5CF6);

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.borderColor, width: 0.5),
            boxShadow: context.premiumShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Orders Processed',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _usageFilter,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: context.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      context,
                      'Customer',
                      totalCustomer.toString(),
                      customerColor,
                      LucideIcons.users,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      context,
                      'Supplier',
                      totalSupplier.toString(),
                      supplierColor,
                      LucideIcons.package,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildSummaryCard(
                context,
                'Total Orders Processed',
                totalProcessed.toString(),
                context.primaryColor,
                LucideIcons.barChart3,
                isFullWidth: true,
              ),
              const SizedBox(height: 24),
              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Today', '1 Week', '1 Month', 'All Time'].map((filter) {
                    final isSelected = _usageFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(filter, style: const TextStyle(fontSize: 12)),
                        selected: isSelected,
                        showCheckmark: false,
                        selectedColor: context.primaryColor.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: isSelected ? context.primaryColor : context.textSecondaryColor,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        backgroundColor: context.surfaceColor,
                        side: BorderSide(
                          color: isSelected ? context.primaryColor : context.borderColor,
                        ),
                        onSelected: (selected) {
                          setState(() {
                            _usageFilter = filter;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              // Legends
              Row(
                children: [
                  _buildLegendItem('Customers ($totalCustomer)', customerColor),
                  const SizedBox(width: 16),
                  _buildLegendItem('Suppliers ($totalSupplier)', supplierColor),
                ],
              ),
              const SizedBox(height: 32),
              if (customerOrders.isEmpty && supplierOrders.isEmpty)
                const SizedBox(
                  height: 160,
                  child: Center(child: Text("No data to show.")),
                )
              else
                SizedBox(
                  height: 250,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            String type = rodIndex == 0 ? "Customer" : "Supplier";
                            return BarTooltipItem(
                              '$type\n',
                              TextStyle(
                                color: rod.color,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              children: [
                                TextSpan(
                                  text: rod.toY.toInt().toString(),
                                  style: TextStyle(
                                    color: context.textColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: TextStyle(
                                  color: context.textSecondaryColor,
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < xLabels.length) {
                                // For Month, only show every 5th label to avoid crowding
                                if (_usageFilter == '1 Month') {
                                  if (index % 5 == 0) {
                                    return SideTitleWidget(
                                      meta: meta,
                                      child: Text(xLabels[index], style: const TextStyle(fontSize: 10)),
                                    );
                                  }
                                } else {
                                  return SideTitleWidget(
                                    meta: meta,
                                    child: Text(xLabels[index], style: const TextStyle(fontSize: 10)),
                                  );
                                }
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxY / 4 > 0 ? maxY / 4 : 10,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: context.borderColor.withValues(alpha: 0.3),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: customerOrders.asMap().entries.map((e) {
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: e.value.toDouble(),
                              color: customerColor,
                              width: 8,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                            BarChartRodData(
                              toY: (e.key < supplierOrders.length ? supplierOrders[e.key] : 0).toDouble(),
                              color: supplierColor,
                              width: 8,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ]
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: context.textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context, String title, String value, Color color, IconData icon, {bool isFullWidth = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: isFullWidth ? 14 : 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isFullWidth ? 28 : 24,
              fontWeight: FontWeight.bold,
              color: context.textColor,
            ),
          ),
        ],
      ),
    );
  }
}
