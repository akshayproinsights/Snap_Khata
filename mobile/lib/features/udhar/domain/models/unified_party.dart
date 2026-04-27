import 'package:mobile/features/udhar/domain/models/udhar_models.dart';
import 'package:mobile/features/inventory/domain/models/vendor_ledger_models.dart';

enum PartyType { customer, supplier }

class UnifiedParty {
  final int id;
  final String name;
  final String? phone;
  final double balance; // Positive means Receivable (To Collect), Negative means Payable (To Pay)
  final PartyType type;
  final DateTime? lastPaymentDate;
  final DateTime? lastTransactionDate;
  final dynamic originalLedger;

  UnifiedParty({
    required this.id,
    required this.name,
    this.phone,
    required this.balance,
    required this.type,
    this.lastPaymentDate,
    this.lastTransactionDate,
    required this.originalLedger,
  });

  factory UnifiedParty.fromJson(Map<String, dynamic> json) {
    return UnifiedParty(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String?,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      type: json['type'] == 'supplier' ? PartyType.supplier : PartyType.customer,
      lastPaymentDate: json['last_payment_date'] != null
          ? DateTime.parse(json['last_payment_date'])
          : null,
      lastTransactionDate: json['last_transaction_date'] != null
          ? DateTime.parse(json['last_transaction_date'])
          : null,
      originalLedger: null,
    );
  }

  // Getters for backwards compatibility
  String get partyName => name;
  double get balanceDue => balance;

  factory UnifiedParty.fromCustomer(CustomerLedger ledger) {
    return UnifiedParty(
      id: ledger.id,
      name: ledger.customerName,
      phone: ledger.customerPhone,
      balance: ledger.balanceDue,
      type: PartyType.customer,
      lastPaymentDate: ledger.lastPaymentDate,
      lastTransactionDate: ledger.lastPaymentDate,
      originalLedger: ledger,
    );
  }

  factory UnifiedParty.fromVendor(VendorLedger ledger) {
    return UnifiedParty(
      id: ledger.id,
      name: ledger.vendorName,
      phone: null, // VendorLedger doesn't have a phone number in the current model
      balance: -ledger.balanceDue, // Negative for Payable
      type: PartyType.supplier,
      lastPaymentDate: ledger.lastPaymentDate,
      lastTransactionDate: ledger.lastPaymentDate,
      originalLedger: ledger,
    );
  }
}
