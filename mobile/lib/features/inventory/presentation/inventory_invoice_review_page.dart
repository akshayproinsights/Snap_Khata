import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/inventory/domain/models/inventory_models.dart';
import 'package:mobile/features/inventory/presentation/inventory_review_page.dart';
import 'package:mobile/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:mobile/features/review/presentation/receipt_review_page.dart';
import 'package:intl/intl.dart';

class InventoryInvoiceReviewPage extends ConsumerStatefulWidget {
  final InventoryInvoiceBundle bundle;

  const InventoryInvoiceReviewPage({super.key, required this.bundle});

  @override
  ConsumerState<InventoryInvoiceReviewPage> createState() =>
      _InventoryInvoiceReviewPageState();
}

class _InventoryInvoiceReviewPageState
    extends ConsumerState<InventoryInvoiceReviewPage> {
  // ── Header Details state ──────────────────────────────────────────
  late final TextEditingController _vendorNameController;
  late final TextEditingController _invoiceNumberController;
  late final TextEditingController _dateController;

  String _paymentMode = 'Credit';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _vendorNameController =
        TextEditingController(text: widget.bundle.vendorName);
    _invoiceNumberController =
        TextEditingController(text: widget.bundle.invoiceNumber);

    String initialDate = widget.bundle.date;
    try {
        final parsed = DateTime.tryParse(initialDate);
        if (parsed != null) {
            initialDate = DateFormat('dd/MM/yyyy').format(parsed);
        }
    } catch (_) {}
    _dateController = TextEditingController(text: initialDate);
  }

  Future<void> _deleteItem(InventoryItem item) async {
    HapticFeedback.mediumImpact();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item?'),
        content: Text('Delete "${item.description}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(inventoryProvider.notifier).deleteItem(item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${item.description}" deleted'),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () {
                // Note: Undo would require recreating the item
                // For now just show a message
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteInvoice(List<InventoryItem> items) async {
    HapticFeedback.mediumImpact();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entire Invoice?'),
        content: Text('Delete invoice with ${items.length} items? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final ids = items.map((i) => i.id).toList();
      await ref.read(inventoryProvider.notifier).bulkDeleteItems(ids);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice deleted')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete invoice: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _vendorNameController.dispose();
    _invoiceNumberController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _showFullImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Invoice Image'),
          ),
          body: InteractiveViewer(
            child: Center(
              child: Hero(
                tag: 'inv_img_${widget.bundle.invoiceNumber}',
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(color: Colors.white)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(double? v) {
    if (v == null) return '';
    final s = v.toStringAsFixed(2);
    return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  Future<void> _selectDate() async {
    DateTime? initialDate;
    try {
      initialDate = DateFormat('dd/MM/yyyy').parse(_dateController.text);
    } catch (_) {
      try {
        initialDate = DateTime.tryParse(_dateController.text) ?? DateTime.now();
      } catch (_) {
        initialDate = DateTime.now();
      }
    }
    
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _saveInvoice(List<InventoryItem> items, double totalAmount) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      String backendDate = _dateController.text.trim();
      try {
        final parsed = DateFormat('dd/MM/yyyy').parse(backendDate);
        backendDate = DateFormat('yyyy-MM-dd').format(parsed);
      } catch (_) {}

      final data = {
        'invoice_number': _invoiceNumberController.text.trim(),
        'vendor_name': _vendorNameController.text.trim(),
        'invoice_date': backendDate,
        'item_ids': items.map((i) => i.id).toList(),
        'payment_mode': _paymentMode,
        'payment_date': backendDate,
        'balance_owed': _paymentMode == 'Credit' ? totalAmount : 0.0,
        'amount_paid': _paymentMode == 'Cash' ? totalAmount : 0.0,
      };

      await ref.read(inventoryProvider.notifier).verifyInvoice(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inventory verified & saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }



  Widget _buildToggleBtn(String mode, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _paymentMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          mode,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
               Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.fileText,
                    size: 18, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              const Text(
                'Header Details',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary),
              ),
              const Spacer(),
              Container(
                 decoration: BoxDecoration(
                   color: Colors.grey.shade100,
                   borderRadius: BorderRadius.circular(20),
                 ),
                 child: Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     _buildToggleBtn('Credit', _paymentMode == 'Credit'),
                     _buildToggleBtn('Cash', _paymentMode == 'Cash'),
                   ],
                 ),
               ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _vendorNameController,
            decoration: _inputDecoration('Vendor Name'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _invoiceNumberController,
                  decoration: _inputDecoration('Invoice Number'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _selectDate,
                  child: AbsorbPointer(
                    child: TextFormField(
                      controller: _dateController,
                      decoration: _inputDecoration('Date').copyWith(
                        suffixIcon: const Icon(LucideIcons.calendar, size: 16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch provider so optimistic updates reflect immediately
    final state = ref.watch(inventoryProvider);

    // Recompute items for this bundle from latest state
    final invoiceKey = widget.bundle.invoiceNumber.isNotEmpty
        ? widget.bundle.invoiceNumber
        : '${widget.bundle.date}_${widget.bundle.vendorName}';

    final currentItems = state.items.where((i) {
      final key = i.invoiceNumber.isNotEmpty
          ? i.invoiceNumber
          : '${i.invoiceDate}_${i.vendorName ?? ''}';
      return key == invoiceKey;
    }).toList();

    // Mismatch items first
    final sortedItems = List<InventoryItem>.from(currentItems);
    sortedItems.sort((a, b) {
      final aMis = a.amountMismatch.abs() > 1.0;
      final bMis = b.amountMismatch.abs() > 1.0;
      if (aMis && !bMis) return -1;
      if (!aMis && bMis) return 1;
      return a.id.compareTo(b.id);
    });

    final hasAnyMismatch = sortedItems.any((i) => i.amountMismatch.abs() > 1.0);
    final totalAmount = sortedItems.fold(0.0, (sum, item) => sum + item.netBill);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.bundle.vendorName,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Review Inventory',
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.trash2, color: Colors.red),
            tooltip: 'Delete Invoice',
            onPressed: _isLoading ? null : () => _deleteInvoice(sortedItems),
          ),
        ],
      ),
      body: Column(
        children: [
          // Receipt image
          if (widget.bundle.receiptLink.isNotEmpty)
            GestureDetector(
              onTap: () => _showFullImage(widget.bundle.receiptLink),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.25,
                width: double.infinity,
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'inv_img_${widget.bundle.invoiceNumber}',
                      child: CachedNetworkImage(
                        imageUrl: widget.bundle.receiptLink,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        placeholder: (ctx, url) => const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white)),
                        errorWidget: (ctx, url, err) => const Icon(
                            LucideIcons.imageOff,
                            color: Colors.white54,
                            size: 40),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.maximize,
                                color: Colors.white, size: 14),
                            SizedBox(width: 6),
                            Text('Tap to expand',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Main list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                _buildHeaderCard(),
                const SizedBox(height: 24),

                Row(
                  children: [
                    const Text(
                      'Line Items',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${sortedItems.length} item${sortedItems.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (sortedItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                        child: Text('No items found.',
                            style: TextStyle(color: AppTheme.textSecondary))),
                  ),
                ...sortedItems.map((item) => _buildItemCard(item)),
                const SizedBox(height: 16),
                
                // Add lots of padding at the bottom so we can easily scroll past the FAB area
                const SizedBox(height: 120),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Grand Total',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '₹${_fmt(totalAmount)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _saveInvoice(sortedItems, totalAmount),
                  icon: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(hasAnyMismatch ? LucideIcons.alertTriangle : LucideIcons.checkCircle),
                  label: Text(
                    hasAnyMismatch ? 'Save with Errors' : 'Confirm & Save ✨',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasAnyMismatch ? Colors.orange : AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(InventoryItem item) {
    final hasMismatch = item.amountMismatch.abs() > 1.0;

    Color borderColor = AppTheme.border;
    Color bgColor = Colors.white;
    if (hasMismatch) {
      borderColor = Colors.red.shade200;
      bgColor = Colors.red.shade50;
    } 

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: hasMismatch ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Part number + status icon row
          Row(
             children: [
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                 decoration: BoxDecoration(
                   color: AppTheme.primary.withValues(alpha: 0.1),
                   borderRadius: BorderRadius.circular(4),
                 ),
                 child: Text(
                   item.partNumber.isNotEmpty ? 'Part: ${item.partNumber}' : 'Item #${item.id}',
                   style: const TextStyle(
                     fontSize: 11,
                     fontWeight: FontWeight.w700,
                     color: AppTheme.primary,
                   ),
                 ),
               ),
               const Spacer(),
               if (hasMismatch)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.alertTriangle, size: 10, color: Colors.red.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Mismatch',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
               const SizedBox(width: 8),
               GestureDetector(
                 onTap: () => _deleteItem(item),
                 child: Container(
                   padding: const EdgeInsets.all(4),
                   decoration: BoxDecoration(
                     color: Colors.red.shade50,
                     borderRadius: BorderRadius.circular(4),
                   ),
                   child: Icon(LucideIcons.trash2, size: 14, color: Colors.red.shade600),
                 ),
               ),
             ],
          ),
          const SizedBox(height: 12),

          // Description + Amount row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: DebouncedReviewField(
                  key: ValueKey('desc_${item.id}'),
                  initialValue: item.description,
                  decoration: _inputDecoration('Description').copyWith(
                    errorText:
                        item.description.trim().isEmpty ? 'Required' : null,
                  ),
                  maxLines: null,
                  onSaved: (val) {
                    if (val != item.description) {
                      ref.read(inventoryProvider.notifier).updateItem(
                        item.id,
                        {'description': val},
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DebouncedReviewField(
                  key: ValueKey('amount_${item.id}'),
                  initialValue: _fmt(item.netBill),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: AppTheme.primary),
                  decoration: _inputDecoration('Amount (₹)'),
                  onSaved: (val) {
                    final newAmount = double.tryParse(val);
                    if (newAmount != null && newAmount != item.netBill) {
                      ref.read(inventoryProvider.notifier).updateItem(
                        item.id,
                        {'net_bill': newAmount, 'amount_mismatch': 0},
                      );
                    }
                  },
                ),
              ),
            ],
          ),

          // Qty × Rate row
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DebouncedReviewField(
                  key: ValueKey('qty_${item.id}'),
                  initialValue: _fmt(item.qty),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDecoration('Qty'),
                  onSaved: (val) {
                    final newQty = double.tryParse(val);
                    if (newQty != null && newQty != item.qty) {
                      final newMismatch =
                          ((newQty * item.rate) - item.netBill).abs();
                      ref.read(inventoryProvider.notifier).updateItem(
                        item.id,
                        {'qty': newQty, 'amount_mismatch': newMismatch},
                      );
                    }
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.0),
                child:
                    Text('×', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: DebouncedReviewField(
                  key: ValueKey('rate_${item.id}'),
                  initialValue: _fmt(item.rate),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDecoration('Rate (₹)'),
                  onSaved: (val) {
                    final newRate = double.tryParse(val);
                    if (newRate != null && newRate != item.rate) {
                      final newMismatch =
                          ((item.qty * newRate) - item.netBill).abs();
                      ref.read(inventoryProvider.notifier).updateItem(
                        item.id,
                        {'rate': newRate, 'amount_mismatch': newMismatch},
                      );
                    }
                  },
                ),
              ),
            ],
          ),

          // Mismatch error hint
          if (hasMismatch) ...[
            const SizedBox(height: 12),
            Container(
               padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
               decoration: BoxDecoration(
                 color: Colors.red.shade100.withValues(alpha: 0.5),
                 borderRadius: BorderRadius.circular(6),
               ),
               child: Row(
               children: [
                  Icon(LucideIcons.alertTriangle,
                      size: 14, color: Colors.red.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Math Error: Qty × Rate ≠ Amount  (diff ₹${item.amountMismatch.toStringAsFixed(2)})',
                      style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
