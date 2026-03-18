class LedgerDashboardSummary {
  final double totalReceivable;
  final double totalPayable;
  final List<DailyCashflow> chartData;

  LedgerDashboardSummary({
    required this.totalReceivable,
    required this.totalPayable,
    required this.chartData,
  });

  factory LedgerDashboardSummary.fromJson(Map<String, dynamic> json) {
    return LedgerDashboardSummary(
      totalReceivable:
          double.tryParse(json['total_receivable']?.toString() ?? '0') ?? 0.0,
      totalPayable:
          double.tryParse(json['total_payable']?.toString() ?? '0') ?? 0.0,
      chartData: (json['chart_data'] as List?)
              ?.map((e) => DailyCashflow.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class DailyCashflow {
  final String date;
  final double cashIn;
  final double cashOut;
  final double netCashflow;

  DailyCashflow({
    required this.date,
    required this.cashIn,
    required this.cashOut,
    required this.netCashflow,
  });

  factory DailyCashflow.fromJson(Map<String, dynamic> json) {
    return DailyCashflow(
      date: json['date'] ?? '',
      cashIn: double.tryParse(json['cash_in']?.toString() ?? '0') ?? 0.0,
      cashOut: double.tryParse(json['cash_out']?.toString() ?? '0') ?? 0.0,
      netCashflow:
          double.tryParse(json['net_cashflow']?.toString() ?? '0') ?? 0.0,
    );
  }
}
