class ChartDataPoint {
  final String date;
  final double cashIn;
  final double cashOut;
  final double netCashflow;

  ChartDataPoint({
    required this.date,
    required this.cashIn,
    required this.cashOut,
    required this.netCashflow,
  });

  factory ChartDataPoint.fromJson(Map<String, dynamic> json) {
    return ChartDataPoint(
      date: json['date'] as String,
      cashIn: double.tryParse(json['cash_in']?.toString() ?? '0') ?? 0.0,
      cashOut: double.tryParse(json['cash_out']?.toString() ?? '0') ?? 0.0,
      netCashflow: double.tryParse(json['net_cashflow']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class DashboardSummary {
  final double totalReceivable;
  final double totalPayable;
  final List<ChartDataPoint> chartData;

  DashboardSummary({
    required this.totalReceivable,
    required this.totalPayable,
    required this.chartData,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      totalReceivable: double.tryParse(json['total_receivable']?.toString() ?? '0') ?? 0.0,
      totalPayable: double.tryParse(json['total_payable']?.toString() ?? '0') ?? 0.0,
      chartData: (json['chart_data'] as List?)
              ?.map((e) => ChartDataPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
