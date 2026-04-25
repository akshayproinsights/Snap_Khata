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
  final dynamic originalLedger;

  UnifiedParty({
    required this.id,
    required this.name,
    this.phone,
    required this.balance,
    required this.type,
    this.lastPaymentDate,
    required this.originalLedger,
  });

  factory UnifiedParty.fromCustomer(CustomerLedger ledger) {
    return UnifiedParty(
      id: ledger.id,
      name: ledger.customerName,
      phone: ledger.customerPhone,
      balance: ledger.balanceDue,
      type: PartyType.customer,
      lastPaymentDate: ledger.lastPaymentDate,
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
      originalLedger: ledger,
    );
  }
}
