import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/dashboard/domain/models/dashboard_models.dart';
import 'package:mobile/shared/widgets/shimmer_placeholders.dart';

/// Enhanced Sales Trend Chart with:
/// - Total Revenue line (blue)
/// - Parts Revenue line (green dashed)
/// - Labour Revenue line (orange dashed)
/// - Toggle legend to show/hide breakdown
class SalesTrendChart extends StatefulWidget {
  final List<DailySalesVolume> data;
  final bool isLoading;

  const SalesTrendChart({
    super.key,
    required this.data,
    this.isLoading = false,
  });

  @override
  State<SalesTrendChart> createState() => _SalesTrendChartState();
}

class _SalesTrendChartState extends State<SalesTrendChart> {
  bool _showBreakdown = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) return const ChartShimmer();

    if (widget.data.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        height: 300,
        child: const Center(
          child: Text('No sales data available for this period',
              style: TextStyle(color: AppTheme.textSecondary)),
        ),
      );
    }

    final data = widget.data;

    // Build spots for each series
    final totalSpots = <FlSpot>[];
    final partsSpots = <FlSpot>[];
    final labourSpots = <FlSpot>[];
    double maxY = 0;

    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      if (item.revenue > maxY) maxY = item.revenue;
      totalSpots.add(FlSpot(i.toDouble(), item.revenue));
      partsSpots.add(FlSpot(i.toDouble(), item.partsRevenue));
      labourSpots.add(FlSpot(i.toDouble(), item.laborRevenue));
    }

    maxY = maxY > 0 ? maxY * 1.25 : 100;


    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sales Trends',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              // Breakdown toggle
              GestureDetector(
                onTap: () => setState(() => _showBreakdown = !_showBreakdown),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _showBreakdown
                        ? AppTheme.primary.withValues(alpha: 0.12)
                        : AppTheme.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          _showBreakdown ? AppTheme.primary : AppTheme.border,
                    ),
                  ),
                  child: Text(
                    _showBreakdown ? 'Hide Breakdown' : 'Parts/Labour',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _showBreakdown
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Legend (when breakdown shown)
          if (_showBreakdown) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                _LegendDot(color: AppTheme.primary, label: 'Total'),
                SizedBox(width: 16),
                _LegendDot(color: AppTheme.success, label: 'Parts'),
                SizedBox(width: 16),
                _LegendDot(color: AppTheme.warning, label: 'Labour'),
              ],
            ),
          ],

          const SizedBox(height: 16),

          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: AppTheme.border,
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: data.length > 7
                          ? (data.length / 5).ceilToDouble()
                          : 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= data.length) {
                          return const SizedBox.shrink();
                        }
                        try {
                          final date = DateTime.parse(data[index].date);
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              DateFormat('dd-MM-yyyy').format(date),
                              style: const TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 9),
                            ),
                          );
                        } catch (_) {
                          return const SizedBox.shrink();
                        }
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: maxY / 4 == 0 ? 1 : maxY / 4,
                      reservedSize: 44,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Text(
                          CurrencyFormatter.formatCompact(value),
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 9),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (data.length - 1).toDouble(),
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  // Total Revenue — bold primary line
                  _buildLine(totalSpots, AppTheme.primary,
                      barWidth: 3, dashed: false),
                  // Parts — shown only when breakdown active
                  if (_showBreakdown)
                    _buildLine(partsSpots, AppTheme.success,
                        barWidth: 2, dashed: true),
                  if (_showBreakdown)
                    _buildLine(labourSpots, AppTheme.warning,
                        barWidth: 2, dashed: true),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF1E293B),
                    getTooltipItems: (spots) {
                      return spots.map((s) {
                        final index = s.x.toInt();
                        final dateStr =
                            index < data.length ? data[index].date : '';
                        final date = DateTime.tryParse(dateStr);
                        final label = date != null
                            ? DateFormat('dd-MM-yyyy').format(date)
                            : dateStr;
                        return LineTooltipItem(
                          '$label\n${CurrencyFormatter.format(s.y)}',
                          const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  LineChartBarData _buildLine(
    List<FlSpot> spots,
    Color color, {
    double barWidth = 3,
    bool dashed = false,
  }) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: barWidth,
      isStrokeCapRound: true,
      dashArray: dashed ? [6, 4] : null,
      dotData: const FlDotData(show: false),
      belowBarData: dashed
          ? BarAreaData(show: false)
          : BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.08),
            ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}
