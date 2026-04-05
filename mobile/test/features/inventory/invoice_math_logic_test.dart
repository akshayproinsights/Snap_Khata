import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/inventory/domain/utils/invoice_math_logic.dart';

void main() {
  group('InvoiceMathLogic', () {
    test('1. Simple: qty=10, rate=100 -> gross=1000, net=1180 (18% GST)', () {
      final result = InvoiceMathLogic.processItem(
        qty: 10,
        rate: 100,
        origDiscPct: 0,
        origDiscAmt: 0,
        cgstPct: 9,
        sgstPct: 9,
        igstPct: 0,
        printedTotal: 1180,
        taxType: 'CGST_SGST',
      );

      expect(result['grossAmount'], 1000.0);
      expect(result['taxableAmount'], 1000.0);
      expect(result['cgstAmount'], 90.0);
      expect(result['sgstAmount'], 90.0);
      expect(result['netAmount'], 1180.0);
      expect(result['needsReview'], false);
    });

    test('2. % discount: qty=10, rate=100, disc%=10 -> taxable=900, net=1062', () {
      final result = InvoiceMathLogic.processItem(
        qty: 10,
        rate: 100,
        origDiscPct: 10,
        origDiscAmt: 0,
        cgstPct: 9,
        sgstPct: 9,
        igstPct: 0,
        printedTotal: 1062,
        taxType: 'CGST_SGST',
      );

      expect(result['grossAmount'], 1000.0);
      expect(result['discType'], 'PERCENT');
      expect(result['discAmount'], 100.0);
      expect(result['taxableAmount'], 900.0);
      expect(result['netAmount'], 1062.0);
    });

    test('3. Amount discount: qty=10, rate=100, disc=50 -> taxable=950, net=1121', () {
      final result = InvoiceMathLogic.processItem(
        qty: 10,
        rate: 100,
        origDiscPct: 0,
        origDiscAmt: 50,
        cgstPct: 9,
        sgstPct: 9,
        igstPct: 0,
        printedTotal: 1121,
        taxType: 'CGST_SGST',
      );

      expect(result['grossAmount'], 1000.0);
      expect(result['discType'], 'AMOUNT');
      expect(result['discPercent'], 5.0); // automatically calculated back
      expect(result['taxableAmount'], 950.0);
      expect(result['netAmount'], 1121.0);
    });

    test('4. Missing printed total: assert needsReview == false', () {
      final result = InvoiceMathLogic.processItem(
        qty: 10,
        rate: 100,
        origDiscPct: 0,
        origDiscAmt: 0,
        cgstPct: 9,
        sgstPct: 9,
        igstPct: 0,
        printedTotal: 0, // Not printed
        taxType: 'CGST_SGST',
      );

      expect(result['needsReview'], false);
      expect(result['mismatchAmount'], 0.0);
    });

    test('5. Mismatch within tolerance (1.50): assert needsReview == false', () {
      final result = InvoiceMathLogic.processItem(
        qty: 10,
        rate: 100,
        origDiscPct: 0,
        origDiscAmt: 0,
        cgstPct: 9,
        sgstPct: 9,
        igstPct: 0,
        printedTotal: 1181.50, // net is 1180, diff is 1.50, tolerance is 2.00
        taxType: 'CGST_SGST',
      );

      expect(result['mismatchAmount'], closeTo(1.50, 0.001));
      expect(result['needsReview'], false);
    });

    test('6. Mismatch above tolerance (3): assert needsReview == true', () {
      final result = InvoiceMathLogic.processItem(
        qty: 10,
        rate: 100,
        origDiscPct: 0,
        origDiscAmt: 0,
        cgstPct: 9,
        sgstPct: 9,
        igstPct: 0,
        printedTotal: 1183, // net is 1180, diff is 3.00, tolerance is 2.00
        taxType: 'CGST_SGST',
      );

      expect(result['mismatchAmount'], closeTo(3.00, 0.001));
      expect(result['needsReview'], true);
    });

    test('7. IGST: assert cgstAmount == 0, sgstAmount == 0', () {
      final result = InvoiceMathLogic.processItem(
        qty: 10,
        rate: 100,
        origDiscPct: 0,
        origDiscAmt: 0,
        cgstPct: 0,
        sgstPct: 0,
        igstPct: 18,
        printedTotal: 1180,
        taxType: 'IGST',
      );

      expect(result['igstAmount'], 180.0);
      expect(result['cgstAmount'], 0.0);
      expect(result['sgstAmount'], 0.0);
    });

    test('8. COMBINED_GST: assert splits into 50/50 CGST/SGST', () {
      final result = InvoiceMathLogic.processItem(
        qty: 10,
        rate: 100,
        origDiscPct: 0,
        origDiscAmt: 0,
        cgstPct: 0,
        sgstPct: 0,
        igstPct: 0,
        printedTotal: 1180,
        taxType: 'COMBINED_GST',
        combinedGstPct: 18,
      );

      expect(result['taxType'], 'CGST_SGST');
      expect(result['cgstPercent'], 9.0);
      expect(result['sgstPercent'], 9.0);
      expect(result['cgstAmount'], 90.0);
      expect(result['sgstAmount'], 90.0);
      expect(result['igstAmount'], 0.0);
    });
  });
}
