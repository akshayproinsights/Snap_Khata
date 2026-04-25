enum LedgerType { customer, supplier }

class UnifiedLedger {
  final int id;
  final String name;
  final String? phone;
  final double balanceDue;
  final DateTime? lastActivityDate;
  final LedgerType type;
  final dynamic originalLedger;

  UnifiedLedger({
    required this.id,
    required this.name,
    this.phone,
    required this.balanceDue,
    this.lastActivityDate,
    required this.type,
    required this.originalLedger,
  });
}
