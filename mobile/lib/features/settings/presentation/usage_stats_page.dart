import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/settings/presentation/providers/usage_provider.dart';

class UsageStatsPage extends ConsumerStatefulWidget {
  const UsageStatsPage({super.key});

  @override
  ConsumerState<UsageStatsPage> createState() => _UsageStatsPageState();
}

class _UsageStatsPageState extends ConsumerState<UsageStatsPage> {
  String _usageFilter = '1 Week';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final usageAsyncValue = ref.watch(usageStatsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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

    int maxX = (xLabels.isNotEmpty ? xLabels.length - 1 : 0);

    final customerColor = const Color(0xFF0EA5E9);
    final supplierColor = const Color(0xFF8B5CF6);

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5),
            boxShadow: Theme.of(context).brightness == Brightness.light
                ? AppTheme.premiumShadow
                : AppTheme.darkPremiumShadow,
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
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Total: $totalProcessed',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['1 Week', '1 Month', 'All Time'].map((filter) {
                    final isSelected = _usageFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(filter, style: const TextStyle(fontSize: 12)),
                        selected: isSelected,
                        showCheckmark: false,
                        selectedColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                        labelStyle: TextStyle(
                          color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        side: BorderSide(
                          color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
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
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxY / 4 > 0 ? maxY / 4 : 10,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                            strokeWidth: 1,
                            dashArray: [4, 4],
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              const style = TextStyle(
                                fontSize: 10,
                              );
                              final color = Theme.of(context).colorScheme.onSurfaceVariant;
                              final index = value.toInt();
                              Widget text;
                              if (index >= 0 && index < xLabels.length) {
                                if (_usageFilter == '1 Week' || _usageFilter == '1 Month') {
                                  if (index % 2 == 0) {
                                    text = Text(xLabels[index], style: style.copyWith(color: color));
                                  } else {
                                    text = const Text('', style: style);
                                  }
                                } else {
                                  text = Text(xLabels[index], style: style.copyWith(color: color));
                                }
                              } else {
                                text = const Text('', style: style);
                              }
                              
                              return SideTitleWidget(
                                meta: meta,
                                child: text,
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: maxX.toDouble(),
                      minY: 0,
                      maxY: maxY,
                      lineBarsData: [
                        LineChartBarData(
                          spots: customerOrders.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.toDouble())).toList(),
                          isCurved: true,
                          color: customerColor,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: customerColor.withValues(alpha: 0.1),
                          ),
                        ),
                        LineChartBarData(
                          spots: supplierOrders.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.toDouble())).toList(),
                          isCurved: true,
                          color: supplierColor,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: supplierColor.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
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
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
