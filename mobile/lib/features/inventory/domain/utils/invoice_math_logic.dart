class InvoiceMathLogic {
  static const double toleranceLimit = 2.00;

  // ── Grand-Total Rule ─────────────────────────────────────────────────────────
  //
  // SCENARIO A  (hasPerItemDiscount = true)
  //   At least one line item has discAmount > 0 or discPercent > 0.
  //   Each item's netAmount already encodes: gross → taxable (after disc) → +GST.
  //   HEADER_DISCOUNT/SCHEME in the footer are just a recap — do NOT subtract again.
  //   grandTotal = Σ(netAmount) + ROUND_OFF/OTHER adjustments
  //
  // SCENARIO B  (hasPerItemDiscount = false)
  //   No per-item discount. Discount appears only as a footer line on the invoice.
  //   Correct invoice math:  totalGross − headerDiscount = totalTaxable → +GST on taxable.
  //   Because items were calculated with discPct=0, their netAmount = gross * (1 + gstRate).
  //   We correct this by scaling GST proportionally to the discounted taxable base.
  //   grandTotal = totalTaxable + scaledGST + ROUND_OFF/OTHER adjustments
  //
  // Use [computeGrandTotal] as the single source of truth for both scenarios.
  //
  static double computeGrandTotal({
    required List<Map<String, double>> items,
    // Each map must contain: grossAmount, taxableAmount, cgstAmount, sgstAmount, igstAmount, netAmount
    required double headerDiscountAmt,  // sum of all HEADER_DISCOUNT/SCHEME amounts (positive)
    required double nonDiscountAdjAmt,  // sum of ROUND_OFF + OTHER amounts (signed)
    required bool hasPerItemDiscount,
  }) {
    if (hasPerItemDiscount) {
      // Scenario A — discounts already inside netAmounts
      final itemsTotal = items.fold(0.0, (s, i) => s + (i['netAmount'] ?? 0.0));
      return itemsTotal + nonDiscountAdjAmt;
    } else {
      // Scenario B — apply header discount before GST
      final totalGross    = items.fold(0.0, (s, i) => s + (i['grossAmount'] ?? 0.0));
      final totalTaxable  = (totalGross - headerDiscountAmt).clamp(0.0, double.maxFinite);
      final origTaxable   = items.fold(0.0, (s, i) => s + (i['taxableAmount'] ?? i['grossAmount'] ?? 0.0));
      final totalGst      = items.fold(0.0, (s, i) =>
          s + (i['cgstAmount'] ?? 0.0) + (i['sgstAmount'] ?? 0.0) + (i['igstAmount'] ?? 0.0));
      final scaledGst     = origTaxable > 0 ? totalGst * (totalTaxable / origTaxable) : totalGst;
      return totalTaxable + scaledGst + nonDiscountAdjAmt;
    }
  }

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

    // 6. Smart mismatch calculation — mirrors backend classify_and_validate_printed_total
    //    Try gross → taxable → net in order. A genuine mismatch only fires when the
    //    printed value does NOT match ANY of the three candidates within tolerance.
    double mismatch = 0.0;
    bool needsReview = false;
    String printedTotalType = 'NOT_PRINTED';

    if (printedTotal > 0) {
      if ((gross - printedTotal).abs() <= toleranceLimit) {
        // Invoice prints GROSS (pre-disc, pre-tax) as the line total.
        // Common on invoices where discount is a header-level adjustment.
        printedTotalType = 'GROSS';
        mismatch = (gross - printedTotal).abs();
        needsReview = false;
      } else if ((taxable - printedTotal).abs() <= toleranceLimit) {
        // Invoice prints TAXABLE (post-disc, pre-tax) as the line total.
        // Common when GST is aggregated in a footer row.
        printedTotalType = 'TAXABLE';
        mismatch = (taxable - printedTotal).abs();
        needsReview = false;
      } else if ((netAmount - printedTotal).abs() <= toleranceLimit) {
        // Standard invoice — line total is the full NET (post-disc, post-tax).
        printedTotalType = 'NET';
        mismatch = (netAmount - printedTotal).abs();
        needsReview = false;
      } else {
        // Genuine mismatch — printed total doesn't align with any candidate.
        printedTotalType = 'MISMATCH';
        mismatch = (netAmount - printedTotal).abs();
        needsReview = mismatch > toleranceLimit;
      }
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
      'printedTotalType': printedTotalType,
      'taxType': taxType,
    };
  }
}
