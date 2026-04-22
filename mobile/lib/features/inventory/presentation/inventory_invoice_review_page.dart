import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/inventory/domain/models/inventory_models.dart';
import 'package:mobile/features/inventory/domain/models/invoice_item_v2_model.dart';
import 'package:mobile/features/inventory/presentation/inventory_review_page.dart';
import 'package:mobile/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:mobile/features/inventory/presentation/widgets/edit_item_modal.dart';
import 'package:mobile/features/inventory/presentation/widgets/header_adjustments_section.dart';
import 'package:mobile/features/inventory/presentation/widgets/invoice_item_card.dart';
import 'package:mobile/features/inventory/presentation/widgets/validation_save_button.dart';
import 'package:mobile/shared/widgets/app_toast.dart';
import 'package:intl/intl.dart';
import 'providers/vendor_ledger_provider.dart';
import 'providers/inventory_items_provider.dart';
import '../../udhar/presentation/providers/udhar_dashboard_provider.dart';

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

  late List<HeaderAdjustment> _adjustments;
  double? _targetTotal;

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
    _adjustments = List.from(widget.bundle.headerAdjustments);
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
      ref.invalidate(inventoryItemsProvider);
      ref.invalidate(vendorLedgerProvider);
      ref.invalidate(udharDashboardProvider);
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
      ref.invalidate(inventoryItemsProvider);
      ref.invalidate(vendorLedgerProvider);
      ref.invalidate(udharDashboardProvider);
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

  void _showEditAdjustmentDialog(int index, HeaderAdjustment adj) {
    final controller = TextEditingController(text: adj.amount.abs().toStringAsFixed(2));
    final type = adj.adjustmentType;
    final isDeduction = adj.amount < 0 || type == 'HEADER_DISCOUNT' || type == 'SCHEME';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${adj.description ?? adj.adjustmentType}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Amount (₹)',
                prefixText: '₹ ',
                suffixText: isDeduction ? '(Deduction)' : '(Addition)',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(controller.text) ?? 0.0;
              setState(() {
                _adjustments[index] = adj.copyWith(amount: isDeduction ? -val.abs() : val.abs());
                // Reset target total if we manually edit adjustments to avoid dual-conflicts
                _targetTotal = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showEditTotalDialog(double currentCalculatedTotal) {
    final controller = TextEditingController(text: (_targetTotal ?? currentCalculatedTotal).toStringAsFixed(2));
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adjust Grand Total'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the correct total from the bill. We will adjust the extras to match.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Total Bill Amount (₹)',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _targetTotal = null;
                // Remove any manual correction adjustments if they exist
                _adjustments.removeWhere((a) => a.description == 'Manual Correction');
              });
              Navigator.pop(context);
            },
            child: const Text('Reset to Auto'),
          ),
          FilledButton(
            onPressed: () {
              final newTotal = double.tryParse(controller.text);
              if (newTotal != null) {
                setState(() {
                  _targetTotal = newTotal;
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Update Total'),
          ),
        ],
      ),
    );
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
        'final_total': totalAmount,
        'adjustments': _adjustments.map((a) => a.toJson()).toList(),
      };

      await ref.read(inventoryProvider.notifier).verifyInvoice(data);
      
      ref.invalidate(inventoryItemsProvider);
      ref.invalidate(vendorLedgerProvider);
      ref.invalidate(udharDashboardProvider);

      // Persist payment mode on the bundle so downstream pages reflect it
      widget.bundle.paymentMode = _paymentMode;

      if (mounted) {
        AppToast.showSuccess(
          context,
          'Inventory updated successfully. You can continue with your next bill.',
          title: 'Saved',
        );
        context.go('/inventory');
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

    // Build a lookup of optimistically-updated / deleted items from the provider.
    // The provider only loads *pending* items by default, so we must NOT replace
    // the full item list with provider items (verified items won't appear there).
    // Instead, we always start from widget.bundle.items (loaded via inventoryItemsProvider
    // with show_all=true) and only apply per-item overrides from the provider by ID.
    final providerItemById = { for (final i in state.items) i.id: i };

    // Apply optimistic updates: use provider version of each item if present,
    // skip items that were deleted (absent from provider only if provider has
    // loaded items for this invoice at all).
    final providerHasThisInvoice = state.items.any((i) {
      final key = i.invoiceNumber.isNotEmpty
          ? i.invoiceNumber
          : '${i.invoiceDate}_${i.vendorName ?? ''}';
      final invoiceKey = widget.bundle.invoiceNumber.isNotEmpty
          ? widget.bundle.invoiceNumber
          : '${widget.bundle.date}_${widget.bundle.vendorName}';
      return key == invoiceKey;
    });

    final currentItems = widget.bundle.items.where((bundleItem) {
      // If the provider has loaded items for this specific invoice, respect deletions
      if (providerHasThisInvoice && !providerItemById.containsKey(bundleItem.id)) {
        return false; // Item was deleted (optimistic)
      }
      return true;
    }).map((bundleItem) {
      // Apply any optimistic edits from provider
      return providerItemById[bundleItem.id] ?? bundleItem;
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

    final hasAnyMismatch = sortedItems.any((i) => i.amountMismatch.abs() > 1.0 || (i.needsReview ?? false));

    // ── Two-Scenario Grand Total Logic ────────────────────────────────────────
    //
    // SCENARIO A — Per-item discount (discAmount > 0 OR discPercent > 0 on any item):
    //   Each item's netAmount already has: gross → (gross − discAmt) → +GST.
    //   HEADER_DISCOUNT/SCHEME are just a summary of what's already in items.
    //   → Sum item netAmounts; skip HEADER_DISCOUNT from adjustments (avoid double-count).
    //
    // SCENARIO B — Header-only discount (all items have discAmount=0, discPercent=0):
    //   Items have no per-item discount; discount appears only as a footer line.
    //   Correct bill math: totalGross − headerDiscount = totalTaxable → GST on taxable.
    //   Items' netAmounts currently include GST on FULL gross (no discount applied).
    //   → Recalculate: totalTaxable = totalGross − headerDiscount;
    //     scale GST proportionally from items' original GST amounts.
    //   → HEADER_DISCOUNT is consumed here and NOT added to adjustmentTotal.

    final hasPerItemDiscount = sortedItems.any(
      (i) => (i.discAmount ?? 0.0) > 0.01 || (i.discPercent ?? 0.0) > 0.01,
    );



    // ROUND_OFF / OTHER always added on top in both scenarios.
    final nonDiscountAdjTotal = _adjustments.fold<double>(
      0.0,
      (sum, adj) {
        final type = adj.adjustmentType.toUpperCase();
        if (type == 'ROUND_OFF' || type == 'OTHER') {
          return sum + (adj.amount); // use signed amount
        }
        return sum;
      },
    );

    double baseItemsTotal;

    if (hasPerItemDiscount) {
      // ── Scenario A ──────────────────────────────────────────────────────────
      // Discounts are already inside each item's netAmount. Just sum them up.
      baseItemsTotal = sortedItems.fold(
        0.0,
        (sum, item) => sum + (item.netAmount ?? item.netBill),
      );
    } else {
      // ── Scenario B ──────────────────────────────────────────────────────────
      // No per-item discount. Apply HEADER_DISCOUNT/SCHEME to total gross,
      // THEN scale GST proportionally (discount before tax, not after).

      final totalGross = sortedItems.fold(
        0.0,
        (sum, item) => sum + (item.grossAmount ?? (item.qty * item.rate)),
      );

      final headerDiscountAmt = _adjustments.fold<double>(
        0.0,
        (sum, adj) {
          final type = adj.adjustmentType.toUpperCase();
          if (type == 'HEADER_DISCOUNT' || type == 'SCHEME') {
            return sum + adj.amount.abs();
          }
          return sum;
        },
      );

      final totalTaxable = (totalGross - headerDiscountAmt).clamp(0.0, double.infinity);

      // Scale existing GST amounts proportionally to the discounted taxable base.
      // (Items' GST was computed on grossAmount since discPct=0 at item level)
      final originalTaxableBase = sortedItems.fold<double>(
        0.0,
        (sum, item) => sum + (item.taxableAmount ?? item.grossAmount ?? (item.qty * item.rate)),
      );
      final totalGst = sortedItems.fold<double>(
        0.0,
        (sum, item) =>
            sum + (item.cgstAmount ?? 0.0) + (item.sgstAmount ?? 0.0) + (item.igstAmount ?? 0.0),
      );
      final scaledGst = originalTaxableBase > 0
          ? totalGst * (totalTaxable / originalTaxableBase)
          : totalGst;

      baseItemsTotal = totalTaxable + scaledGst;
    }

    double totalAmount = baseItemsTotal + nonDiscountAdjTotal;

    // ── Apply Manual Correction if Target Total is set ────────────────────────
    if (_targetTotal != null) {
        final diff = _targetTotal! - totalAmount;
        if (diff.abs() > 0.001) {
            // Find existing manual correction or create new
            final idx = _adjustments.indexWhere((a) => a.description == 'Manual Correction');
            if (idx != -1) {
                _adjustments[idx] = _adjustments[idx].copyWith(amount: _adjustments[idx].amount + diff);
            } else {
                _adjustments.add(HeaderAdjustment(
                    adjustmentType: 'OTHER',
                    amount: diff,
                    description: 'Manual Correction',
                ));
            }
            // Re-calculate to reflect the correction
            totalAmount = _targetTotal!;
        }
    }

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
                ...sortedItems.map((item) => InvoiceItemCard(
                  item: item,
                  onEdit: () {
                    EditItemModal.show(context, item, (updatedItem) {
                      ref.read(inventoryProvider.notifier).updateItem(updatedItem.id, {
                        'description': updatedItem.description,
                        'part_number': updatedItem.partNumber,
                        'hsn_code': updatedItem.hsnCode,
                        'qty': updatedItem.qty,
                        'rate': updatedItem.rate,
                        'gross_amount': updatedItem.grossAmount,
                        'disc_type': updatedItem.discType,
                        'disc_amount': updatedItem.discAmount,
                        'taxable_amount': updatedItem.taxableAmount,
                        'tax_type': updatedItem.taxType,
                        'cgst_amount': updatedItem.cgstAmount,
                        'sgst_amount': updatedItem.sgstAmount,
                        'igst_percent': updatedItem.igstPercent,
                        'igst_amount': updatedItem.igstAmount,
                        'net_amount': updatedItem.netAmount,
                        'net_bill': updatedItem.netBill,
                        'printed_total': updatedItem.printedTotal,
                        'amount_mismatch': updatedItem.amountMismatch,
                        'needs_review': updatedItem.needsReview,
                      });
                    });
                  },
                  onDelete: () => _deleteItem(item),
                )),
                HeaderAdjustmentsSection(
                  adjustments: _adjustments,
                  hasPerItemDiscount: hasPerItemDiscount,
                  onEdit: _showEditAdjustmentDialog,
                ),
                const SizedBox(height: 16),
                
                // Add lots of padding at the bottom so we can easily scroll past the FAB area
                const SizedBox(height: 120),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: ValidationSaveButton(
        totalAmount: totalAmount,
        hasMismatch: hasAnyMismatch,
        isLoading: _isLoading,
        onSave: () => _saveInvoice(sortedItems, totalAmount),
        onTotalTap: () => _showEditTotalDialog(totalAmount),
        isUpdate: widget.bundle.isVerified,
      ),
    );
  }
}


