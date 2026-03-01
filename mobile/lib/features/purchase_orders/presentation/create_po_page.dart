import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/purchase_orders/domain/models/purchase_order_models.dart';
import 'package:mobile/features/purchase_orders/presentation/providers/purchase_order_provider.dart';
import 'package:mobile/shared/widgets/app_toast.dart';

/// Page for manually adding any item to the draft purchase order.
class CreatePoPage extends ConsumerStatefulWidget {
  const CreatePoPage({super.key});

  @override
  ConsumerState<CreatePoPage> createState() => _CreatePoPageState();
}

class _CreatePoPageState extends ConsumerState<CreatePoPage> {
  final _formKey = GlobalKey<FormState>();
  final _partNumberCtrl = TextEditingController();
  final _itemNameCtrl = TextEditingController();
  final _currentStockCtrl = TextEditingController(text: '0');
  final _reorderPointCtrl = TextEditingController(text: '2');
  final _reorderQtyCtrl = TextEditingController(text: '1');
  final _unitValueCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _priority = 'P2';
  String? _selectedSupplier;
  bool _isLoading = false;

  static const _priorities = ['P0', 'P1', 'P2', 'P3'];
  static const _priorityLabels = {
    'P0': '🔴 P0 — Urgent (Out of Stock)',
    'P1': '🟠 P1 — High (Low Stock)',
    'P2': '🔵 P2 — Normal',
    'P3': '⚪ P3 — Low Priority',
  };

  @override
  void dispose() {
    _partNumberCtrl.dispose();
    _itemNameCtrl.dispose();
    _currentStockCtrl.dispose();
    _reorderPointCtrl.dispose();
    _reorderQtyCtrl.dispose();
    _unitValueCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suppliers =
        ref.watch(purchaseOrderProvider.select((s) => s.suppliers));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Add to Draft PO',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(LucideIcons.info, size: 16, color: AppTheme.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Fill in the item details. Items added here go into your draft basket.',
                        style: TextStyle(fontSize: 12, color: AppTheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Part Number
              _label('Part Number *'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _partNumberCtrl,
                decoration: _decoration('e.g. AB-12345'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),

              // Item Name
              _label('Item Name *'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _itemNameCtrl,
                decoration: _decoration('e.g. Oil Filter 650ml'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),

              // Stock row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Current Stock'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _currentStockCtrl,
                          keyboardType: TextInputType.number,
                          decoration: _decoration('0'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Reorder Point'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _reorderPointCtrl,
                          keyboardType: TextInputType.number,
                          decoration: _decoration('2'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Order Qty + Unit Value row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Order Qty *'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _reorderQtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: _decoration('1'),
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null || n <= 0) return 'Must be > 0';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Unit Price (₹)'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _unitValueCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: _decoration('Optional'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Priority
              _label('Priority'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _priority,
                decoration: _decoration(''),
                items: _priorities
                    .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(_priorityLabels[p] ?? p,
                            style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (v) => setState(() => _priority = v ?? 'P2'),
              ),
              const SizedBox(height: 14),

              // Supplier
              _label('Supplier (optional)'),
              const SizedBox(height: 6),
              if (suppliers.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedSupplier,
                  hint: const Text('Select or leave blank'),
                  decoration: _decoration(''),
                  items: suppliers
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedSupplier = v),
                )
              else
                TextFormField(
                  decoration: _decoration('Supplier name'),
                  onChanged: (v) => _selectedSupplier = v.trim(),
                ),
              const SizedBox(height: 14),

              // Notes
              _label('Notes (optional)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: _decoration('Any special instructions...'),
              ),
              const SizedBox(height: 28),

              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(LucideIcons.shoppingCart, size: 18),
                  label: const Text('Add to Draft',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13));

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppTheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();

    setState(() => _isLoading = true);

    final item = DraftPoItem(
      partNumber: _partNumberCtrl.text.trim(),
      itemName: _itemNameCtrl.text.trim(),
      currentStock: double.tryParse(_currentStockCtrl.text.trim()) ?? 0,
      reorderPoint: double.tryParse(_reorderPointCtrl.text.trim()) ?? 2,
      reorderQty: int.tryParse(_reorderQtyCtrl.text.trim()) ?? 1,
      unitValue: _unitValueCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_unitValueCtrl.text.trim()),
      priority: _priority,
      supplierName: _selectedSupplier?.trim().isEmpty == true
          ? null
          : _selectedSupplier?.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    final ok = await ref.read(purchaseOrderProvider.notifier).addItem(item);

    if (mounted) {
      setState(() => _isLoading = false);
      if (ok) {
        AppToast.showSuccess(context, '${item.itemName} added to draft!');
        Navigator.pop(context);
      } else {
        AppToast.showError(context, 'Failed to add item. Try again.');
      }
    }
  }
}
