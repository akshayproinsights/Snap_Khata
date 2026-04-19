import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';

enum GstMode { included, excluded, none }


class PaymentSummaryCard extends StatelessWidget {
  final bool isAutomobile;
  final GstMode gstMode;
  final double partsSubtotal; // sum of taxable items
  final double laborSubtotal; // sum of non-taxable items
  final double gstAmount; // Total GST
  final double grandTotal; // parts + labor + GST (if excluded)
  final double originalTotal; // original total from header or simple sum
  final void Function(GstMode) onGstModeChanged;

  const PaymentSummaryCard({
    super.key,
    this.isAutomobile = true,
    required this.gstMode,
    required this.partsSubtotal,
    required this.laborSubtotal,
    required this.gstAmount,
    required this.grandTotal,
    required this.originalTotal,
    required this.onGstModeChanged,
  });

  String _fmt(double v) {
    final s = v.toStringAsFixed(2);
    return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
  }

  @override
  Widget build(BuildContext context) {
    final isGstInvoice = gstMode != GstMode.none;
    final hasLabor = laborSubtotal > 0.01;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isGstInvoice
              ? [const Color(0xFF0F172A), const Color(0xFF1E3A5F)]
              : [const Color(0xFF0F172A), const Color(0xFF1A2A3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: Theme.of(context).brightness == Brightness.light
            ? AppTheme.premiumShadow
            : AppTheme.darkPremiumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card Header ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.receipt,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Payment Summary',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        )),
                    Text(
                      isGstInvoice
                          ? (isAutomobile ? 'GST Invoice @18% on Parts & Labor' : 'GST Invoice @18%')
                          : 'Order Summary',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Invoice Type Toggle ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _TypePill(
                    label: '📋 Order Summary',
                    selected: gstMode == GstMode.none,
                    onTap: () => onGstModeChanged(GstMode.none),
                  ),
                  const SizedBox(width: 4),
                  _TypePill(
                    label: '🧾 GST Invoice',
                    selected: isGstInvoice,
                    onTap: () => onGstModeChanged(GstMode.included),
                  ),
                ],
              ),
            ),
          ),

          // ── Include / Exclude sub-toggle ─────────────────────────────────
          if (isGstInvoice) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.25), width: 0.5),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _GstModePill(
                      label: 'Included in price',
                      sublabel: 'GST inside bill total',
                      selected: gstMode == GstMode.included,
                      onTap: () => onGstModeChanged(GstMode.included),
                    ),
                    const SizedBox(width: 4),
                    _GstModePill(
                      label: 'Exclude (add on top)',
                      sublabel: 'GST added to total',
                      selected: gstMode == GstMode.excluded,
                      onTap: () => onGstModeChanged(GstMode.excluded),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),


          // ── Divider ──────────────────────────────────────────────────────
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            color: Colors.white.withValues(alpha: 0.08),
          ),

          // ── Amount Breakdown ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              children: [
                _AmountRow(
                  label: isAutomobile ? 'Parts Subtotal' : 'Subtotal',
                  value: '₹${_fmt(partsSubtotal + (isAutomobile ? 0 : laborSubtotal))}',
                  labelColor: Colors.white.withValues(alpha: 0.7),
                  valueColor: Colors.white.withValues(alpha: 0.9),
                ),
                if (isAutomobile && hasLabor) ...[
                  const SizedBox(height: 8),
                  _AmountRow(
                    label: 'Labor / Service (no GST)',
                    value: '₹${_fmt(laborSubtotal)}',
                    labelColor: Colors.white.withValues(alpha: 0.45),
                    valueColor: Colors.white.withValues(alpha: 0.5),
                  ),
                ],
                if (isGstInvoice) ...[
                  const SizedBox(height: 10),
                  _AmountRow(
                    label: gstMode == GstMode.included
                        ? 'GST @18% (included within)'
                        : 'GST @18% (excluded, added on top)',
                    value: gstMode == GstMode.included
                        ? '₹${_fmt(gstAmount)} ✓'
                        : '+ ₹${_fmt(gstAmount)}',
                    labelColor: const Color(0xFFFBBF24),
                    valueColor: const Color(0xFFFBBF24),
                  ),
                ],
                const SizedBox(height: 14),
                Container(height: 0.5, color: Colors.white.withValues(alpha: 0.12)),
                const SizedBox(height: 14),
                // Grand Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Amount',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        )),
                    Text(
                      '₹${_fmt(grandTotal)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                // Excluded GST delta notice
                if (gstMode == GstMode.excluded &&
                    grandTotal > originalTotal) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 0.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.alertTriangle,
                            color: Color(0xFFFBBF24), size: 13),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Excluded GST adds ₹${_fmt(gstAmount)} — '
                            'new total ₹${_fmt(grandTotal)} '
                            '(original: ₹${_fmt(originalTotal)})',
                            style: const TextStyle(
                              color: Color(0xFFFBBF24),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (gstMode == GstMode.included) ...[
                  const SizedBox(height: 8),
                  Text(
                    'GST @18% is already included within the prices.',
                    style: TextStyle(
                      color: Colors.greenAccent.withValues(alpha: 0.75),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _TypePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? const Color(0xFF0F172A) : Colors.white54,
            ),
          ),
        ),
      ),
    );
  }
}

class _GstModePill extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool selected;
  final VoidCallback onTap;

  const _GstModePill({
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color:
                selected ? Colors.amber.withValues(alpha: 0.85) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? const Color(0xFF0F172A) : Colors.white54,
                ),
              ),
              Text(
                sublabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: selected
                      ? const Color(0xFF0F172A).withValues(alpha: 0.7)
                      : Colors.white30,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;

  const _AmountRow({
    required this.label,
    required this.value,
    required this.labelColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: labelColor, fontSize: 13),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
