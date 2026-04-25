import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/inventory/domain/models/inventory_models.dart';
import 'package:mobile/features/inventory/domain/utils/invoice_math_logic.dart';

class EditItemModal extends StatefulWidget {
  final InventoryItem item;
  final Function(InventoryItem updatedItem) onSave;

  const EditItemModal({
    super.key,
    required this.item,
    required this.onSave,
  });

  static Future<void> show(BuildContext context, InventoryItem item, Function(InventoryItem) onSave) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditItemModal(item: item, onSave: onSave),
    );
  }

  @override
  State<EditItemModal> createState() => _EditItemModalState();
}

class _EditItemModalState extends State<EditItemModal> {
  late TextEditingController _descController;
  late TextEditingController _partNumberController;
  late TextEditingController _hsnController;
  late TextEditingController _qtyController;
  late TextEditingController _rateController;
  late TextEditingController _discPctController;
  late TextEditingController _discAmtController;
  late TextEditingController _cgstPctController;
  late TextEditingController _sgstPctController;
  late TextEditingController _igstPctController;
  late TextEditingController _printedTotalController;
  late TextEditingController _extraAdjController;

  Map<String, dynamic> _previewState = {};

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController(text: widget.item.description);
    _partNumberController = TextEditingController(text: widget.item.partNumber);
    _hsnController = TextEditingController(text: widget.item.hsnCode ?? '');
    _qtyController = TextEditingController(text: _fmt(widget.item.qty));
    _rateController = TextEditingController(text: _fmt(widget.item.rate));

    // --- Discount ---
    final storedDiscAmt = widget.item.discAmount ?? 0.0;
    final grossAmt = widget.item.grossAmount ?? (widget.item.qty * widget.item.rate);
    double inferredDiscPct = widget.item.discPercent ?? 0.0;
    if (inferredDiscPct == 0 && storedDiscAmt > 0 && grossAmt > 0) {
      inferredDiscPct = double.parse((storedDiscAmt / grossAmt * 100).toStringAsFixed(2));
    }
    _discPctController = TextEditingController(text: inferredDiscPct > 0 ? _fmt(inferredDiscPct) : '0');
    _discAmtController = TextEditingController(text: _fmt(storedDiscAmt));

    // --- Tax Rates ---
    final taxable = widget.item.taxableAmount ?? (grossAmt - storedDiscAmt);
    double inferredCgstPct = widget.item.cgstPercent ?? 0.0;
    double inferredSgstPct = widget.item.sgstPercent ?? 0.0;
    double inferredIgstPct = widget.item.igstPercent ?? 0.0;

    if (inferredCgstPct == 0 && (widget.item.cgstAmount ?? 0) > 0 && taxable > 0) {
      inferredCgstPct = double.parse(((widget.item.cgstAmount! / taxable) * 100).toStringAsFixed(2));
    }
    if (inferredSgstPct == 0 && (widget.item.sgstAmount ?? 0) > 0 && taxable > 0) {
      inferredSgstPct = double.parse(((widget.item.sgstAmount! / taxable) * 100).toStringAsFixed(2));
    }
    if (inferredIgstPct == 0 && (widget.item.igstAmount ?? 0) > 0 && taxable > 0) {
      inferredIgstPct = double.parse(((widget.item.igstAmount! / taxable) * 100).toStringAsFixed(2));
    }

    if ((widget.item.taxType == 'CGST_SGST' || widget.item.taxType == 'COMBINED_GST')
        && inferredCgstPct == 0 && inferredSgstPct == 0 && inferredIgstPct == 0) {
      inferredCgstPct = 9.0;
      inferredSgstPct = 9.0;
    }

    _cgstPctController = TextEditingController(text: inferredCgstPct > 0 ? _fmt(inferredCgstPct) : '0');
    _sgstPctController = TextEditingController(text: inferredSgstPct > 0 ? _fmt(inferredSgstPct) : '0');
    _igstPctController = TextEditingController(text: inferredIgstPct > 0 ? _fmt(inferredIgstPct) : '0');
    _printedTotalController = TextEditingController(text: _fmt(widget.item.printedTotal ?? widget.item.netBill));
    _extraAdjController = TextEditingController(text: '0');

    // Listeners
    _qtyController.addListener(_recalculate);
    _rateController.addListener(_recalculate);
    _discPctController.addListener(_recalculate);
    _discAmtController.addListener(_recalculate);
    _cgstPctController.addListener(_recalculate);
    _sgstPctController.addListener(_recalculate);
    _igstPctController.addListener(_recalculate);
    _printedTotalController.addListener(_recalculate);
    _extraAdjController.addListener(_recalculate);

    _recalculate();
  }

  @override
  void dispose() {
    _descController.dispose();
    _partNumberController.dispose();
    _hsnController.dispose();
    _qtyController.dispose();
    _rateController.dispose();
    _discPctController.dispose();
    _discAmtController.dispose();
    _cgstPctController.dispose();
    _sgstPctController.dispose();
    _igstPctController.dispose();
    _printedTotalController.dispose();
    _extraAdjController.dispose();
    super.dispose();
  }

  String _fmt(double? v) {
    if (v == null) return '';
    return v.round().toString();
  }

  double _parse(String val) {
    return double.tryParse(val.trim()) ?? 0.0;
  }

  void _recalculate() {
    final qty = _parse(_qtyController.text);
    final rate = _parse(_rateController.text);
    final discPct = _parse(_discPctController.text);
    final discAmt = _parse(_discAmtController.text);
    final cgstPct = _parse(_cgstPctController.text);
    final sgstPct = _parse(_sgstPctController.text);
    final igstPct = _parse(_igstPctController.text);
    final printedTotal = _parse(_printedTotalController.text);

    final taxType = (igstPct > 0) ? 'IGST' : 'CGST_SGST';

    final result = InvoiceMathLogic.processItem(
      qty: qty,
      rate: rate,
      origDiscPct: discPct,
      origDiscAmt: discAmt,
      cgstPct: cgstPct,
      sgstPct: sgstPct,
      igstPct: igstPct,
      printedTotal: printedTotal,
      taxType: taxType,
    );

    setState(() {
      _previewState = result;
    });
  }

  /// The final net amount = calculated net + extra adjustment
  double get _adjustedNetAmount {
    final calcNet = (_previewState['netAmount'] as double?) ?? 0.0;
    final adj = _parse(_extraAdjController.text);
    return calcNet + adj;
  }



  void _handleSave() {
    final qty = _parse(_qtyController.text);
    final rate = _parse(_rateController.text);
    final adjustedNet = _adjustedNetAmount;

    final updated = widget.item.copyWith(
      description: _descController.text,
      partNumber: _partNumberController.text,
      hsnCode: _hsnController.text.trim().isEmpty ? null : _hsnController.text.trim(),
      qty: qty,
      rate: rate,
      grossAmount: _previewState['grossAmount'],
      discType: _previewState['discType'],
      discAmount: _previewState['discAmount'],
      taxableAmount: _previewState['taxableAmount'],
      cgstAmount: _previewState['cgstAmount'],
      sgstAmount: _previewState['sgstAmount'],
      igstPercent: _previewState['igstPercent'],
      igstAmount: _previewState['igstAmount'],
      netAmount: adjustedNet,
      netBill: adjustedNet,
      printedTotal: _previewState['printedTotal'],
      amountMismatch: 0.0,   // user resolved it manually
      needsReview: false,    // always clear after explicit save
      taxType: _previewState['taxType'],
    );

    widget.onSave(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final double mismatch = (_previewState['mismatchAmount'] as double?) ?? 0.0;
    final double extraAdj = _parse(_extraAdjController.text);
    final double residualMismatch = mismatch - extraAdj.abs();

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  const Text(
                    'Edit Item Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                ],
              ),
            ),
            const Divider(height: 1),

            // Scrollable Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Item Info Section ──────────────────────────────────
                    _buildSectionLabel('Item Info', LucideIcons.package),
                    const SizedBox(height: 10),
                    _buildTextField('Item Description', _descController, maxLines: 2),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Part Number', _partNumberController,
                          hint: 'e.g. BRK-12345')),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField('HSN Code', _hsnController,
                          hint: 'e.g. 8708')),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Pricing Section ────────────────────────────────────
                    _buildSectionLabel('Pricing', LucideIcons.indianRupee),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Qty', _qtyController, isNumber: true)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField('Rate (₹)', _rateController, isNumber: true)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Disc %', _discPctController, isNumber: true)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField('Disc Amt (₹)', _discAmtController, isNumber: true)),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Tax Section ────────────────────────────────────────
                    _buildSectionLabel('Tax (GST)', LucideIcons.percent),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('CGST %', _cgstPctController, isNumber: true)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField('SGST %', _sgstPctController, isNumber: true)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField('IGST %', _igstPctController, isNumber: true)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField('Printed Total (from bill)', _printedTotalController,
                      isNumber: true, hint: 'Amount as printed on the paper bill'),

                    const SizedBox(height: 24),

                    // ── Live Preview ───────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Column(
                        children: [
                          _buildPreviewRow('Gross Amount', _previewState['grossAmount']),
                          _buildPreviewRow('Discount', -((_previewState['discAmount'] ?? 0.0) as double), color: Colors.green),
                          _buildPreviewRow('Taxable Value', _previewState['taxableAmount']),
                          _buildPreviewRow('Total Tax',
                            ((_previewState['cgstAmount'] ?? 0) as double) +
                            ((_previewState['sgstAmount'] ?? 0) as double) +
                            ((_previewState['igstAmount'] ?? 0) as double),
                            color: Colors.orange.shade700),
                          const Divider(),
                          _buildPreviewRow('Calculated Net',
                            (_previewState['netAmount'] as double?) ?? 0.0,
                            isBold: true),

                          if (extraAdj != 0.0) ...[ 
                            _buildPreviewRow(
                              extraAdj > 0 ? 'Extra Adjustment (+)' : 'Extra Adjustment (-)',
                              extraAdj,
                              color: extraAdj > 0 ? Colors.orange : Colors.green,
                            ),
                            const Divider(),
                            _buildPreviewRow('Final Amount', _adjustedNetAmount, isBold: true,
                            color: context.primaryColor),
                          ],

                          if (mismatch > 0.5 && extraAdj == 0.0) ...[ 
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: Row(
                                children: [
                                  Icon(LucideIcons.alertCircle, size: 16, color: Colors.amber.shade700),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Total differs by ${CurrencyFormatter.format(mismatch)} from the bill. '
                                      'Use "Extra Adjustment" below to fix it.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.amber.shade800,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          if (extraAdj != 0.0 && residualMismatch.abs() <= 0.5) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.shade300),
                              ),
                              child: Row(
                                children: [
                                  Icon(LucideIcons.checkCircle2, size: 16, color: Colors.green.shade700),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Total looks correct now ✓',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Extra Adjustment Section ───────────────────────────
                    _buildSectionLabel('Extra Adjustment', LucideIcons.arrowUpDown),
                    const SizedBox(height: 6),
                    Text(
                      'If the grand total still doesn\'t match the bill, add a small + or − amount here to fix it. '
                      'For example, enter "-2" to reduce total by ₹2, or "3" to add ₹3.',
                      style: TextStyle(fontSize: 12, color: context.textSecondaryColor, height: 1.5),
                    ),
                    const SizedBox(height: 10),
                    _buildTextField('Adjustment Amount (₹)', _extraAdjController,
                      isNumber: true,
                      allowNegative: true,
                      hint: 'e.g. -2 or 3',
                      prefixIcon: LucideIcons.arrowUpDown,
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save Item',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: context.primaryColor),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: context.textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
    bool allowNegative = false,
    int maxLines = 1,
    String? hint,
    IconData? prefixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber
          ? (allowNegative
              ? const TextInputType.numberWithOptions(decimal: true, signed: true)
              : const TextInputType.numberWithOptions(decimal: true))
          : TextInputType.text,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(fontSize: 11, color: context.textSecondaryColor.withValues(alpha: 0.5)),
        labelStyle: const TextStyle(fontSize: 12),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 16, color: context.textSecondaryColor) : null,
        filled: true,
        fillColor: context.surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.borderColor),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _buildPreviewRow(String label, double? value,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 14 : 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: context.textSecondaryColor,
            ),
          ),
          Text(
            value != null ? CurrencyFormatter.format(value) : CurrencyFormatter.format(0),
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color ?? context.textColor,
            ),
          )
        ],
      ),
    );
  }
}
