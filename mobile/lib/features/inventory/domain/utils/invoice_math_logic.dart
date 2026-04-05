class InvoiceMathLogic {
  static const double toleranceLimit = 2.00;

  /// Replicates Python's Decimal quantization: Decimal.quantize('0.01', ROUND_HALF_UP)
  /// Using (value * 100).round() / 100 is equivalent to half-up for positive values,
  /// but we should handle it cleanly.
  static double roundToPaise(double value) {
    return (value * 100).round() / 100.0;
  }

  static double calculateGross(double qty, double rate) {
    return roundToPaise(qty * rate);
  }

  static Map<String, double> calculateDiscounts(
      double gross, double discPct, double discAmt) {
    if (discPct > 0 && discAmt == 0) {
      discAmt = roundToPaise(gross * discPct / 100);
    } else if (discAmt > 0 && discPct == 0) {
      discPct = gross > 0 ? roundToPaise(discAmt / gross * 100) : 0.0;
    } else if (discPct > 0 && discAmt > 0) {
      // Both provided - validate and trust amount if there's a discrepancy > 1.0
      double calculatedAmt = roundToPaise(gross * discPct / 100);
      if ((calculatedAmt - discAmt).abs() > 1.0) {
        discPct = gross > 0 ? roundToPaise(discAmt / gross * 100) : 0.0;
      }
    }

    double taxable = roundToPaise(gross - discAmt);
    return {
      'discPct': discPct,
      'discAmt': discAmt,
      'taxable': taxable,
    };
  }

  static Map<String, double> calculateTax(
      double taxable, double cgstPct, double sgstPct, double igstPct) {
    double cgstAmt = roundToPaise(taxable * cgstPct / 100);
    double sgstAmt = roundToPaise(taxable * sgstPct / 100);
    double igstAmt = roundToPaise(taxable * igstPct / 100);

    return {
      'cgstAmt': cgstAmt,
      'sgstAmt': sgstAmt,
      'igstAmt': igstAmt,
    };
  }

  static Map<String, dynamic> processItem({
    required double qty,
    required double rate,
    required double origDiscPct,
    required double origDiscAmt,
    required double cgstPct,
    required double sgstPct,
    required double igstPct,
    required double printedTotal,
    required String taxType,
    double combinedGstPct = 0.0,
  }) {
    // 1. Route combined GST
    if (taxType == 'COMBINED_GST') {
      taxType = 'CGST_SGST';
      cgstPct = combinedGstPct / 2.0;
      sgstPct = combinedGstPct / 2.0;
      igstPct = 0.0;
    }

    // 2. Gross calculation
    double gross = calculateGross(qty, rate);

    // 3. Discount Classification
    String discType = 'NONE';
    if (origDiscPct > 0 && origDiscAmt > 0) {
      discType = 'BOTH';
    } else if (origDiscPct > 0) {
      discType = 'PERCENT';
    } else if (origDiscAmt > 0) {
      discType = 'AMOUNT';
    }

    // 4. Discounts logic - always from GROSS
    var discountRes = calculateDiscounts(gross, origDiscPct, origDiscAmt);
    double discPct = discountRes['discPct']!;
    double discAmt = discountRes['discAmt']!;
    double taxable = discountRes['taxable']!;

    // 5. Tax logic
    var taxRes = calculateTax(taxable, cgstPct, sgstPct, igstPct);
    double cgstAmt = taxRes['cgstAmt']!;
    double sgstAmt = taxRes['sgstAmt']!;
    double igstAmt = taxRes['igstAmt']!;

    double taxTotal = cgstAmt + sgstAmt + igstAmt;
    double netAmount = roundToPaise(taxable + taxTotal);

    // 6. Mismatch calculation
    double mismatch = 0.0;
    bool needsReview = false;

    if (printedTotal > 0) {
      mismatch = (netAmount - printedTotal).abs();
      needsReview = mismatch > toleranceLimit;
    }

    return {
      'grossAmount': gross,
      'discType': discType,
      'discPercent': discPct,
      'discAmount': discAmt,
      'taxableAmount': taxable,
      'cgstPercent': cgstPct,
      'cgstAmount': cgstAmt,
      'sgstPercent': sgstPct,
      'sgstAmount': sgstAmt,
      'igstPercent': igstPct,
      'igstAmount': igstAmt,
      'netAmount': netAmount,
      'printedTotal': printedTotal,
      'mismatchAmount': mismatch,
      'needsReview': needsReview,
      'taxType': taxType,
    };
  }
}
