import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/dashboard/presentation/providers/analytics_provider.dart';
import 'package:mobile/features/dashboard/domain/models/dashboard_models.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AnalyticsDashboardPage extends ConsumerStatefulWidget {
  const AnalyticsDashboardPage({super.key});

  @override
  ConsumerState<AnalyticsDashboardPage> createState() => _AnalyticsDashboardPageState();
}

class _AnalyticsDashboardPageState extends ConsumerState<AnalyticsDashboardPage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final analyticsState = ref.watch(analyticsProvider);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: const Text('Dashboard Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: analyticsState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : analyticsState.error != null
              ? Center(child: Text('Error: ${analyticsState.error}'))
              : analyticsState.analytics == null
                  ? const Center(child: Text('No data available'))
                  : _buildContent(context, isDark, analyticsState.analytics!),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark, DashboardAnalytics data) {
    final analyticsState = ref.watch(analyticsProvider);
    
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Filter Toggle
        _buildFilterToggle(context, analyticsState.days),
        const SizedBox(height: 16),
        
        // Summary Cards
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                context,
                'Total Sales',
                '₹${data.totalSalesAmount}',
                '${data.totalSalesCount} Bills',
                const Color(0xFF0EA5E9),
                LucideIcons.arrowUpRight,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                context,
                'Total Purchases',
                '₹${data.totalPurchaseAmount}',
                '${data.totalPurchaseCount} Bills',
                const Color(0xFF8B5CF6),
                LucideIcons.arrowDownLeft,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        
        // Chart 1: Sales
        _buildChartContainer(
          context,
          'Sales (Customer)',
          data.sales,
          const Color(0xFF0EA5E9),
        ),
        const SizedBox(height: 20),
        
        // Chart 2: Purchases
        _buildChartContainer(
          context,
          'Purchases (Supplier)',
          data.purchases,
          const Color(0xFF8B5CF6),
        ),
      ],
    );
  }

  Widget _buildFilterToggle(BuildContext context, int currentDays) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor, width: 0.5),
      ),
      child: Row(
        children: [
          _buildFilterButton(context, '1 Week', 7, currentDays == 7),
          _buildFilterButton(context, '1 Month', 30, currentDays == 30),
          _buildFilterButton(context, 'All Time', 365, currentDays == 365),
        ],
      ),
    );
  }

  Widget _buildFilterButton(BuildContext context, String label, int days, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(analyticsProvider.notifier).changePeriod(days),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? context.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : context.textColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    String value,
    String subtitle,
    Color color,
    IconData icon,
  ) {
    return Container(
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
              Text(
                title,
                style: TextStyle(
                  color: context.textSecondaryColor,
                  fontSize: 12,
                ),
              ),
              Icon(icon, color: color, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: context.textSecondaryColor,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartContainer(
    BuildContext context,
    String title,
    List<AnalyticsDataPoint> points,
    Color color,
  ) {
    double maxY = 10;
    for (var p in points) {
      if (p.amount > maxY) maxY = p.amount.toDouble();
    }
    maxY = maxY * 1.2; // 20% margin

    return Container(
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: points.isEmpty
                ? const Center(child: Text('No data for this period'))
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              '₹${rod.toY.toInt()}',
                              TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
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
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              if (value == 0) return const SizedBox();
                              return Text(
                                '₹${(value / 1000).toStringAsFixed(1)}k',
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
                              if (index >= 0 && index < points.length) {
                                final dateStr = points[index].date;
                                final parts = dateStr.split('-');
                                if (parts.length >= 3) {
                                  return SideTitleWidget(
                                    meta: meta,
                                    child: Text('${parts[2]}/${parts[1]}', style: const TextStyle(fontSize: 10)),
                                  );
                                }
                                return SideTitleWidget(
                                  meta: meta,
                                  child: Text(dateStr, style: const TextStyle(fontSize: 10)),
                                );
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
                      barGroups: points.asMap().entries.map((e) {
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: e.value.amount.toDouble(),
                              color: color,
                              width: 12,
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
    );
  }
}
