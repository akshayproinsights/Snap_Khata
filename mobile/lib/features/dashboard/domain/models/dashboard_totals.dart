class DashboardTotals {
  final double totalReceivable;
  final double totalPayable;

  const DashboardTotals({
    required this.totalReceivable,
    required this.totalPayable,
  });

  factory DashboardTotals.initial() => const DashboardTotals(
        totalReceivable: 0.0,
        totalPayable: 0.0,
      );
}
