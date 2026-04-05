import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
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
  late TextEditingController _qtyController;
  late TextEditingController _rateController;
  late TextEditingController _discPctController;
  late TextEditingController _discAmtController;
  late TextEditingController _cgstPctController;
  late TextEditingController _sgstPctController;
  late TextEditingController _igstPctController;
  late TextEditingController _printedTotalController;

  Map<String, dynamic> _previewState = {};

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController(text: widget.item.description);
    _qtyController = TextEditingController(text: _fmt(widget.item.qty));
    _rateController = TextEditingController(text: _fmt(widget.item.rate));
    
    // Attempt to reverse engineer or extract discount percentages. 
    // We will use 0.0 if not present, and handle logic in the processItem callback.
    _discPctController = TextEditingController(text: '0'); 
    _discAmtController = TextEditingController(text: _fmt(widget.item.discAmount ?? 0));
    _cgstPctController = TextEditingController(text: '0');
    _sgstPctController = TextEditingController(text: '0');
    _igstPctController = TextEditingController(text: _fmt(widget.item.igstPercent ?? 0));
    _printedTotalController = TextEditingController(text: _fmt(widget.item.printedTotal ?? widget.item.netBill));

    // Handle COMBINED_GST back to CGST/SGST if applicable
    if (widget.item.taxType == 'COMBINED_GST' || widget.item.taxType == 'CGST_SGST') {
      // Simplistic fallback if we don't have the original percent in the model yet
      // In reality, backend would return cgst_percent, but until then we can assume 9% for 18% total.
      _cgstPctController.text = '9';
      _sgstPctController.text = '9';
    }

    // Attach listeners to recalculate on the fly
    _qtyController.addListener(_recalculate);
    _rateController.addListener(_recalculate);
    _discPctController.addListener(_recalculate);
    _discAmtController.addListener(_recalculate);
    _cgstPctController.addListener(_recalculate);
    _sgstPctController.addListener(_recalculate);
    _igstPctController.addListener(_recalculate);
    _printedTotalController.addListener(_recalculate);

    _recalculate();
  }

  @override
  void dispose() {
    _descController.dispose();
    _qtyController.dispose();
    _rateController.dispose();
    _discPctController.dispose();
    _discAmtController.dispose();
    _cgstPctController.dispose();
    _sgstPctController.dispose();
    _igstPctController.dispose();
    _printedTotalController.dispose();
    super.dispose();
  }

  String _fmt(double? v) {
    if (v == null) return '';
    final s = v.toStringAsFixed(2);
    return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
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

  void _handleSave() {
    final qty = _parse(_qtyController.text);
    final rate = _parse(_rateController.text);

    final updated = widget.item.copyWith(
      description: _descController.text,
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
      netAmount: _previewState['netAmount'],
      netBill: _previewState['netAmount'],
      printedTotal: _previewState['printedTotal'],
      amountMismatch: _previewState['mismatchAmount'],
      needsReview: _previewState['needsReview'],
      taxType: _previewState['taxType'],
    );

    widget.onSave(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bool needsReview = _previewState['needsReview'] ?? false;
    final double mismatch = _previewState['mismatchAmount'] ?? 0.0;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                    _buildTextField('Description', _descController, maxLines: 2),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Quantity', _qtyController, isNumber: true)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField('Rate (₹)', _rateController, isNumber: true)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Disc %', _discPctController, isNumber: true)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField('Disc Amt', _discAmtController, isNumber: true)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('CGST %', _cgstPctController, isNumber: true)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField('SGST %', _sgstPctController, isNumber: true)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField('IGST %', _igstPctController, isNumber: true)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField('Printed Total (From OCR)', _printedTotalController, isNumber: true),
                    
                    const SizedBox(height: 24),
                    
                    // Live Preview Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          _buildPreviewRow('Gross Amount', _previewState['grossAmount']),
                          _buildPreviewRow('Discount Amt', -(_previewState['discAmount'] ?? 0.0), color: Colors.green),
                          _buildPreviewRow('Taxable Value', _previewState['taxableAmount']),
                          _buildPreviewRow('Total Tax', (_previewState['cgstAmount'] ?? 0) + (_previewState['sgstAmount'] ?? 0) + (_previewState['igstAmount'] ?? 0), color: Colors.orange.shade700),
                          const Divider(),
                          _buildPreviewRow('Calculated Net', _previewState['netAmount'], isBold: true),
                          
                          if (mismatch > 0) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  needsReview ? '⚠ Review Needed' : 'Accepted Diff',
                                  style: TextStyle(
                                    color: needsReview ? Colors.red : Colors.grey.shade600,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'Diff: ₹${mismatch.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: needsReview ? Colors.red : Colors.grey.shade600,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            )
                          ]
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Footer
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: needsReview ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  needsReview ? 'Fix Math Errors to Save' : 'Save Item',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isNumber = false, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _buildPreviewRow(String label, double? value, {bool isBold = false, Color? color}) {
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
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            value != null ? '₹${value.toStringAsFixed(2)}' : '₹0.00',
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color ?? AppTheme.textPrimary,
            ),
          )
        ],
      ),
    );
  }
}
