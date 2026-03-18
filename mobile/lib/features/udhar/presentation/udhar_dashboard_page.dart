import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/udhar/presentation/udhar_list_page.dart';
import 'package:mobile/features/inventory/presentation/vendor_ledger/vendor_ledger_list_page.dart';
import 'package:mobile/features/udhar/presentation/providers/udhar_dashboard_provider.dart';
import 'package:mobile/features/udhar/presentation/providers/udhar_search_provider.dart';
import 'package:mobile/features/udhar/presentation/widgets/add_udhar_entry_sheet.dart';

class UdharDashboardPage extends ConsumerWidget {
  const UdharDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(udharDashboardProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Udhar / Ledger Dashboard'),
        ),
        body: dashboardState.isLoading && dashboardState.summary == null
            ? const Center(child: CircularProgressIndicator())
            : dashboardState.error != null && dashboardState.summary == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(dashboardState.error!),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref
                              .read(udharDashboardProvider.notifier)
                              .fetchSummary(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Net Outstanding Dues Card
                      _buildSummaryCard(dashboardState.summary?.totalReceivable ?? 0.0,
                          dashboardState.summary?.totalPayable ?? 0.0),
                      
                      const SizedBox(height: 16),

                      // Bar Chart
                      _buildChart(dashboardState.summary?.chartData ?? []),

                      const SizedBox(height: 16),

                      // Tabs
                      const TabBar(
                        tabs: [
                          Tab(text: 'Customers (Receivables)'),
                          Tab(text: 'Suppliers (Payables)'),
                        ],
                        labelColor: AppTheme.primary,
                        unselectedLabelColor: AppTheme.textSecondary,
                        indicatorColor: AppTheme.primary,
                      ),
                      
                      // Search Bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Search Party Name...',
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                                ),
                                onChanged: (value) {
                                  ref.read(udharSearchQueryProvider.notifier).setQuery(value);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.filter_list),
                                onPressed: () {
                                  // Optional: Add filter bottom sheet logic later
                                },
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      
                      // Tab Views
                      const Expanded(
                        child: TabBarView(
                          children: [
                            UdharListPage(),
                            VendorLedgerListPage(),
                          ],
                        ),
                      ),
                    ],
                  ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (context) => const AddUdharEntrySheet(),
            );
          },
          label: const Text('New Udhar Entry'),
          icon: const Icon(Icons.add),
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSummaryCard(double receivable, double payable) {
    final currencyFormatter =
        NumberFormat.currency(symbol: '₹', decimalDigits: 2, locale: 'en_IN');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOU WILL GET\n(RECEIVABLE)',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  currencyFormatter.format(receivable),
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: Colors.grey.shade300,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOU WILL GIVE\n(PAYABLE)',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  currencyFormatter.format(payable),
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(List dataPoints) {
    if (dataPoints.isEmpty) {
      return const SizedBox(
        height: 150,
        child: Center(child: Text('No recent transaction data')),
      );
    }

    // Prepare chart data
    final barGroups = <BarChartGroupData>[];
    double maxY = 0.0;
    double minY = 0.0;

    for (int i = 0; i < dataPoints.length; i++) {
        final point = dataPoints[i];
        final netFlow = point.netCashflow;
        
        if (netFlow > maxY) maxY = netFlow;
        if (netFlow < minY) minY = netFlow;

        barGroups.add(
            BarChartGroupData(
                x: i,
                barRods: [
                    BarChartRodData(
                        toY: netFlow,
                        color: netFlow >= 0 ? Colors.green : Colors.red,
                        width: 16,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                          bottomLeft: Radius.circular(0),
                          bottomRight: Radius.circular(0),
                        ),
                    ),
                ],
            ),
        );
    }

    // Add some padding to Y axis
    maxY = maxY > 0 ? maxY * 1.2 : 0;
    minY = minY < 0 ? minY * 1.2 : 0;
    if (maxY == 0 && minY == 0) {
      maxY = 100;
      minY = -100;
    }

    return Container(
      height: 180,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          minY: minY,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < dataPoints.length) {
                    // Show dates selectively, e.g., first, middle, last to avoid crowding
                    if (index == 0 || index == dataPoints.length - 1 || index == dataPoints.length ~/ 2) {
                        try {
                           final dateStr = dataPoints[index].date;
                           final dateObj = DateTime.parse(dateStr);
                           final formatted = DateFormat('dd MMM').format(dateObj);
                           return Padding(
                             padding: const EdgeInsets.only(top: 8.0),
                             child: Text(formatted, style: const TextStyle(fontSize: 10)),
                           );
                        } catch(e) {
                           return const SizedBox();
                        }
                    }
                  }
                  return const SizedBox();
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) {
                if (value == 0) {
                   return FlLine(color: Colors.grey.shade400, strokeWidth: 1.5);
                }
                return const FlLine(color: Colors.transparent, strokeWidth: 0);
            },
          ),
          borderData: FlBorderData(show: false),
          barGroups: barGroups,
        ),
      ),
    );
  }
}
